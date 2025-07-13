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
    private var autoStartStreaming = false
    // Test signal related properties
    @Published var isTestSignalEnabled = false
    @Published var isStreamingEnabled = false
    @Published var testSignalData: [Int32] = []
    @Published var isReceivingTestData = false
    @Published var eegChannel1: [Int32] = []
    @Published var eegChannel2: [Int32] = []
    private let EEG_PACKET_TYPE: UInt8 = 0x04
    @Published var isInNormalMode = false  // True for normal mode, false for test signal mode
    @Published var isLeadOffDetectionEnabled = false
    private let NEOCORE_CMD_ID_EEG_LEAD_OFF_CTRL: UInt16 = 0x02
    private var isInTestMode = false
    @Published var ch1ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    @Published var ch2ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    private var leadOffAnalysisTimer: Timer?
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
    private let NEOCORE_CMD_ID_DATA_STREAM_CTRL: UInt16 = 0x00
    private let NEOCORE_CMD_ID_EEG_TEST_SIGNAL_CTRL: UInt16 = 0x01
    private let NEOCORE_NOTIFY_ID_EEG_DATA: UInt16 = 0x00
    
    // EEG data header (Feature=2 (Sensor Stream), Type=1 (Notification), ID=0 (EEG Data))
    private let EEG_DATA_HEADER: UInt16 = 0x0480
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()
    private let targetDevices = ["QCC5181", "QCC5181-LE", "NEOCORE"]
    private let savedDeviceKey = "savedBluetoothDeviceID"
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods for Device Discovery and Connection
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        discoveredDevices = []
        
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
    }
    
    func connect(to device: DiscoveredDevice) {
        guard let peripheral = device.peripheral else { return }
        self.peripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func saveConnectedDevice() {
        guard let device = connectedDevice else { return }
        UserDefaults.standard.set(device.id, forKey: savedDeviceKey)
    }
    
    private func enableLeadOffDetection(_ enable: Bool) {
        // Construct the Lead-Off Detection Control command
        // Feature ID: 0x01 (Sensor Configuration)
        // PDU Type: 0x00 (Command)
        // PDU Specific ID: 0x02 (Lead-Off Detection Control)
        let payload = Data([enable ? 0x01 : 0x00])
        
        sendCommand(
            featureId: NEOCORE_SENSOR_CFG_FEATURE_ID,
            pduType: PDU_TYPE_COMMAND,
            pduId: NEOCORE_CMD_ID_EEG_LEAD_OFF_CTRL,
            data: payload
        )
        
        print("Lead-off detection \(enable ? "enabled" : "disabled")")
        isLeadOffDetectionEnabled = enable
    }

    
    func reconnectToPreviousDevice() {
        guard let savedID = UserDefaults.standard.string(forKey: savedDeviceKey) else { return }
        
        // Start scanning to find the device
        startScanning()
        
        // Setup observer for the saved device
        $discoveredDevices
            .compactMap { devices in devices.first { $0.id == savedID } }
            .first()
            .sink { [weak self] device in
                self?.stopScanning()
                self?.connect(to: device)
            }
            .store(in: &cancellables)
    }
    
    func checkPermissions() {
        switch centralManager.state {
        case .poweredOn:
            permissionStatus = .authorized
        case .unauthorized:
            permissionStatus = .denied
        case .poweredOff:
            permissionStatus = .poweredOff
        case .resetting:
            permissionStatus = .unknown
        case .unsupported:
            permissionStatus = .unsupported
        case .unknown:
            permissionStatus = .notDetermined
        @unknown default:
            permissionStatus = .unknown
        }
    }
    
    // MARK: - Device Information Commands
    func readSerialNumber() {
        sendCommand(featureId: NEOCORE_CORE_FEATURE_ID,
                   pduType: PDU_TYPE_COMMAND,
                   pduId: NEOCORE_CMD_ID_GET_SERIAL_NUM,
                   data: nil)
    }
    
    func readBatteryLevel() {
        sendCommand(featureId: NEOCORE_BATTERY_FEATURE_ID,
                   pduType: PDU_TYPE_COMMAND,
                   pduId: NEOCORE_CMD_ID_GET_BATTERY_LEVEL,
                   data: nil)
    }
    
    // MARK: - Test Signal and Data Streaming
    // Replace these methods in your BluetoothService class

    // Fix the operator precedence issue in startRecording method
    func startRecording(useTestSignal: Bool, enableLeadOff: Bool = false) {
        // Reset data
        eegChannel1 = []
        eegChannel2 = []
        isTestSignalEnabled = false
        isStreamingEnabled = false
        isReceivingTestData = false
        isLeadOffDetectionEnabled = false
        isInTestMode = true
        isInNormalMode = !useTestSignal
        
        // Reset lead-off data
        SignalProcessing.resetLeadoffData()
        ch1ConnectionStatus = (false, 0.0)
        ch2ConnectionStatus = (false, 0.0)
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = nil
        
        print("Starting recording in \(useTestSignal ? "test signal" : "normal") mode with lead-off detection \(enableLeadOff ? "enabled" : "disabled")")
        
        // 1. Enable notifications on the characteristic
        if let notifyCharacteristic = notifyCharacteristic {
            peripheral?.setNotifyValue(true, for: notifyCharacteristic)
            print("Enabling notifications")
        }
        
        // 2. If using test signal, enable it (otherwise skip this step)
        if useTestSignal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isInTestMode else { return }
                
                print("Enabling test signal")
                self.enableTestSignal(true)
            }
        }
        
        // 3. If enabling lead-off detection, send the command
        if enableLeadOff {
            let leadOffDelay = useTestSignal ? 1.0 : 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + leadOffDelay) { [weak self] in
                guard let self = self, self.isInTestMode else { return }
                
                print("Enabling lead-off detection")
                self.enableLeadOffDetection(true)
            }
        }
        
        // 4. Enable streaming
        let streamingDelay = useTestSignal ? (enableLeadOff ? 1.5 : 1.0) : (enableLeadOff ? 1.0 : 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + streamingDelay) { [weak self] in
            guard let self = self, self.isInTestMode else { return }
            
            print("Enabling streaming")
            self.enableDataStreaming(true)
            
            // 5. Start collecting data
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isInTestMode else { return }
                
                self.isReceivingTestData = true
                print("Recording fully activated - collecting data with test signal: \(useTestSignal), lead-off: \(enableLeadOff)")
                
                // 6. Start lead-off analysis timer if lead-off detection is enabled
                if enableLeadOff {
                    self.startLeadOffAnalysis()
                }
            }
        }
    }

    // Add method to start lead-off analysis
    private func startLeadOffAnalysis() {
        // Create a timer that runs every second to analyze the data
        leadOffAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  self.isLeadOffDetectionEnabled,
                  !self.eegChannel1.isEmpty,
                  !self.eegChannel2.isEmpty else {
                return
            }
            
            // Process lead-off detection
            let result = SignalProcessing.processLeadoffDetection(
                ch1Data: self.eegChannel1,
                ch2Data: self.eegChannel2
            )
            
            // Update connection status
            DispatchQueue.main.async {
                self.ch1ConnectionStatus = (result.ch1Connected, result.ch1Quality)
                self.ch2ConnectionStatus = (result.ch2Connected, result.ch2Quality)
            }
        }
    }

    // Update stopRecording to clean up lead-off analysis
    func stopRecording() {
        print("Stopping recording")
        isInTestMode = false
        isReceivingTestData = false
        
        // Stop lead-off analysis
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = nil
        
        // 1. Disable streaming first
        enableDataStreaming(false)
        
        // 2. If test signal was enabled, disable it
        if isTestSignalEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.enableTestSignal(false)
            }
        }
        
        // 3. If lead-off detection was enabled, disable it
        if isLeadOffDetectionEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.enableLeadOffDetection(false)
            }
        }
        
        // 4. Finally disable notifications
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if let notifyCharacteristic = self?.notifyCharacteristic {
                self?.peripheral?.setNotifyValue(false, for: notifyCharacteristic)
            }
            
            // Reset flags after everything is stopped
            DispatchQueue.main.async {
                self?.isInNormalMode = false
                self?.isLeadOffDetectionEnabled = false
                self?.ch1ConnectionStatus = (false, 0.0)
                self?.ch2ConnectionStatus = (false, 0.0)
                // Don't clear EEG data here so it can be exported after recording
            }
        }
    }

    // Update the existing startTestDrive for backward compatibility
    func startTestDrive() {
        startRecording(useTestSignal: true, enableLeadOff: false)
    }

    func stopTestDrive() {
        stopRecording()
    }

    // Replace the handleEEGDataNotification method
    private func parseResponse(data: Data) {
        guard data.count >= 1 else {
            print("Invalid data: too short")
            return
        }
        
        // Extract packet type (first byte)
        let packetType = data[0]
        
        // Handle EEG data packets
        if packetType == EEG_PACKET_TYPE {
            handleEEGDataPacket(data)
            return
        }
        
        // For other packets, parse normally
        // Continue with your existing parsing for other packet types
        if packetType != EEG_PACKET_TYPE {
            // Extract header
            guard data.count >= 2 else { return }
            
            let headerByte1 = data[0]
            let headerByte2 = data[1]
            let commandId: UInt16 = (UInt16(headerByte1) << 8) | UInt16(headerByte2)
            
            // Parse header components
            let featureId = commandId >> 9
            let pduType = (commandId >> 7) & 0x03
            let pduId = commandId & 0x7F
            
            print("Received response: feature=\(featureId), type=\(pduType), id=\(pduId), command=0x\(String(format: "%04X", commandId))")
            
            // Handle based on response type
            if pduType == PDU_TYPE_RESPONSE {
                // Response to commands
                if featureId == NEOCORE_CORE_FEATURE_ID && pduId == NEOCORE_CMD_ID_GET_SERIAL_NUM {
                    handleSerialNumberResponse(data: data)
                } else if featureId == NEOCORE_BATTERY_FEATURE_ID && pduId == NEOCORE_CMD_ID_GET_BATTERY_LEVEL {
                    handleBatteryLevelResponse(data: data)
                }
            } else if pduType == PDU_TYPE_NOTIFICATION {
                // Other notifications handled here
                if featureId == NEOCORE_BATTERY_FEATURE_ID {
                    // Battery notification
                    handleBatteryLevelResponse(data: data)
                }
            } else if pduType == PDU_TYPE_ERROR {
                print("Received error response: \(data.hexDescription)")
            }
        }
    }
    
    private func handleEEGDataPacket(_ data: Data) {
        // EEG packet structure:
        // [Packet Type (1 byte)] [Payload Length (1 byte)] [Message Index (2 bytes)] [Channel Data...]
        
        // Ensure we have at least the header
        guard data.count >= 4 else {
            print("EEG packet too short")
            return
        }
        
        // Extract header fields
        let packetType = data[0]   // Should be 0x04
        let payloadLength = data[1]
        let messageIndex = UInt16(data[2]) | (UInt16(data[3]) << 8)
        
        print("EEG Packet: Type=\(packetType), Length=\(payloadLength), Index=\(messageIndex)")
        
        // Skip the 4-byte header to get to the channel data
        let channelData = data.subdata(in: 4..<data.count)
        
        // Process the interleaved channel data (each channel has 4-byte samples)
        var channel1Samples: [Int32] = []
        var channel2Samples: [Int32] = []
        
        // Process 8 bytes at a time (4 bytes per channel)
        for i in stride(from: 0, to: channelData.count, by: 8) {
            // Channel 1 (first 4 bytes)
            if i + 3 < channelData.count {
                let ch1Value = parseInt32(from: channelData, startIndex: i)
                channel1Samples.append(ch1Value)
            }
            
            // Channel 2 (next 4 bytes)
            if i + 7 < channelData.count {
                let ch2Value = parseInt32(from: channelData, startIndex: i + 4)
                channel2Samples.append(ch2Value)
            }
        }
        
        print("Parsed \(channel1Samples.count) samples for Channel 1")
        print("Parsed \(channel2Samples.count) samples for Channel 2")
        
        if channel1Samples.count > 0 {
            print("CH1 first sample: \(channel1Samples[0])")
        }
        
        if channel2Samples.count > 0 {
            print("CH2 first sample: \(channel2Samples[0])")
        }
        
        // Only append data if we're in test mode and receiving data
        if isReceivingTestData && isInTestMode {
            DispatchQueue.main.async {
                // Add the new samples to each channel
                self.eegChannel1.append(contentsOf: channel1Samples)
                self.eegChannel2.append(contentsOf: channel2Samples)
                

                // Previously we limited stored samples to the last 2000 points
                // which truncated longer recordings when exporting.
                // Remove this cap so we preserve all recorded data for export.
                
                print("Updated EEG channels: CH1=\(self.eegChannel1.count), CH2=\(self.eegChannel2.count)")
            }
        }
    }
    
    
    // Helper to parse Int32 from little-endian data
    private func parseInt32(from data: Data, startIndex: Int) -> Int32 {
        guard startIndex + 3 < data.count else { return 0 }
        
        // Little-endian format
        let byte0 = UInt32(data[startIndex])
        let byte1 = UInt32(data[startIndex + 1]) << 8
        let byte2 = UInt32(data[startIndex + 2]) << 16
        let byte3 = UInt32(data[startIndex + 3]) << 24
        
        return Int32(bitPattern: byte0 | byte1 | byte2 | byte3)
    }
    
    private func enableDataStreaming(_ enable: Bool) {
        // Construct the Data Stream Control command
        // Feature ID: 0x01 (Sensor Configuration)
        // PDU Type: 0x00 (Command)
        // PDU Specific ID: 0x00 (Data Stream Control)
        let payload = Data([enable ? 0x01 : 0x00])
        
        sendCommand(
            featureId: NEOCORE_SENSOR_CFG_FEATURE_ID,
            pduType: PDU_TYPE_COMMAND,
            pduId: NEOCORE_CMD_ID_DATA_STREAM_CTRL,
            data: payload
        )
        
        print("Data streaming \(enable ? "enabled" : "disabled")")
        isStreamingEnabled = enable
        
        // If disabling streaming, also clear the test data
        if !enable {
            testSignalData = []
        }
    }
    
    private func enableTestSignal(_ enable: Bool) {
        // Construct the Test Signal Control command
        // Feature ID: 0x01 (Sensor Configuration)
        // PDU Type: 0x00 (Command)
        // PDU Specific ID: 0x01 (Test Signal Control)
        let payload = Data([enable ? 0x01 : 0x00])
        
        sendCommand(
            featureId: NEOCORE_SENSOR_CFG_FEATURE_ID,
            pduType: PDU_TYPE_COMMAND,
            pduId: NEOCORE_CMD_ID_EEG_TEST_SIGNAL_CTRL,
            data: payload
        )
        
        print("Test signal \(enable ? "enabled" : "disabled")")
        isTestSignalEnabled = enable
        isReceivingTestData = enable
    }
    
    // MARK: - Command and Response Handling
    
    // Helper method to build and send commands
    private func sendCommand(featureId: UInt16, pduType: UInt16, pduId: UInt16, data: Data?) {
        guard let writeCharacteristic = writeCharacteristic,
              let peripheral = peripheral else {
            print("Cannot send command: write characteristic or peripheral not available")
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
        
        print("Sending command: \(String(format: "0x%04X", commandId)) with payload: \(commandData.hexDescription)")
        
        // Write the command
        peripheral.writeValue(commandData, for: writeCharacteristic, type: .withResponse)
    }
    
    // Parse incoming data packets
    
    private func handleSerialNumberResponse(data: Data) {
        guard data.count > 2 else {
            print("Invalid serial number response")
            return
        }
        
        // Extract payload (after the 2-byte header)
        let serialData = data.subdata(in: 2..<data.count)
        
        // Try to convert to string
        if let serialString = String(data: serialData, encoding: .utf8) {
            DispatchQueue.main.async {
                self.serialNumber = serialString
                print("Received serial number: \(serialString)")
            }
        } else {
            // If not a UTF-8 string, use hex representation
            let hexSerial = serialData.hexDescription
            DispatchQueue.main.async {
                self.serialNumber = hexSerial
                print("Received serial number (hex): \(hexSerial)")
            }
        }
    }
    
    private func handleBatteryLevelResponse(data: Data) {
        guard data.count >= 3 else {
            print("Invalid battery level response")
            return
        }
        
        // Battery level is in the first byte after the header
        let level = Int(data[2])
        
        DispatchQueue.main.async {
            self.batteryLevel = level
            print("Received battery level: \(level)%")
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
        print("Connected to \(peripheral.name ?? "Unknown Device")")
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
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device")")
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDevice = nil
            self.batteryLevel = nil
            self.serialNumber = nil
            self.writeCharacteristic = nil
            self.notifyCharacteristic = nil
            self.isTestSignalEnabled = false
            self.isStreamingEnabled = false
            self.isReceivingTestData = false
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("No services found")
            return
        }
        
        print("Discovered \(services.count) services")
        
        // For each service, discover the characteristics we need
        for service in services {
            print("Found service: \(service.uuid)")
            
            // Check if this is the Neocore service
            if service.uuid == serviceUUID {
                print("Found Neocore service")
                peripheral.discoverCharacteristics(
                    [writeCharacteristicUUID, notifyCharacteristicUUID],
                    for: service
                )
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("No characteristics found")
            return
        }
        
        print("Discovered \(characteristics.count) characteristics for service \(service.uuid)")
        
        // Store references to our characteristics
        for characteristic in characteristics {
            print("Found characteristic: \(characteristic.uuid)")
            
            if characteristic.uuid == writeCharacteristicUUID {
                print("Found write characteristic")
                writeCharacteristic = characteristic
            } else if characteristic.uuid == notifyCharacteristicUUID {
                print("Found notify characteristic")
                notifyCharacteristic = characteristic
                
                // Do NOT enable notifications automatically
                // We'll do this explicitly when needed
            }
        }
        
        // If we have both characteristics, we're ready to communicate
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            DispatchQueue.main.async {
                self.isConnected = true
                
                // Request serial number and battery level
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.readSerialNumber()
                    
                    // Request battery level after serial number
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.readBatteryLevel()
                    }
                }
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error receiving characteristic update: \(error!.localizedDescription)")
            return
        }
        
        // Handle notify characteristic updates
        if characteristic.uuid == notifyCharacteristicUUID, let data = characteristic.value {
            print("Received data: \(data.hexDescription)")
            parseResponse(data: data)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error.localizedDescription)")
        } else {
            print("Successfully wrote to characteristic")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error changing notification state: \(error.localizedDescription)")
        } else {
            print("Notification state updated for \(characteristic.uuid)")
            if characteristic.isNotifying {
                print("Notifications enabled")
            } else {
                print("Notifications disabled")
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
