import Foundation
import CoreBluetooth
import Combine

class BluetoothService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedDevice: BLEDevice?
    @Published var batteryLevel: Int?
    @Published var serialNumber: String?
    @Published var permissionStatus: PermissionStatus = .unknown
    
    // Diagnostic properties
    @Published var diagnosticLog: [String] = []
    @Published var serialNumberStatus: CommandStatus = .notRequested
    @Published var batteryLevelStatus: CommandStatus = .notRequested
    
    // MARK: - Neocore Protocol Constants
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let writeCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let notifyCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    // Feature IDs
    private let NEOCORE_CORE_FEATURE_ID: UInt16 = 0x00
    private let NEOCORE_SENSOR_CFG_FEATURE_ID: UInt16 = 0x01
    private let NEOCORE_SENSOR_STREAM_FEATURE_ID: UInt16 = 0x02
    private let NEOCORE_BATTERY_FEATURE_ID: UInt16 = 0x03
    private let NEOCORE_CHARGER_STATUS_FEATURE_ID: UInt16 = 0x04
    
    // PDU Types
    private let PDU_TYPE_COMMAND: UInt16 = 0
    private let PDU_TYPE_NOTIFICATION: UInt16 = 1
    private let PDU_TYPE_RESPONSE: UInt16 = 2
    private let PDU_TYPE_ERROR: UInt16 = 3
    
    // Command IDs
    private let NEOCORE_CMD_ID_GET_SERIAL_NUM: UInt16 = 0x01
    private let NEOCORE_CMD_ID_GET_BATTERY_LEVEL: UInt16 = 0x00
    
    // Command timeouts
    private let commandTimeout: TimeInterval = 5.0 // 5 seconds
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()
    private let targetDevices = ["QCC5181", "QCC5181-LE", "NEOCORE"]
    private let savedDeviceKey = "savedBluetoothDeviceID"
    
    // Command tracking
    private var pendingCommands: [UInt16: (timer: Timer?, statusPublisher: Published<CommandStatus>.Publisher)] = [:]
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Logging
    private func log(_ message: String) {
        print("BLE: \(message)")
        DispatchQueue.main.async {
            self.diagnosticLog.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
            // Keep log at a reasonable size
            if self.diagnosticLog.count > 100 {
                self.diagnosticLog.removeFirst(self.diagnosticLog.count - 100)
            }
        }
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            log("Cannot start scanning - Bluetooth not powered on")
            return
        }
        
        isScanning = true
        discoveredDevices = []
        log("Starting device scan...")
        
        // Scan for all devices rather than specific service
        centralManager.scanForPeripherals(
            withServices: nil, // No service filter
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Auto-stop scanning after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        log("Scanning stopped")
    }
    
    func connect(to device: DiscoveredDevice) {
        guard let peripheral = device.peripheral else {
            log("Error: Cannot connect to device - peripheral is nil")
            return
        }
        
        self.peripheral = peripheral
        log("Connecting to device: \(device.name)")
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = peripheral else {
            log("Error: Cannot disconnect - no device connected")
            return
        }
        
        log("Disconnecting from device: \(peripheral.name ?? "Unknown")")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func saveConnectedDevice() {
        guard let device = connectedDevice else {
            log("Error: Cannot save device - no device connected")
            return
        }
        
        UserDefaults.standard.set(device.id, forKey: savedDeviceKey)
        log("Saved device \(device.name) with ID \(device.id)")
    }
    
    func reconnectToPreviousDevice() {
        guard let savedID = UserDefaults.standard.string(forKey: savedDeviceKey) else {
            log("No previously saved device found")
            return
        }
        
        log("Attempting to reconnect to previously saved device with ID: \(savedID)")
        
        // Start scanning to find the device
        startScanning()
        
        // Setup observer for the saved device
        $discoveredDevices
            .compactMap { devices in devices.first { $0.id == savedID } }
            .first()
            .sink { [weak self] device in
                guard let self = self else { return }
                self.log("Found previously saved device: \(device.name)")
                self.stopScanning()
                self.connect(to: device)
            }
            .store(in: &cancellables)
    }
    
    func checkPermissions() {
        switch centralManager.state {
        case .poweredOn:
            permissionStatus = .authorized
            log("Bluetooth state: Powered On")
        case .unauthorized:
            permissionStatus = .denied
            log("Bluetooth state: Unauthorized")
        case .poweredOff:
            permissionStatus = .poweredOff
            log("Bluetooth state: Powered Off")
        case .resetting:
            permissionStatus = .unknown
            log("Bluetooth state: Resetting")
        case .unsupported:
            permissionStatus = .unsupported
            log("Bluetooth state: Unsupported")
        case .unknown:
            permissionStatus = .notDetermined
            log("Bluetooth state: Unknown")
        @unknown default:
            permissionStatus = .unknown
            log("Bluetooth state: Unknown (future state)")
        }
    }
    
    // MARK: - BLE Command Methods
    
    func readSerialNumber() {
        log("Requesting serial number...")
        serialNumberStatus = .requested
        
        // Create command key for tracking
        let commandKey = createCommandKey(featureId: NEOCORE_CORE_FEATURE_ID, pduId: NEOCORE_CMD_ID_GET_SERIAL_NUM)
        
        // Set up timeout timer
        let timer = Timer.scheduledTimer(withTimeInterval: commandTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.log("Serial number request timed out")
            DispatchQueue.main.async {
                self.serialNumberStatus = .timeout
                self.pendingCommands.removeValue(forKey: commandKey)
            }
        }
        
        // Track the command
        pendingCommands[commandKey] = (timer, $serialNumberStatus)
        
        // Send the command
        sendCommand(
            featureId: NEOCORE_CORE_FEATURE_ID,
            pduType: PDU_TYPE_COMMAND,
            pduId: NEOCORE_CMD_ID_GET_SERIAL_NUM,
            data: nil
        )
    }
    
    func readBatteryLevel() {
        log("Requesting battery level...")
        batteryLevelStatus = .requested
        
        // Create command key for tracking
        let commandKey = createCommandKey(featureId: NEOCORE_BATTERY_FEATURE_ID, pduId: NEOCORE_CMD_ID_GET_BATTERY_LEVEL)
        
        // Set up timeout timer
        let timer = Timer.scheduledTimer(withTimeInterval: commandTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.log("Battery level request timed out")
            DispatchQueue.main.async {
                self.batteryLevelStatus = .timeout
                self.pendingCommands.removeValue(forKey: commandKey)
            }
        }
        
        // Track the command
        pendingCommands[commandKey] = (timer, $batteryLevelStatus)
        
        // Send the command
        sendCommand(
            featureId: NEOCORE_BATTERY_FEATURE_ID,
            pduType: PDU_TYPE_COMMAND,
            pduId: NEOCORE_CMD_ID_GET_BATTERY_LEVEL,
            data: nil
        )
    }
    
    // MARK: - Command Helpers
    
    private func createCommandKey(featureId: UInt16, pduId: UInt16) -> UInt16 {
        return (featureId << 8) | pduId
    }
    
    // Helper method to build and send commands
    private func sendCommand(featureId: UInt16, pduType: UInt16, pduId: UInt16, data: Data?) {
        guard let writeCharacteristic = writeCharacteristic,
              let peripheral = peripheral else {
            log("Error: Cannot send command - write characteristic or peripheral not available")
            return
        }
        
        // Build command header
        let commandId: UInt16 = ((featureId << 9) | (pduType << 7)) | pduId
        var bytes = [UInt8]()
        
        // Add header bytes (big-endian)
        bytes.append(UInt8((commandId >> 8) & 0xFF))  // High byte
        bytes.append(UInt8(commandId & 0xFF))        // Low byte
        
        // Add data bytes if provided
        let commandData: Data
        if let data = data {
            var mutableData = Data(bytes)
            mutableData.append(data)
            commandData = mutableData
        } else {
            commandData = Data(bytes)
        }
        
        log("Sending command: \(String(format: "0x%04X", commandId)) - Raw data: \(commandData.hexDescription)")
        
        // Write the command
        peripheral.writeValue(commandData, for: writeCharacteristic, type: .withResponse)
    }
    
    // Helper method to parse responses
    private func parseResponse(data: Data) {
        guard data.count >= 2 else {
            log("Invalid response: too short")
            return
        }
        
        // Extract header
        let headerByte1 = data[0]
        let headerByte2 = data[1]
        let commandId: UInt16 = (UInt16(headerByte1) << 8) | UInt16(headerByte2)
        
        // Parse header components
        let featureId = commandId >> 9
        let pduType = (commandId >> 7) & 0x03
        let pduId = commandId & 0x7F
        
        log("Received response: feature=\(featureId), type=\(pduType), id=\(pduId) - Raw data: \(data.hexDescription)")
        
        // Handle based on response type
        if pduType == PDU_TYPE_RESPONSE {
            // Response to commands
            if featureId == NEOCORE_CORE_FEATURE_ID && pduId == NEOCORE_CMD_ID_GET_SERIAL_NUM {
                // Cancel timeout
                let key = createCommandKey(featureId: NEOCORE_CORE_FEATURE_ID, pduId: NEOCORE_CMD_ID_GET_SERIAL_NUM)
                pendingCommands[key]?.timer?.invalidate()
                pendingCommands.removeValue(forKey: key)
                
                handleSerialNumberResponse(data: data)
            } else if featureId == NEOCORE_BATTERY_FEATURE_ID && pduId == NEOCORE_CMD_ID_GET_BATTERY_LEVEL {
                // Cancel timeout
                let key = createCommandKey(featureId: NEOCORE_BATTERY_FEATURE_ID, pduId: NEOCORE_CMD_ID_GET_BATTERY_LEVEL)
                pendingCommands[key]?.timer?.invalidate()
                pendingCommands.removeValue(forKey: key)
                
                handleBatteryLevelResponse(data: data)
            }
        } else if pduType == PDU_TYPE_NOTIFICATION {
            // Asynchronous notifications
            if featureId == NEOCORE_BATTERY_FEATURE_ID {
                // Battery notification
                handleBatteryLevelResponse(data: data)
            }
        } else if pduType == PDU_TYPE_ERROR {
            log("Received error response: \(data.hexDescription)")
            
            // Check if this is a response to a command we're tracking
            if featureId == NEOCORE_CORE_FEATURE_ID && pduId == NEOCORE_CMD_ID_GET_SERIAL_NUM {
                // Cancel timeout and update status
                let key = createCommandKey(featureId: NEOCORE_CORE_FEATURE_ID, pduId: NEOCORE_CMD_ID_GET_SERIAL_NUM)
                pendingCommands[key]?.timer?.invalidate()
                pendingCommands.removeValue(forKey: key)
                
                DispatchQueue.main.async {
                    self.serialNumberStatus = .error
                }
            } else if featureId == NEOCORE_BATTERY_FEATURE_ID && pduId == NEOCORE_CMD_ID_GET_BATTERY_LEVEL {
                // Cancel timeout and update status
                let key = createCommandKey(featureId: NEOCORE_BATTERY_FEATURE_ID, pduId: NEOCORE_CMD_ID_GET_BATTERY_LEVEL)
                pendingCommands[key]?.timer?.invalidate()
                pendingCommands.removeValue(forKey: key)
                
                DispatchQueue.main.async {
                    self.batteryLevelStatus = .error
                }
            }
        }
    }
    
    private func handleSerialNumberResponse(data: Data) {
        guard data.count > 2 else {
            log("Invalid serial number response: payload too short")
            DispatchQueue.main.async {
                self.serialNumberStatus = .error
            }
            return
        }
        
        // Extract payload (after the 2-byte header)
        let serialData = data.subdata(in: 2..<data.count)
        
        // Try to convert to string
        if let serialString = String(data: serialData, encoding: .utf8) {
            log("Parsed serial number: \(serialString)")
            DispatchQueue.main.async {
                self.serialNumber = serialString
                self.serialNumberStatus = .success
            }
        } else {
            // If not a UTF-8 string, use hex representation
            let hexSerial = serialData.hexDescription
            log("Parsed serial number (hex): \(hexSerial)")
            DispatchQueue.main.async {
                self.serialNumber = hexSerial
                self.serialNumberStatus = .success
            }
        }
    }
    
    private func handleBatteryLevelResponse(data: Data) {
        guard data.count >= 3 else {
            log("Invalid battery level response: payload too short")
            DispatchQueue.main.async {
                self.batteryLevelStatus = .error
            }
            return
        }
        
        // Battery level is in the first byte after the header
        let level = Int(data[2])
        log("Parsed battery level: \(level)%")
        
        DispatchQueue.main.async {
            self.batteryLevel = level
            self.batteryLevelStatus = .success
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        checkPermissions()
        
        if central.state == .poweredOn {
            reconnectToPreviousDevice()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown Device"
        
        // Skip unknown devices
        guard name != "Unknown Device" else { return }
        
        // Log only for devices that might be ours
        let mightBeOurs = targetDevices.contains { deviceName in name.contains(deviceName) }
        if mightBeOurs {
            log("Discovered potential device: \(name) (RSSI: \(RSSI.intValue))")
            
            // Log advertisement data for debugging
            log("Advertisement data: \(advertisementData)")
        }
        
        // Check if this is one of our target devices
        let isPriority = targetDevices.contains { deviceName in
            name.contains(deviceName)
        }
        
        let newDevice = DiscoveredDevice(
            id: peripheral.identifier.uuidString,
            name: name,
            rssi: RSSI.intValue,
            peripheral: peripheral,
            isPriority: isPriority
        )
        
        // Add if not already in list
        if !discoveredDevices.contains(where: { $0.id == newDevice.id }) {
            // Add and sort with priority devices first
            DispatchQueue.main.async {
                self.discoveredDevices.append(newDevice)
                self.discoveredDevices.sort {
                    if $0.isPriority && !$1.isPriority { return true }
                    if !$0.isPriority && $1.isPriority { return false }
                    return $0.name < $1.name
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Connected to \(peripheral.name ?? "Unknown Device")")
        peripheral.delegate = self
        
        // Discover services - don't filter by UUID since we connected based on name
        peripheral.discoverServices(nil)
        
        let device = BLEDevice(
            id: peripheral.identifier.uuidString,
            name: peripheral.name ?? "Connected Device",
            peripheral: peripheral
        )
        
        DispatchQueue.main.async {
            self.connectedDevice = device
            self.saveConnectedDevice()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            log("Disconnected from \(peripheral.name ?? "Unknown Device") with error: \(error.localizedDescription)")
        } else {
            log("Disconnected from \(peripheral.name ?? "Unknown Device")")
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDevice = nil
            self.batteryLevel = nil
            self.serialNumber = nil
            self.writeCharacteristic = nil
            self.notifyCharacteristic = nil
            self.serialNumberStatus = .notRequested
            self.batteryLevelStatus = .notRequested
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            log("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            log("No services found")
            return
        }
        
        log("Discovered \(services.count) services")
        
        var foundNeocoreService = false
        
        // For each service, discover the characteristics we need
        for service in services {
            log("Found service: \(service.uuid)")
            
            // Check if this is the Neocore service
            if service.uuid == serviceUUID {
                log("Found Neocore service")
                foundNeocoreService = true
                peripheral.discoverCharacteristics(
                    [writeCharacteristicUUID, notifyCharacteristicUUID],
                    for: service
                )
            }
        }
        
        if !foundNeocoreService {
            log("Warning: Neocore service not found among discovered services")
            // Still discover characteristics for all services in case the UUID is different
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            log("Error discovering characteristics for service \(service.uuid): \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            log("No characteristics found for service \(service.uuid)")
            return
        }
        
        log("Discovered \(characteristics.count) characteristics for service \(service.uuid)")
        
        var foundWrite = false
        var foundNotify = false
        
        // Store references to our characteristics
        for characteristic in characteristics {
            log("Found characteristic: \(characteristic.uuid)")
            
            if characteristic.uuid == writeCharacteristicUUID {
                log("Found write characteristic")
                writeCharacteristic = characteristic
                foundWrite = true
            } else if characteristic.uuid == notifyCharacteristicUUID {
                log("Found notify characteristic")
                notifyCharacteristic = characteristic
                foundNotify = true
                
                // Enable notifications
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // If we're looking at the Neocore service but didn't find our characteristics
        if service.uuid == serviceUUID {
            if !foundWrite {
                log("Warning: Write characteristic not found in Neocore service")
            }
            if !foundNotify {
                log("Warning: Notify characteristic not found in Neocore service")
            }
        }
        
        // If we have both characteristics, we're ready to communicate
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            log("Found both write and notify characteristics - device is ready for communication")
            
            DispatchQueue.main.async {
                self.isConnected = true
                
                // Request serial number and battery level with a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.readSerialNumber()
                    
                    // Request battery level after serial number
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.readBatteryLevel()
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("Error receiving characteristic update: \(error.localizedDescription)")
            return
        }
        
        // Handle notify characteristic updates
        if characteristic.uuid == notifyCharacteristicUUID, let data = characteristic.value {
            log("Received data on notify characteristic: \(data.hexDescription)")
            parseResponse(data: data)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("Error writing to characteristic: \(error.localizedDescription)")
        } else {
            log("Successfully wrote to characteristic: \(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("Error changing notification state: \(error.localizedDescription)")
        } else {
            log("Notification state updated for \(characteristic.uuid)")
            if characteristic.isNotifying {
                log("Notifications enabled")
            } else {
                log("Notifications disabled")
            }
        }
    }
}

// MARK: - Supporting Models
enum PermissionStatus {
    case unknown
    case notDetermined
    case denied
    case poweredOff
    case unsupported
    case authorized
}

enum CommandStatus {
    case notRequested
    case requested
    case success
    case error
    case timeout
}

struct DiscoveredDevice: Identifiable {
    let id: String
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral?
    let isPriority: Bool
}

struct BLEDevice: Identifiable {
    let id: String
    let name: String
    let peripheral: CBPeripheral?
}

// MARK: - Utility Extension
extension Data {
    var hexDescription: String {
        return self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
