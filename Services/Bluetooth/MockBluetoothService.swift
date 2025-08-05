import Foundation
import CoreBluetooth
import Combine

class MockBluetoothService: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    static let shared = MockBluetoothService()
        
    private let feedbackSubject = PassthroughSubject<Double, Never>()
    
    var feedbackPublisher: AnyPublisher<Double, Never> {
        feedbackSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Simulation state
    private var simPhase: Double = 0.0
    private let simStep: Double = 0.15
    
    private var scanDeviceIndex = 0
    
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
    @Published var isInNormalMode = false
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
    
    // EEG data header
    private let EEG_DATA_HEADER: UInt16 = 0x0480
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()
    private let targetDevices = ["QCC5181", "QCC5181-LE", "NEOCORE"]
    private let savedDeviceKey = "savedBluetoothDeviceID"
    
    // Mock timers
    private var dataGenerationTimer: Timer?
    private var scanTimer: Timer?
    
    // Mock devices
    private let mockDevices = [
        DiscoveredDevice(id: "device-1", name: "NeuroLink Pro", rssi: -45, peripheral: nil, isPriority: true),
        DiscoveredDevice(id: "device-2", name: "QCC5181", rssi: -55, peripheral: nil, isPriority: true),
        DiscoveredDevice(id: "device-3", name: "NEOCORE", rssi: -65, peripheral: nil, isPriority: true)
    ]
    
    // MARK: - Initialization
    override init() {
        super.init()
        // Don't create real CBCentralManager in mock
        setupMockState()
    }
    
    private func setupMockState() {
        permissionStatus = .authorized
        // Simulate having a connected device after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.simulateDeviceConnection()
        }
    }
    
    private func simulateDeviceConnection() {
        isConnected = true
        connectedDevice = BLEDevice(id: "mock-device-id", name: "NeuroLink Pro", peripheral: nil)
        batteryLevel = Int.random(in: 0...100)
        serialNumber = "NL-2024-8847"
    }
    
    // MARK: - Public Methods for Device Discovery and Connection
    
    func startScanning() {
        print("Mock: Starting scan")
        isScanning = true
        discoveredDevices = []
        scanDeviceIndex = 0
        
        // Cancel any existing timer first
        scanTimer?.invalidate()
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.scanDeviceIndex < self.mockDevices.count else {
                self?.stopScanning()
                return
            }
            
            DispatchQueue.main.async {
                self.discoveredDevices.append(self.mockDevices[self.scanDeviceIndex])
                print("Mock: Discovered device: \(self.mockDevices[self.scanDeviceIndex].name)")
                self.scanDeviceIndex += 1
            }
        }
        
        // Auto-stop scanning after 15 seconds - but only if still scanning
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.isScanning == true {
                self?.stopScanning()
            }
        }
    }
    
    
    func stopScanning() {
        guard isScanning else { return }
        
        print("Mock: Stopping scan")
        scanTimer?.invalidate()
        scanTimer = nil
        isScanning = false
    }
    
    func connect(to device: DiscoveredDevice) {
        print("Mock: Connecting to \(device.name)")
        stopScanning()
        
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 14) {
            self.isConnected = true
            self.connectedDevice = BLEDevice(id: device.id, name: device.name, peripheral: nil)
            self.batteryLevel = Int.random(in: 60...95)
            self.serialNumber = "NL-2024-\(Int.random(in: 1000...9999))"
            self.saveConnectedDevice()
            
            // Simulate reading device info
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.readSerialNumber()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.readBatteryLevel()
                }
            }
        }
    }
    
    func disconnect() {
        print("Mock: Disconnecting device")
        stopRecording()
        removeSavedDevice()
        
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
    
    func saveConnectedDevice() {
        guard let device = connectedDevice else { return }
        UserDefaults.standard.set(device.id, forKey: savedDeviceKey)
        print("Mock: Saved device ID: \(device.id)")
    }
    
    func removeSavedDevice() {
        UserDefaults.standard.removeObject(forKey: savedDeviceKey)
    }
    
    private func enableLeadOffDetection(_ enable: Bool) {
        print("Mock: Lead-off detection \(enable ? "enabled" : "disabled")")
        isLeadOffDetectionEnabled = enable
    }
    
    func autoConnect() {
        print("Mock: Auto connecting")
        
        guard let savedID = UserDefaults.standard.string(forKey: savedDeviceKey) else { return }
        
        startScanning()
                
        // Simulate finding the saved device
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            if let device = self.mockDevices.first(where: { $0.id == savedID }) {
                self.connect(to: device)
            }
        }
    }
    
    func checkPermissions() {
        permissionStatus = .authorized
    }
    
    // MARK: - Device Information Commands
    func readSerialNumber() {
        print("Mock: Reading serial number")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.handleSerialNumberResponse(data: Data("NL-2024-\(Int.random(in: 1000...9999))".utf8))
        }
    }
    
    func readBatteryLevel() {
        print("Mock: Reading battery level")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let mockData = Data([0x00, 0x00, UInt8.random(in: 60...95)])
            self.handleBatteryLevelResponse(data: mockData)
        }
    }
    
    // MARK: - Test Signal and Data Streaming
    
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
        
        print("Mock: Starting recording in \(useTestSignal ? "test signal" : "normal") mode with lead-off detection \(enableLeadOff ? "enabled" : "disabled")")
        
        // Simulate the sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.isInTestMode else { return }
            
            if useTestSignal {
                print("Mock: Enabling test signal")
                self.enableTestSignal(true)
            }
        }
        
        if enableLeadOff {
            let leadOffDelay = useTestSignal ? 1.0 : 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + leadOffDelay) { [weak self] in
                guard let self = self, self.isInTestMode else { return }
                
                print("Mock: Enabling lead-off detection")
                self.enableLeadOffDetection(true)
            }
        }
        
        let streamingDelay = useTestSignal ? (enableLeadOff ? 1.5 : 1.0) : (enableLeadOff ? 1.0 : 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + streamingDelay) { [weak self] in
            guard let self = self, self.isInTestMode else { return }
            
            print("Mock: Enabling streaming")
            self.enableDataStreaming(true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isInTestMode else { return }
                
                self.isReceivingTestData = true
                print("Mock: Recording fully activated")
                
                if enableLeadOff {
                    self.startLeadOffAnalysis()
                }
                
                // Start generating mock data
                self.startDataGeneration(useTestSignal: useTestSignal)
            }
        }
    }
    
    private func startLeadOffAnalysis() {
        leadOffAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  self.isLeadOffDetectionEnabled,
                  !self.eegChannel1.isEmpty,
                  !self.eegChannel2.isEmpty else {
                return
            }
            
            let result = SignalProcessing.processLeadoffDetection(
                ch1Data: self.eegChannel1,
                ch2Data: self.eegChannel2
            )
            
            DispatchQueue.main.async {
                self.ch1ConnectionStatus = (result.ch1Connected, result.ch1Quality)
                self.ch2ConnectionStatus = (result.ch2Connected, result.ch2Quality)
            }
        }
    }
    
    func stopRecording() {
        print("Mock: Stopping recording")
        isInTestMode = false
        isReceivingTestData = false
        
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = nil
        
        dataGenerationTimer?.invalidate()
        dataGenerationTimer = nil
        
        isTestSignalEnabled = false
        isStreamingEnabled = false
        
        enableDataStreaming(false)
        
        if isTestSignalEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.enableTestSignal(false)
            }
        }
        
        if isLeadOffDetectionEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.enableLeadOffDetection(false)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
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
    
    func startTestDrive() {
        startRecording(useTestSignal: true, enableLeadOff: false)
    }
    
    func stopTestDrive() {
        stopRecording()
    }
    
    private func parseResponse(data: Data) {
        guard data.count >= 1 else {
            print("Mock: Invalid data: too short")
            return
        }
        
        let packetType = data[0]
        
        if packetType == EEG_PACKET_TYPE {
            handleEEGDataPacket(data)
            return
        }
        
        if packetType != EEG_PACKET_TYPE {
            guard data.count >= 2 else { return }
            
            let headerByte1 = data[0]
            let headerByte2 = data[1]
            let commandId: UInt16 = (UInt16(headerByte1) << 8) | UInt16(headerByte2)
            
            let featureId = commandId >> 9
            let pduType = (commandId >> 7) & 0x03
            let pduId = commandId & 0x7F
            
            print("Mock: Received response: feature=\(featureId), type=\(pduType), id=\(pduId)")
            
            if pduType == PDU_TYPE_RESPONSE {
                if featureId == NEOCORE_CORE_FEATURE_ID && pduId == NEOCORE_CMD_ID_GET_SERIAL_NUM {
                    handleSerialNumberResponse(data: data)
                } else if featureId == NEOCORE_BATTERY_FEATURE_ID && pduId == NEOCORE_CMD_ID_GET_BATTERY_LEVEL {
                    handleBatteryLevelResponse(data: data)
                }
            } else if pduType == PDU_TYPE_NOTIFICATION {
                if featureId == NEOCORE_BATTERY_FEATURE_ID {
                    handleBatteryLevelResponse(data: data)
                }
            } else if pduType == PDU_TYPE_ERROR {
                print("Mock: Received error response")
            }
        }
    }
    
    private func handleEEGDataPacket(_ data: Data) {
        guard data.count >= 4 else {
            print("Mock: EEG packet too short")
            return
        }
        
        let packetType = data[0]
        let payloadLength = data[1]
        let messageIndex = UInt16(data[2]) | (UInt16(data[3]) << 8)
        
        print("Mock: EEG Packet: Type=\(packetType), Length=\(payloadLength), Index=\(messageIndex)")
        
        // Generate mock channel data instead of parsing real data
        // This will be handled by startDataGeneration instead
    }
    
    private func parseInt32(from data: Data, startIndex: Int) -> Int32 {
        guard startIndex + 3 < data.count else { return 0 }
        
        let byte0 = UInt32(data[startIndex])
        let byte1 = UInt32(data[startIndex + 1]) << 8
        let byte2 = UInt32(data[startIndex + 2]) << 16
        let byte3 = UInt32(data[startIndex + 3]) << 24
        
        return Int32(bitPattern: byte0 | byte1 | byte2 | byte3)
    }
    
    private func enableDataStreaming(_ enable: Bool) {
        print("Mock: Data streaming \(enable ? "enabled" : "disabled")")
        isStreamingEnabled = enable
        
        if !enable {
            testSignalData = []
        }
    }
    
    private func enableTestSignal(_ enable: Bool) {
        print("Mock: Test signal \(enable ? "enabled" : "disabled")")
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
        let ch1Samples = eegChannel1.suffix(10)
        let ch2Samples = eegChannel2.suffix(10)
        
        if ch1Samples.isEmpty && ch2Samples.isEmpty {
            return 0.0
        }
        
        let ch1Avg = ch1Samples.isEmpty ? 0 : Double(ch1Samples.reduce(0, +)) / Double(ch1Samples.count)
        let ch2Avg = ch2Samples.isEmpty ? 0 : Double(ch2Samples.reduce(0, +)) / Double(ch2Samples.count)
        
        let raw = (ch1Avg + ch2Avg)
        return raw
    }
    
    private func generateSimulatedValue(for word: String) -> Double {
        let raw = sin(simPhase)
        let value = raw * 50 + 50
        simPhase += simStep
        if simPhase > .pi * 2 { simPhase -= .pi * 2 }
        return value
    }
    
    // MARK: - Command and Response Handling
    
    private func sendCommand(featureId: UInt16, pduType: UInt16, pduId: UInt16, data: Data?) {
        let commandId: UInt16 = ((featureId << 9) | (pduType << 7)) | pduId
        print("Mock: Sending command: \(String(format: "0x%04X", commandId))")
        
        // Simulate response after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Generate mock response based on command
            if featureId == self.NEOCORE_CORE_FEATURE_ID && pduId == self.NEOCORE_CMD_ID_GET_SERIAL_NUM {
                self.handleSerialNumberResponse(data: Data("NL-2024-\(Int.random(in: 1000...9999))".utf8))
            } else if featureId == self.NEOCORE_BATTERY_FEATURE_ID && pduId == self.NEOCORE_CMD_ID_GET_BATTERY_LEVEL {
                let mockData = Data([0x00, 0x00, UInt8.random(in: 60...95)])
                self.handleBatteryLevelResponse(data: mockData)
            }
        }
    }
    
    private func handleSerialNumberResponse(data: Data) {
        if let serialString = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.serialNumber = serialString
                print("Mock: Received serial number: \(serialString)")
            }
        } else {
            let hexSerial = data.hexDescription
            DispatchQueue.main.async {
                self.serialNumber = hexSerial
                print("Mock: Received serial number (hex): \(hexSerial)")
            }
        }
    }
    
    private func handleBatteryLevelResponse(data: Data) {
        guard data.count >= 3 else {
            print("Mock: Invalid battery level response")
            return
        }
        
        let level = Int(data[2])
        
        DispatchQueue.main.async {
            self.batteryLevel = level
            print("Mock: Received battery level: \(level)%")
        }
    }
    
    // MARK: - Data Generation for Mock
    
    private func startDataGeneration(useTestSignal: Bool) {
        // Make sure we clean up any existing timer first
        dataGenerationTimer?.invalidate()
        dataGenerationTimer = nil
        
        // Use a longer interval to prevent UI freezing (reduced frequency)
        dataGenerationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isReceivingTestData else {
                // Clean up timer if not receiving data
                self?.dataGenerationTimer?.invalidate()
                self?.dataGenerationTimer = nil
                return
            }
            
            let sampleCount = 10
            var ch1Samples: [Int32] = []
            var ch2Samples: [Int32] = []
            
            for i in 0..<sampleCount {
                if useTestSignal {
                    // Use simulation phase instead of Date() for better performance
                    let phaseOffset = Double(i) * 0.1
                    let ch1Value = Int32(sin((self.simPhase + phaseOffset) * 2.0 * .pi) * 1000 + 2000)
                    let ch2Value = Int32(cos((self.simPhase + phaseOffset) * 1.5 * .pi) * 800 + 1800)
                    ch1Samples.append(ch1Value)
                    ch2Samples.append(ch2Value)
                } else {
                    let ch1Value = Int32.random(in: -500...500) + Int32(sin(self.simPhase) * 200)
                    let ch2Value = Int32.random(in: -400...400) + Int32(cos(self.simPhase) * 150)
                    ch1Samples.append(ch1Value)
                    ch2Samples.append(ch2Value)
                }
            }
            
            // Increment simulation phase after generating all samples
            self.simPhase += self.simStep
            if self.simPhase > 2.0 * .pi {
                self.simPhase -= 2.0 * .pi
            }
            
            // Update on main queue but don't block it
            DispatchQueue.main.async {
                self.eegChannel1.append(contentsOf: ch1Samples)
                self.eegChannel2.append(contentsOf: ch2Samples)
                
                let maxStoredSamples = 2000
                if self.eegChannel1.count > maxStoredSamples {
                    self.eegChannel1.removeFirst(self.eegChannel1.count - maxStoredSamples)
                }
                if self.eegChannel2.count > maxStoredSamples {
                    self.eegChannel2.removeFirst(self.eegChannel2.count - maxStoredSamples)
                }
            }
        }
    }
    
    // MARK: - Mock Test Methods for UI Testing
    
    func simulateDisconnection() {
        disconnect()
    }
    
    func simulateLowBattery() {
        batteryLevel = Int.random(in: 5...25)
    }
    
    func simulatePoorSignalQuality() {
        ch1ConnectionStatus = (true, Double.random(in: 0.2...0.5))
        ch2ConnectionStatus = (true, Double.random(in: 0.1...0.4))
    }
    
    func simulateGoodSignalQuality() {
        ch1ConnectionStatus = (true, Double.random(in: 0.85...0.98))
        ch2ConnectionStatus = (true, Double.random(in: 0.85...0.98))
    }
    
    func simulateLeadOffDetected() {
        ch1ConnectionStatus = (false, 0.0)
        ch2ConnectionStatus = (false, 0.0)
    }
}

// MARK: - Mock CBCentralManagerDelegate (not implemented since we don't use real Bluetooth)
extension MockBluetoothService {
    // These would be CBCentralManagerDelegate methods but we don't implement them
    // since we're not using real Bluetooth in the mock
}

// MARK: - Mock CBPeripheralDelegate (not implemented since we don't use real Bluetooth)
extension MockBluetoothService {
    // These would be CBPeripheralDelegate methods but we don't implement them
    // since we're not using real peripherals in the mock
}
