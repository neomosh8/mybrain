import Foundation
import CoreBluetooth
import Combine

class MockBluetoothService: NSObject, ObservableObject {
    // MARK: - Static Properties
    static let shared = MockBluetoothService()
    
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isConnected = false
    @Published var connectedDevice: BLEDevice?
    @Published var permissionStatus: PermissionStatus = .unknown
    
    // Parser properties
    @Published var batteryLevel: Int?
    @Published var serialNumber: String?
    @Published var testSignalData: [Int32] = []
    @Published var eegChannel1: [Int32] = []
    @Published var eegChannel2: [Int32] = []
    
    // Streamer properties
    @Published var isTestSignalEnabled = false
    @Published var isStreamingEnabled = false
    @Published var isReceivingTestData = false
    @Published var isInNormalMode = false
    @Published var isLeadOffDetectionEnabled = false
    
    // Quality Analyzer properties
    @Published var ch1ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    @Published var ch2ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    
    // MARK: - Private Properties
    private let feedbackSubject = PassthroughSubject<Double, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // Simulation state
    private var simPhase: Double = 0.0
    private let simStep: Double = 0.15
    private var scanDeviceIndex = 0
    private var autoStartStreaming = false
    private var isInTestMode = false
    
    // Mock data generation
    private var dataTimer: Timer?
    private var leadOffAnalysisTimer: Timer?
    private var batteryTimer: Timer?
    
    // Neocore Protocol Constants
    private let NEOCORE_CORE_FEATURE_ID: UInt16 = 0x00
    private let NEOCORE_SENSOR_CFG_FEATURE_ID: UInt16 = 0x01
    private let NEOCORE_SENSOR_STREAM_FEATURE_ID: UInt16 = 0x02
    private let NEOCORE_BATTERY_FEATURE_ID: UInt16 = 0x03
    private let NEOCORE_CHARGER_STATUS_FEATURE_ID: UInt16 = 0x04
    
    private let PDU_TYPE_COMMAND: UInt16 = 0
    private let PDU_TYPE_NOTIFICATION: UInt16 = 1
    private let PDU_TYPE_RESPONSE: UInt16 = 2
    private let PDU_TYPE_ERROR: UInt16 = 3
    
    private let NEOCORE_CMD_ID_GET_SERIAL_NUM: UInt16 = 0x01
    private let NEOCORE_CMD_ID_GET_BATTERY_LEVEL: UInt16 = 0x00
    private let NEOCORE_CMD_ID_DATA_STREAM_CTRL: UInt16 = 0x00
    private let NEOCORE_CMD_ID_EEG_TEST_SIGNAL_CTRL: UInt16 = 0x01
    private let NEOCORE_CMD_ID_EEG_LEAD_OFF_CTRL: UInt16 = 0x02
    private let NEOCORE_NOTIFY_ID_EEG_DATA: UInt16 = 0x00
    
    private let EEG_PACKET_TYPE: UInt8 = 0x04
    
    // MARK: - Public Interface
    
    var feedbackPublisher: AnyPublisher<Double, Never> {
        feedbackSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupMockPermissions()
        setupMockDevices()
    }
    
    deinit {
        stopAllTimers()
    }
    
