import Foundation
import CoreBluetooth
import Combine

class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()
    
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var batteryLevel: Int?
    @Published var serialNumber: String?
    @Published var firmwareVersion: String?
    @Published var deviceName: String?
    @Published var deviceMac: String?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var bluetoothState: CBManagerState = .unknown
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    private var discoveredDeviceIDs = Set<UUID>() // Track already discovered devices
    
    // Auto-connect storage
    private let lastConnectedDeviceKey = "neocore_last_connected_device"
    
    // UUIDs from Neocore documentation
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxCharUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txCharUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    // MARK: - Feature and Command IDs
    private let NEOCORE_CORE_FEATURE_ID: UInt8 = 0x00
    private let NEOCORE_BATTERY_FEATURE_ID: UInt8 = 0x04
    
    private let NEOCORE_CMD_ID_GET_API_VER: UInt8 = 0x00
    private let NEOCORE_CMD_ID_GET_SERIAL_NUM: UInt8 = 0x01
    private let NEOCORE_CMD_ID_GET_FW_VER: UInt8 = 0x03
    private let NEOCORE_CMD_ID_GET_BATTERY_LEVEL: UInt8 = 0x00
    
    // MARK: - Initialization
    override private init() {
        super.init()
        print("BLEManager: Initializing")
        // Create the central manager on the main queue explicitly
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("BLEManager: Cannot start scanning, Bluetooth is not powered on (state: \(centralManager.state.rawValue))")
            return
        }
        
        print("BLEManager: Starting scan")
        // Clear discovered devices before starting new scan
        DispatchQueue.main.async {
            self.discoveredDevices.removeAll()
            self.discoveredDeviceIDs.removeAll()
            self.isScanning = true
            self.connectionState = .scanning
        }
        
        // Scan for all devices to ensure we catch everything
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        // Add a timeout to stop scanning after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            if self.isScanning {
                print("BLEManager: Scan timeout reached")
                self.stopScanning()
            }
        }
    }
    
    func stopScanning() {
        print("BLEManager: Stopping scan")
        centralManager.stopScan()
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        print("BLEManager: Connecting to \(peripheral.name ?? "Unknown")")
        DispatchQueue.main.async {
            self.connectionState = .connecting
        }
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            print("BLEManager: Disconnecting from \(peripheral.name ?? "Unknown")")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func attemptAutoConnect() {
        if centralManager.state != .poweredOn {
            print("BLEManager: Cannot auto-connect, Bluetooth is not powered on")
            DispatchQueue.main.async {
                self.connectionState = .bluetoothOff
            }
            return
        }
        
        guard let savedID = UserDefaults.standard.string(forKey: lastConnectedDeviceKey),
              let uuid = UUID(uuidString: savedID) else {
            print("BLEManager: No saved device to reconnect to")
            DispatchQueue.main.async {
                self.connectionState = .disconnected
            }
            return
        }
        
        print("BLEManager: Attempting to reconnect to \(savedID)")
        DispatchQueue.main.async {
            self.connectionState = .reconnecting
        }
        
        // Look for the previously connected device
        let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = knownPeripherals.first {
            print("BLEManager: Found saved peripheral, attempting connection")
            connect(to: peripheral)
        } else {
            // If we can't find the device by UUID, try retrieving connected peripherals
            print("BLEManager: Couldn't find saved peripheral by UUID, checking connected peripherals")
            let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
            if let peripheral = connectedPeripherals.first {
                print("BLEManager: Found connected peripheral with service, connecting")
                connect(to: peripheral)
            } else {
                print("BLEManager: No connected peripherals found, starting scan")
                startScanning()
            }
        }
    }
    
    // MARK: - Helper Methods
    func isNeocore(_ peripheral: CBPeripheral) -> Bool {
        guard let name = peripheral.name else { return false }
        return name.uppercased().starts(with: "NEOCORE")
    }
    
    func isQCC(_ peripheral: CBPeripheral) -> Bool {
        guard let name = peripheral.name?.uppercased() else { return false }
        return name.contains("QCC5181") || name.contains("QCC5181")
    }
    
    // MARK: - Device Commands
    func requestBatteryLevel() {
        print("BLEManager: Requesting battery level")
        sendCommand(featureID: NEOCORE_BATTERY_FEATURE_ID, commandID: NEOCORE_CMD_ID_GET_BATTERY_LEVEL)
    }
    
    func requestSerialNumber() {
        print("BLEManager: Requesting serial number")
        sendCommand(featureID: NEOCORE_CORE_FEATURE_ID, commandID: NEOCORE_CMD_ID_GET_SERIAL_NUM)
    }
    
    func requestFirmwareVersion() {
        print("BLEManager: Requesting firmware version")
        sendCommand(featureID: NEOCORE_CORE_FEATURE_ID, commandID: NEOCORE_CMD_ID_GET_FW_VER)
    }
    
    // MARK: - Send Commands
    private func sendCommand(featureID: UInt8, commandID: UInt8, payload: Data? = nil) {
        guard let rxChar = characteristics[rxCharUUID],
              let peripheral = connectedPeripheral else {
            print("BLEManager: Cannot send command, no connected peripheral or characteristic")
            return
        }
        
        // PDU Format per Neocore doc:
        // - Feature ID (7 bits)
        // - PDU Type (2 bits) - 00 for command
        // - PDU Specific ID (7 bits) - Command ID
        
        // Build packet
        var pduData = Data()
        let byte1 = (featureID << 1) | 0x00 // Feature ID + PDU Type (first bit)
        let byte2 = commandID << 1 // PDU Specific ID
        
        pduData.append(byte1)
        pduData.append(byte2)
        
        if let payload = payload {
            pduData.append(payload)
        }
        
        print("BLEManager: Sending command - Feature: \(featureID), Command: \(commandID)")
        peripheral.writeValue(pduData, for: rxChar, type: .withResponse)
    }
    
    // MARK: - Testing Method
    func simulateConnection() {
        // For testing UI without actual device
        print("BLEManager: Simulating connection")
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionState = .connected
            self.deviceName = "NeoBrain QCC5181"
            self.batteryLevel = 85
            self.serialNumber = "NS12345678"
            self.firmwareVersion = "v1.0.5"
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.bluetoothState = central.state
        }
        print("BLEManager: Bluetooth state changed to: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            print("BLEManager: Bluetooth powered on")
            if connectionState == .reconnecting || connectionState == .bluetoothOff {
                print("BLEManager: Attempting auto-connect after state change")
                attemptAutoConnect()
            }
        case .poweredOff:
            print("BLEManager: Bluetooth powered off")
            DispatchQueue.main.async {
                self.connectionState = .bluetoothOff
                self.isConnected = false
            }
        case .unauthorized:
            print("BLEManager: Bluetooth unauthorized")
            DispatchQueue.main.async {
                self.connectionState = .unauthorized
            }
        case .unsupported:
            print("BLEManager: Bluetooth unsupported")
            DispatchQueue.main.async {
                self.connectionState = .unsupported
            }
        default:
            print("BLEManager: Bluetooth in other state: \(central.state.rawValue)")
            DispatchQueue.main.async {
                self.connectionState = .disconnected
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Only add peripherals with names to the list
        guard let name = peripheral.name, !name.isEmpty else {
            return
        }
        
        print("BLEManager: Discovered \(name) with UUID: \(peripheral.identifier)")
        
        // Only process if we haven't seen this device before in this scan session
        if !discoveredDeviceIDs.contains(peripheral.identifier) {
            discoveredDeviceIDs.insert(peripheral.identifier)
            
            // Explicitly update UI on main thread and use a copy operation
            DispatchQueue.main.async {
                var updatedDevices = self.discoveredDevices
                updatedDevices.append(peripheral)
                self.discoveredDevices = updatedDevices
                
                print("BLEManager: Added device to list, total count: \(self.discoveredDevices.count)")
            }
        }
        
        // If this is our saved device, connect automatically
        if let savedID = UserDefaults.standard.string(forKey: self.lastConnectedDeviceKey),
           peripheral.identifier.uuidString == savedID {
            print("BLEManager: Found previously connected device, connecting automatically")
            self.stopScanning()
            self.connect(to: peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("BLEManager: Connected to \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionState = .connected
            
            // Update device name
            self.deviceName = peripheral.name
        }
        
        // Save for future auto-connection
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: self.lastConnectedDeviceKey)
        UserDefaults.standard.synchronize()
        
        // Set up peripheral delegate and discover services
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("BLEManager: Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "No error details")")
        DispatchQueue.main.async {
            self.connectionState = .failed
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("BLEManager: Disconnected from \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "No error")")
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionState = .disconnected
            self.connectedPeripheral = nil
            self.characteristics.removeAll()
        }
    }
}


// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("BLEManager: Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("BLEManager: No services discovered")
            return
        }
        
        print("BLEManager: Discovered \(services.count) services")
        
        for service in services {
            print("BLEManager: Discovering characteristics for service: \(service.uuid)")
            peripheral.discoverCharacteristics([rxCharUUID, txCharUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("BLEManager: Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("BLEManager: No characteristics discovered")
            return
        }
        
        print("BLEManager: Discovered \(characteristics.count) characteristics")
        
        for characteristic in characteristics {
            print("BLEManager: Found characteristic: \(characteristic.uuid)")
            // Store for future use
            self.characteristics[characteristic.uuid] = characteristic
            
            // Enable notifications for TxChar
            if characteristic.uuid == txCharUUID {
                print("BLEManager: Enabling notifications for TX characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // Request initial device information after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            print("BLEManager: Requesting initial device information")
            self?.requestBatteryLevel()
            self?.requestSerialNumber()
            self?.requestFirmwareVersion()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("BLEManager: Error updating characteristic value: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("BLEManager: No data in characteristic update")
            return
        }
        
        print("BLEManager: Received data: \(data.hexDescription)")
        
        // Process the response based on the PDU format
        if characteristic.uuid == txCharUUID {
            handleDeviceResponse(data)
        }
    }
    
    private func handleDeviceResponse(_ data: Data) {
        // Parse the PDU format
        if data.count < 2 {
            print("BLEManager: Response data too short")
            return
        }
        
        let byte1 = data[0]
        let byte2 = data[1]
        
        let featureID = byte1 >> 1
        let pduType = ((byte1 & 0x01) << 1) | (byte2 >> 7)
        let specificID = (byte2 >> 1) & 0x3F
        
        print("BLEManager: Parsed response - Feature: \(featureID), PDU Type: \(pduType), Specific ID: \(specificID)")
        
        // For the purpose of our demo, simulate some data
        // In a real implementation, you'd parse the actual response payload here
        DispatchQueue.main.async {
            if featureID == self.NEOCORE_BATTERY_FEATURE_ID {
                let level = Int.random(in: 30...100)
                print("BLEManager: Setting battery level to \(level)%")
                self.batteryLevel = level
            } else if featureID == self.NEOCORE_CORE_FEATURE_ID {
                if specificID == self.NEOCORE_CMD_ID_GET_SERIAL_NUM {
                    let serialNumber = "NS" + String(format: "%08X", Int.random(in: 0...0xFFFFFFFF))
                    print("BLEManager: Setting serial number to \(serialNumber)")
                    self.serialNumber = serialNumber
                } else if specificID == self.NEOCORE_CMD_ID_GET_FW_VER {
                    let firmwareVersion = "v1.0.\(Int.random(in: 1...9))"
                    print("BLEManager: Setting firmware version to \(firmwareVersion)")
                    self.firmwareVersion = firmwareVersion
                }
            }
        }
    }
}

// MARK: - Connection State Enum
enum ConnectionState: String {
    case disconnected = "Disconnected"
    case scanning = "Scanning for devices"
    case connecting = "Connecting"
    case connected = "Connected"
    case reconnecting = "Reconnecting"
    case failed = "Connection failed"
    case bluetoothOff = "Bluetooth is turned off"
    case unauthorized = "Bluetooth permission denied"
    case unsupported = "Bluetooth not supported"
}

// MARK: - Helper Extensions
extension Data {
    var hexDescription: String {
        return self.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}
