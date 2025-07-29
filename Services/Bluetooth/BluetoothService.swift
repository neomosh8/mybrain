import Foundation
import CoreBluetooth
import Combine
import Accelerate

//typealias BTService = BluetoothService
typealias BTService = MockBluetoothService

class BluetoothService: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    static let shared = BluetoothService()
    private var onlineFilter = OnlineFilter()
    
    private let feedbackSubject = PassthroughSubject<Double, Never>()
    
    var feedbackPublisher: AnyPublisher<Double, Never> {
        feedbackSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Simulation state
    private var simPhase: Double = 0.0
    private let simStep: Double = 0.15
    
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
    private let EEG_PACKET_TYPE: UInt8 = 0x02 // Updated from 0x04 to match Python
    private let HEADER_BYTES: Int = 2       // Feature + PDU header trimmed by Python client
    
    private let SAMPLE_RATE = 250
    private let SAMPLES_PER_CHUNK = 27
    private let NUM_CHANNELS = 2
    
    private let SIGNAL_BANDS: [String: (low: Double, high: Double)] = [
        "delta": (1, 4),
        "theta": (4, 8),
        "alpha": (8, 12),
        "beta": (13, 30),
        "gamma": (30, 45)
    ]
    private let NOISE_BAND = (45.0, 100.0)
    
    
    @Published var isInNormalMode = false  // True for normal mode, false for test signal mode
    @Published var isLeadOffDetectionEnabled = false
    private let NEOCORE_CMD_ID_EEG_LEAD_OFF_CTRL: UInt16 = 0x02
    private var isInTestMode = false
    @Published var ch1ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    @Published var ch2ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    private var leadOffAnalysisTimer: Timer?
    private var qualityAnalysisTimer: Timer?
    
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
    
    func autoConnect() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not ready, waiting for powered on state")
            return
        }
        
        // If we have a saved device, try to reconnect
        if let savedID = UserDefaults.standard.string(forKey: savedDeviceKey) {
            print("Attempting to auto-connect to saved device: \(savedID)")
            reconnectToPreviousDevice()
        } else {
            // Start scanning for new devices
            print("No saved device, starting scan")
            startScanning()
        }
    }
    
    func connect(to device: DiscoveredDevice) {
        guard let peripheral = device.peripheral else { return }
        self.peripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        removeSavedDevice()
    }
    
    func saveConnectedDevice() {
        guard let device = connectedDevice else { return }
        UserDefaults.standard.set(device.id, forKey: savedDeviceKey)
    }
    
    func removeSavedDevice() {
        UserDefaults.standard.removeObject(forKey: savedDeviceKey)
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
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not ready for reconnection")
            return
        }
        
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
        
        onlineFilter = OnlineFilter()
        
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
        
        if isReceivingTestData {
            startQualityAnalysis()
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
    
    
    private func startQualityAnalysis() {
        qualityAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  !self.eegChannel1.isEmpty,
                  !self.eegChannel2.isEmpty else { return }
            
            let (ch1Metrics, ch2Metrics) = self.analyzeSignalQuality(
                channel1: self.eegChannel1,
                channel2: self.eegChannel2
            )
            
            // Process or display metrics as needed
            print("Signal Quality - CH1 SNR: \(ch1Metrics?.snr.totalSNRdB ?? 0) dB, CH2 SNR: \(ch2Metrics?.snr.totalSNRdB ?? 0) dB")
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
            
            // Clear data and reset flags after everything is stopped
            DispatchQueue.main.async {
                self?.eegChannel1 = []
                self?.eegChannel2 = []
                self?.isInNormalMode = false
                self?.isLeadOffDetectionEnabled = false
                self?.ch1ConnectionStatus = (false, 0.0)
                self?.ch2ConnectionStatus = (false, 0.0)
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
        guard data.count > HEADER_BYTES else {
            print("Invalid data: too short")
            return
        }
        
        // First two bytes are Feature ID + PDU header in the new protocol
        let payload = data.dropFirst(HEADER_BYTES)
        guard let packetType = payload.first else { return }
        
        // EEG streaming packets
        if packetType == EEG_PACKET_TYPE {
            handleEEGDataPacket(Data(payload))
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
        // [0] Packet Type (0x02)
        // [1] Payload length
        // [2..3] Message index (little-endian)
        // [4...] Interleaved samples (ch1 4-bytes, ch2 4-bytes)
        guard data.count >= 4 else {
            print("EEG packet too short: \(data.count) bytes")
            return
        }
        
        let payloadLength = Int(data[1])
        
        guard payloadLength > 0 && payloadLength <= 216 else {  // 27 samples * 2 channels * 4 bytes
            print("Invalid payload length: \(payloadLength)")
            return
        }
        
        let messageIndex = UInt16(data[2]) | (UInt16(data[3]) << 8)
        
        print("EEG Packet: Type=0x02, Length=\(payloadLength), Index=\(messageIndex)")
        
        // Calculate expected total packet size
        let expectedSize = 4 + payloadLength // header + payload
        guard data.count >= expectedSize else {
            print("Packet size mismatch: expected \(expectedSize), got \(data.count)")
            return
        }
        
        // Extract samples data
        let samples = data.subdata(in: 4..<(4 + payloadLength))
        
        // Process interleaved channel data
        var ch1Doubles = [Double]()
        var ch2Doubles = [Double]()
        
        for i in stride(from: 0, to: samples.count - 7, by: 8) {
            // Parse little-endian Int32 values
            let ch1Val = samples.subdata(in: i..<i+4).withUnsafeBytes { $0.load(as: Int32.self) }
            let ch2Val = samples.subdata(in: i+4..<i+8).withUnsafeBytes { $0.load(as: Int32.self) }
            
            ch1Doubles.append(Double(ch1Val))
            ch2Doubles.append(Double(ch2Val))
        }
        
        print("Parsed \(ch1Doubles.count) samples for each channel")
        
        // Apply filtering before storing
        ch1Doubles = ch1Doubles.map { Double($0) }
        ch2Doubles = ch2Doubles.map { Double($0) }
        
        // Apply online filtering (matching Python implementation)
        onlineFilter.apply(to: &ch1Doubles, &ch2Doubles)
        
        // Convert back to Int32 for storage
        let filteredCh1 = ch1Doubles.map { Int32($0) }
        let filteredCh2 = ch2Doubles.map { Int32($0) }
        
        // Only append data if we're receiving data
        if isReceivingTestData && isInTestMode {
            DispatchQueue.main.async {
                self.eegChannel1.append(contentsOf: filteredCh1)
                self.eegChannel2.append(contentsOf: filteredCh2)
                
                // Keep buffer bounded (matching Python's buffer_size logic)
                let maxStoredSamples = 5000 // 20 seconds at 250Hz
                if self.eegChannel1.count > maxStoredSamples {
                    self.eegChannel1.removeFirst(self.eegChannel1.count - maxStoredSamples)
                }
                if self.eegChannel2.count > maxStoredSamples {
                    self.eegChannel2.removeFirst(self.eegChannel2.count - maxStoredSamples)
                }
                
                print("Updated EEG channels: CH1=\(self.eegChannel1.count), CH2=\(self.eegChannel2.count)")
            }
        }
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
    
    func processFeedback(word: String) -> Double {
        let value: Double
        if isConnected {
            value = calculateSignalValue()
        } else {
            value = generateSimulatedValue(for: word)
        }
        
        feedbackSubject.send(value)
        
        return value
    }
    
    private func calculateSignalValue() -> Double {
        // Take last few samples from each channel and average them
        let ch1Samples = eegChannel1.suffix(10)
        let ch2Samples = eegChannel2.suffix(10)
        
        if ch1Samples.isEmpty && ch2Samples.isEmpty {
            return 0.0 // Fallback if no data
        }
        
        let ch1Avg = ch1Samples.isEmpty ? 0 : Double(ch1Samples.reduce(0, +)) / Double(ch1Samples.count)
        let ch2Avg = ch2Samples.isEmpty ? 0 : Double(ch2Samples.reduce(0, +)) / Double(ch2Samples.count)
        
        let raw = (ch1Avg + ch2Avg) / 2.0
        return raw
    }
    
    
    private func generateSimulatedValue(for word: String) -> Double {
        let raw = sin(simPhase)
        
        // [0..100]
        let value = raw * 50 + 50
        
        simPhase += simStep
        if simPhase > .pi * 2 { simPhase -= .pi * 2 }
        
        return value
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
    
    
    private func analyzeSignalQuality(channel1: [Int32], channel2: [Int32]) -> (ch1: SignalQualityMetrics?, ch2: SignalQualityMetrics?) {
        guard channel1.count >= Int(SAMPLE_RATE * 2) else { return (nil, nil) }
        
        let ch1Data = channel1.suffix(Int(SAMPLE_RATE * 5)).map { Double($0) }
        let ch2Data = channel2.suffix(Int(SAMPLE_RATE * 5)).map { Double($0) }
        
        let ch1Metrics = calculateQualityMetrics(for: ch1Data)
        let ch2Metrics = calculateQualityMetrics(for: ch2Data)
        
        return (ch1Metrics, ch2Metrics)
    }
    
    private func calculateQualityMetrics(for data: [Double]) -> SignalQualityMetrics? {
        // Calculate dynamic range
        let dr = calculateDynamicRange(data)
        
        // Calculate SNR using Welch's method
        let snr = calculateSNR(data)
        
        return SignalQualityMetrics(dynamicRange: dr, snr: snr)
    }
    
    
    private func calculateDynamicRange(_ data: [Double]) -> DynamicRange {
        guard !data.isEmpty else {
            return DynamicRange(linear: 0, db: 0, peakToPeak: 0, rms: 0, max: 0, min: 0)
        }
        
        // Remove DC component
        var mean: Double = 0
        vDSP_meanvD(data, 1, &mean, vDSP_Length(data.count))
        let signalAC = data.map { $0 - mean }
        
        // Peak-to-peak dynamic range
        var max: Double = 0
        var min: Double = 0
        vDSP_maxvD(signalAC, 1, &max, vDSP_Length(signalAC.count))
        vDSP_minvD(signalAC, 1, &min, vDSP_Length(signalAC.count))
        let peakToPeak = max - min
        
        // RMS value
        var rms: Double = 0
        vDSP_measqvD(signalAC, 1, &rms, vDSP_Length(signalAC.count))
        rms = sqrt(rms)
        
        // Dynamic range in dB
        let absValues = signalAC.map { abs($0) }
        var maxAbs: Double = 0
        var minAbs: Double = 0
        vDSP_maxvD(absValues, 1, &maxAbs, vDSP_Length(absValues.count))
        
        // Find minimum non-zero value
        let nonZeroValues = absValues.filter { $0 > 0 }
        if !nonZeroValues.isEmpty {
            vDSP_minvD(nonZeroValues, 1, &minAbs, vDSP_Length(nonZeroValues.count))
        } else {
            minAbs = 1e-10
        }
        
        let drDB = minAbs > 0 ? 20 * log10(maxAbs / minAbs) : 0
        let linear = minAbs > 0 ? maxAbs / minAbs : 0
        
        return DynamicRange(
            linear: linear,
            db: drDB,
            peakToPeak: peakToPeak,
            rms: rms,
            max: maxAbs,
            min: minAbs
        )
    }
    
    private func calculateSNR(_ data: [Double]) -> SignalToNoiseRatio {
        guard data.count >= SAMPLE_RATE else {
            return SignalToNoiseRatio(
                totalSNRdB: 0,
                bandSNR: [:],
                signalPower: 0,
                noisePower: 0
            )
        }
        
        // Calculate power spectral density using Welch's method
        let nperseg = min(data.count / 4, SAMPLE_RATE)
        let (freqs, psd) = welch(data, fs: Double(SAMPLE_RATE), nperseg: nperseg)
        
        // Calculate power in signal bands
        var signalPower: Double = 0
        var bandSNR: [String: Double] = [:]
        
        for (bandName, (low, high)) in SIGNAL_BANDS {
            let bandPower = calculateBandPower(freqs: freqs, psd: psd, lowFreq: low, highFreq: high)
            signalPower += bandPower
            bandSNR[bandName] = bandPower
        }
        
        // Calculate noise power
        let noisePower = calculateBandPower(
            freqs: freqs,
            psd: psd,
            lowFreq: NOISE_BAND.0,
            highFreq: NOISE_BAND.1
        )
        
        // Total SNR
        let totalSNRdB = noisePower > 0 ? 10 * log10(signalPower / noisePower) : 0
        
        // Band-specific SNR
        for bandName in bandSNR.keys {
            if let bandPower = bandSNR[bandName], noisePower > 0 {
                bandSNR[bandName] = 10 * log10(bandPower / noisePower)
            } else {
                bandSNR[bandName] = 0
            }
        }
        
        return SignalToNoiseRatio(
            totalSNRdB: totalSNRdB,
            bandSNR: bandSNR,
            signalPower: signalPower,
            noisePower: noisePower
        )
    }
    
    // Helper method for Welch's method implementation
    private func welch(_ data: [Double], fs: Double, nperseg: Int) -> (freqs: [Double], psd: [Double]) {
        let noverlap = nperseg / 2
        let step = nperseg - noverlap
        
        var psdAccumulator = [Double](repeating: 0, count: nperseg / 2 + 1)
        var segmentCount = 0
        
        // Create FFT setup once
        let log2n = vDSP_Length(log2(Double(nperseg)))
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return ([], [])
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }
        
        // Process overlapping segments
        for start in stride(from: 0, to: data.count - nperseg + 1, by: step) {
            let segment = Array(data[start..<start + nperseg])
            
            // Apply Hann window
            var windowedSegment = [Double](repeating: 0, count: nperseg)
            var window = [Double](repeating: 0, count: nperseg)
            vDSP_hann_windowD(&window, vDSP_Length(nperseg), Int32(vDSP_HANN_NORM))
            vDSP_vmulD(segment, 1, window, 1, &windowedSegment, 1, vDSP_Length(nperseg))
            
            // Compute FFT and PSD
            var realPart = windowedSegment
            var imagPart = [Double](repeating: 0, count: nperseg)
            var segmentPSD = [Double](repeating: 0, count: nperseg / 2 + 1)
            
            realPart.withUnsafeMutableBufferPointer { realBuffer in
                imagPart.withUnsafeMutableBufferPointer { imagBuffer in
                    var splitComplex = DSPDoubleSplitComplex(
                        realp: realBuffer.baseAddress!,
                        imagp: imagBuffer.baseAddress!
                    )
                    
                    // Perform FFT
                    vDSP_fft_zipD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // Calculate power spectrum
                    vDSP_zvmagsD(&splitComplex, 1, &segmentPSD, 1, vDSP_Length(nperseg / 2))
                }
            }
            
            // Handle DC component
            segmentPSD[0] = realPart[0] * realPart[0]
            
            // Scale
            var scale = 2.0 / (fs * Double(nperseg))
            vDSP_vsmulD(segmentPSD, 1, &scale, &segmentPSD, 1, vDSP_Length(segmentPSD.count))
            segmentPSD[0] /= 2.0
            
            // Accumulate
            vDSP_vaddD(psdAccumulator, 1, segmentPSD, 1, &psdAccumulator, 1, vDSP_Length(segmentPSD.count))
            segmentCount += 1
        }
        
        // Average
        var scale = 1.0 / Double(segmentCount)
        vDSP_vsmulD(psdAccumulator, 1, &scale, &psdAccumulator, 1, vDSP_Length(psdAccumulator.count))
        
        // Generate frequency array
        let freqs = (0..<psdAccumulator.count).map { Double($0) * fs / Double(nperseg) }
        
        return (freqs, psdAccumulator)
    }
    
    // Helper method to compute PSD of a segment
    private func computePSD(_ segment: [Double], fs: Double) -> [Double] {
        let n = segment.count
        let log2n = vDSP_Length(log2(Double(n)))
        
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return [Double](repeating: 0, count: n / 2 + 1)
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }
        
        // Prepare for FFT
        var realPart = segment
        var imagPart = [Double](repeating: 0, count: n)
        var powerSpectrum = [Double](repeating: 0, count: n / 2 + 1)
        
        // Use withUnsafeMutablePointer to ensure pointer validity
        realPart.withUnsafeMutableBufferPointer { realBuffer in
            imagPart.withUnsafeMutableBufferPointer { imagBuffer in
                var splitComplex = DSPDoubleSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imagBuffer.baseAddress!
                )
                
                // Perform FFT
                vDSP_fft_zipD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                // Calculate power spectrum
                vDSP_zvmagsD(&splitComplex, 1, &powerSpectrum, 1, vDSP_Length(n / 2))
            }
        }
        
        // Handle DC and Nyquist
        powerSpectrum[0] = realPart[0] * realPart[0]
        if n % 2 == 0 {
            powerSpectrum[n / 2] = realPart[n / 2] * realPart[n / 2]
        }
        
        // Scale for PSD
        var scale = 2.0 / (fs * Double(n))
        vDSP_vsmulD(powerSpectrum, 1, &scale, &powerSpectrum, 1, vDSP_Length(powerSpectrum.count))
        
        // DC and Nyquist don't get doubled
        powerSpectrum[0] /= 2.0
        if n % 2 == 0 {
            powerSpectrum[n / 2] /= 2.0
        }
        
        return powerSpectrum
    }
    
    // Helper method to calculate band power
    private func calculateBandPower(freqs: [Double], psd: [Double], lowFreq: Double, highFreq: Double) -> Double {
        var power: Double = 0
        
        for i in 0..<freqs.count {
            if freqs[i] >= lowFreq && freqs[i] <= highFreq {
                if i > 0 {
                    // Trapezoidal integration
                    let df = freqs[i] - freqs[i-1]
                    power += (psd[i] + psd[i-1]) * df / 2.0
                }
            }
        }
        
        return power
    }
    
    
    private func buildStreamCommand(_ start: Bool) -> Data {
        let payload = Data([start ? 0x01 : 0x00])
        return buildCommand(
            featureId: NEOCORE_SENSOR_CFG_FEATURE_ID,
            pduId: NEOCORE_CMD_ID_DATA_STREAM_CTRL,
            payload: payload
        )
    }
    
    private func buildCommand(featureId: UInt16, pduId: UInt16, payload: Data?) -> Data {
        let commandId = (featureId << 9) | (PDU_TYPE_COMMAND << 7) | pduId
        var data = Data()
        data.append(UInt8((commandId >> 8) & 0xFF))
        data.append(UInt8(commandId & 0xFF))
        if let payload = payload {
            data.append(payload)
        }
        return data
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        checkPermissions()
        
        switch central.state {
        case .poweredOn:
            print("Bluetooth powered on, ready for operations")
            reconnectToPreviousDevice()
        case .poweredOff:
            print("Bluetooth powered off")
        case .unauthorized:
            print("Bluetooth unauthorized")
        default:
            print("Bluetooth state: \(central.state.rawValue)")
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
                
                // Request larger MTU for better throughput (matching Python's 247)
                // Note: iOS will negotiate the actual MTU with the peripheral
                if #available(iOS 9.0, *) {
                    print("Requesting MTU update...")
                    // The actual MTU request happens automatically in iOS
                    // We can check the negotiated MTU value
                    let currentMTU = peripheral.maximumWriteValueLength(for: .withResponse)
                    print("Current MTU for writes: \(currentMTU)")
                }
                
                // Request serial number and battery level after connection is fully established
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

struct SignalQualityMetrics {
    let dynamicRange: DynamicRange
    let snr: SignalToNoiseRatio
}

struct DynamicRange {
    let linear: Double
    let db: Double
    let peakToPeak: Double
    let rms: Double
    let max: Double
    let min: Double
}

struct SignalToNoiseRatio {
    let totalSNRdB: Double
    let bandSNR: [String: Double]
    let signalPower: Double
    let noisePower: Double
}

// MARK: - Utility Extension
extension Data {
    var hexDescription: String {
        return self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