    // MARK: - Setup Methods
    private func setupMockPermissions() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.permissionStatus = .authorized
        }
    }
    
    private func setupMockDevices() {
        let mockDevices = [
            DiscoveredDevice(
                id: "device-1",
                name: "NeuroLink Pro",
                rssi: -45,
                peripheral: nil,
                isPriority: true
            ),
            DiscoveredDevice(
                id: "device-2",
                name: "QCC5181",
                rssi: -62,
                peripheral: nil,
                isPriority: true
            ),
            DiscoveredDevice(
                id: "device-3",
                name: "NEOCORE",
                rssi: -78,
                peripheral: nil,
                isPriority: true
            )
        ]
        
        DispatchQueue.main.async {
            self.discoveredDevices = mockDevices
        }
    }
    
    // MARK: - Scanner Methods
    func startScanning() {
        guard !isScanning else { return }
        
        print("Mock: Starting scan...")
        isScanning = true
        
        // Simulate finding devices gradually
        simulateDeviceDiscovery()
    }
    
    func stopScanning() {
        guard isScanning else { return }
        
        print("Mock: Stopping scan...")
        isScanning = false
    }
    
    func autoConnect() {
        guard !discoveredDevices.isEmpty else {
            print("Mock: No devices to auto-connect")
            return
        }
        
        let deviceToConnect = discoveredDevices.first!
        connect(to: deviceToConnect)
    }
    
    func connect(to device: DiscoveredDevice) {
        guard !isConnected else {
            print("Mock: Already connected")
            return
        }
        
        print("Mock: Connecting to \(device.name)...")
        
        // Stop scanning if active
        if isScanning {
            stopScanning()
        }
        
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.simulateSuccessfulConnection(device)
        }
    }
    
    func disconnect() {
        guard isConnected else { return }
        
        print("Mock: Disconnecting...")
        
        // Stop all streaming and timers
        stopRecording()
        stopAllTimers()
        
        // Reset connection state
        isConnected = false
        connectedDevice = nil
        
        // Reset EEG data
        clearEEGData()
        
        // Reset device info
        batteryLevel = nil
        serialNumber = nil
        
        // Reset quality status
        ch1ConnectionStatus = (false, 0.0)
        ch2ConnectionStatus = (false, 0.0)
        
        print("Mock: Disconnected")
    }
    
    func checkPermissions() {
        // Mock always has permissions
        permissionStatus = .authorized
    }
    
    // MARK: - Streamer Methods
    func startRecording(useTestSignal: Bool, enableLeadOff: Bool = false) {
        guard isConnected else {
            print("Mock: Cannot start recording - not connected")
            return
        }
        
        print("Mock: Starting recording (testSignal: \(useTestSignal), leadOff: \(enableLeadOff))")
        
        isInTestMode = useTestSignal
        isTestSignalEnabled = useTestSignal
        isStreamingEnabled = true
        isReceivingTestData = useTestSignal
        isInNormalMode = !useTestSignal
        isLeadOffDetectionEnabled = enableLeadOff
        
        // Clear previous data
        clearEEGData()
        
        // Start data generation
        startDataGeneration(useTestSignal: useTestSignal)
        
        // Start lead-off analysis if enabled
        if enableLeadOff {
            startLeadOffAnalysis()
        }
        
        // Start quality analysis
        startQualityAnalysis()
    }
    
    func stopRecording() {
        print("Mock: Stopping recording")
        
        isStreamingEnabled = false
        isTestSignalEnabled = false
        isReceivingTestData = false
        isInNormalMode = false
        isLeadOffDetectionEnabled = false
        
        stopDataGeneration()
        stopLeadOffAnalysis()
        stopQualityAnalysis()
    }
    
    func toggleTestSignal() {
        let newState = !isTestSignalEnabled
        print("Mock: Toggling test signal to \(newState)")
        
        if isStreamingEnabled {
            isTestSignalEnabled = newState
            isReceivingTestData = newState
            isInNormalMode = !newState
            isInTestMode = newState
            
            // Restart data generation with new mode
            stopDataGeneration()
            startDataGeneration(useTestSignal: newState)
        }
    }
    
    func enableLeadOffDetection(_ enable: Bool) {
        print("Mock: Lead-off detection \(enable ? "enabled" : "disabled")")
        isLeadOffDetectionEnabled = enable
        
        if enable {
            startLeadOffAnalysis()
        } else {
            stopLeadOffAnalysis()
        }
    }
    
    // MARK: - Device Info Methods
    func readSerialNumber() {
        guard isConnected else { return }
        
        // Simulate reading serial number
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.serialNumber = "NL-2024-\(Int.random(in: 1000...9999))"
            print("Mock: Serial number: \(self.serialNumber!)")
        }
    }
    
    func readBatteryLevel() {
        guard isConnected else { return }
        
        // Simulate reading battery level
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.batteryLevel = Int.random(in: 60...95)
            print("Mock: Battery level: \(self.batteryLevel!)%")
        }
    }
    
    // MARK: - Feedback Processing
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
    
    // MARK: - Private Methods
    
    private func simulateDeviceDiscovery() {
        // Gradually add devices during scanning
        let discoveryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            guard self.isScanning else {
                timer.invalidate()
                return
            }
            
            if self.scanDeviceIndex < self.discoveredDevices.count {
                let device = self.discoveredDevices[self.scanDeviceIndex]
                print("Mock: Discovered device: \(device.name)")
                self.scanDeviceIndex += 1
            }
            
            if self.scanDeviceIndex >= self.discoveredDevices.count {
                timer.invalidate()
            }
        }
        
        RunLoop.current.add(discoveryTimer, forMode: .common)
    }
    
    private func simulateSuccessfulConnection(_ device: DiscoveredDevice) {
        isConnected = true
        connectedDevice = BLEDevice(id: device.id, name: device.name, peripheral: nil)
        
        print("Mock: Connected to \(device.name)")
        
        // Simulate reading device info after connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.readSerialNumber()
            self.readBatteryLevel()
        }
        
        // Auto-start streaming if configured
        if autoStartStreaming {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startRecording(useTestSignal: true, enableLeadOff: true)
            }
        }
        
        // Start periodic battery updates
        startBatteryUpdates()
    }
    
    private func clearEEGData() {
        testSignalData.removeAll()
        eegChannel1.removeAll()
        eegChannel2.removeAll()
    }
    
    private func startDataGeneration(useTestSignal: Bool) {
        dataTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            self.generateMockEEGData(useTestSignal: useTestSignal)
        }
    }
    
    private func stopDataGeneration() {
        dataTimer?.invalidate()
        dataTimer = nil
    }
    
    private func generateMockEEGData(useTestSignal: Bool) {
        let samplesPerPacket = 10
        var ch1Samples: [Int32] = []
        var ch2Samples: [Int32] = []
        
        for _ in 0..<samplesPerPacket {
            if useTestSignal {
                // Generate test signal (square wave for channel 1, sine for channel 2)
                let testValue1 = Int32(sin(simPhase) > 0 ? 1000 : -1000)
                let testValue2 = Int32(sin(simPhase * 2) * 800)
                
                ch1Samples.append(testValue1)
                ch2Samples.append(testValue2)
                testSignalData.append(testValue1)
            } else {
                // Generate realistic EEG-like noise
                let noise1 = Int32.random(in: -50...50)
                let noise2 = Int32.random(in: -50...50)
                let base1 = Int32(sin(simPhase * 0.1) * 30)
                let base2 = Int32(cos(simPhase * 0.15) * 25)
                
                ch1Samples.append(base1 + noise1)
                ch2Samples.append(base2 + noise2)
            }
            
            simPhase += simStep
            if simPhase > .pi * 4 { simPhase -= .pi * 4 }
        }
        
        // Update published arrays on main queue
        DispatchQueue.main.async {
            self.eegChannel1.append(contentsOf: ch1Samples)
            self.eegChannel2.append(contentsOf: ch2Samples)
            
            // Keep arrays manageable
            let maxStoredSamples = 2000
            if self.eegChannel1.count > maxStoredSamples {
                self.eegChannel1.removeFirst(self.eegChannel1.count - maxStoredSamples)
            }
            if self.eegChannel2.count > maxStoredSamples {
                self.eegChannel2.removeFirst(self.eegChannel2.count - maxStoredSamples)
            }
        }
    }
    
    private func startLeadOffAnalysis() {
        leadOffAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.simulateLeadOffAnalysis()
        }
    }
    
    private func stopLeadOffAnalysis() {
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = nil
    }
    
    private func simulateLeadOffAnalysis() {
        // Simulate varying connection quality
        let ch1Connected = Double.random(in: 0...1) > 0.1 // 90% connected
        let ch2Connected = Double.random(in: 0...1) > 0.1 // 90% connected
        
        let ch1Quality = ch1Connected ? Double.random(in: 0.7...0.95) : 0.0
        let ch2Quality = ch2Connected ? Double.random(in: 0.7...0.95) : 0.0
        
        DispatchQueue.main.async {
            self.ch1ConnectionStatus = (ch1Connected, ch1Quality)
            self.ch2ConnectionStatus = (ch2Connected, ch2Quality)
        }
    }
    
    private func startQualityAnalysis() {
        // Quality analysis is handled by lead-off analysis
        if !isLeadOffDetectionEnabled {
            // If lead-off is disabled, assume good quality
            ch1ConnectionStatus = (true, 0.9)
            ch2ConnectionStatus = (true, 0.9)
        }
    }
    
    private func stopQualityAnalysis() {
        // Reset quality status
        ch1ConnectionStatus = (false, 0.0)
        ch2ConnectionStatus = (false, 0.0)
    }
    
    private func startBatteryUpdates() {
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            if self.isConnected {
                self.readBatteryLevel()
            }
        }
    }
    
    private func stopAllTimers() {
        dataTimer?.invalidate()
        dataTimer = nil
        
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = nil
        
        batteryTimer?.invalidate()
        batteryTimer = nil
    }
    
    private func calculateSignalValue() -> Double {
        let ch1Samples = eegChannel1.suffix(10)
        let ch2Samples = eegChannel2.suffix(10)
        
        if ch1Samples.isEmpty && ch2Samples.isEmpty {
            return 0.0
        }
        
        let ch1Avg = ch1Samples.isEmpty ? 0 : Double(ch1Samples.reduce(0, +)) / Double(ch1Samples.count)
        let ch2Avg = ch2Samples.isEmpty ? 0 : Double(ch2Samples.reduce(0, +)) / Double(ch2Samples.count)
        
        let raw = (ch1Avg + ch2Avg) / 2.0
        return raw
    }
    
    private func generateSimulatedValue(for word: String) -> Double {
        let raw = sin(simPhase)
        let value = raw * 50 + 50 // Scale to [0..100]
        simPhase += simStep
        if simPhase > .pi * 2 { simPhase -= .pi * 2 }
        return value
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
    
    func setAutoStartStreaming(_ enabled: Bool) {
        autoStartStreaming = enabled
    }
}
