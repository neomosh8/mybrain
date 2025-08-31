import Foundation
import CoreBluetooth
import Combine

final class MockBluetoothService: NSObject, ObservableObject, BTServiceProtocol {
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
    @Published var eegChannel1: [Double] = []
    @Published var eegChannel2: [Double] = []
    
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
    
    // MARK: - Feedback Publisher
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
    
    // MARK: - Scanner Control Methods
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
        stopBatteryUpdates()
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
    
    // MARK: - Streaming Control Methods
    // MARK: - Streaming Control Methods
    func startRecording(useTestSignal: Bool, enableLeadOff: Bool = false) {
        guard isConnected else {
            print("Mock: Cannot start recording - not connected")
            return
        }
        print("Mock: Starting recording (stream only; mode must be set separately)")

        // Stream ON (do not change mode flags here)
        isStreamingEnabled = true

        // Clear previous data
        clearEEGData()

        // Start data generation (mode is read live each tick)
        startDataGeneration()

        // Lead-off analysis: driven by current mode
        if isLeadOffDetectionEnabled {
            startLeadOffAnalysis()
        } else {
            stopLeadOffAnalysis()
        }

        // Quality assumption if no lead-off
        startQualityAnalysis()
    }

    func stopRecording() {
        print("Mock: Stopping recording")
        isStreamingEnabled = false

        stopDataGeneration()
        stopLeadOffAnalysis()
        stopQualityAnalysis()
    }

    // MARK: - NEW: Mode-only APIs (no streaming side effects)
    func setModeNormal() {
        isTestSignalEnabled = false
        isLeadOffDetectionEnabled = false
        isInNormalMode = true
        isReceivingTestData = false
        print("Mock: Mode = NORMAL")
    }

    func setModeTestSignal() {
        isTestSignalEnabled = true
        isLeadOffDetectionEnabled = false
        isInNormalMode = false
        isReceivingTestData = true
        print("Mock: Mode = TEST SIGNAL")
    }

    func setModeLeadOff() {
        isTestSignalEnabled = false
        isLeadOffDetectionEnabled = true
        isInNormalMode = false
        isReceivingTestData = false
        print("Mock: Mode = LEAD-OFF")
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
    
    // MARK: - Battery Monitoring
    func startBatteryUpdates(interval: TimeInterval = 300.0) {
        guard isConnected else { return }
        
        print("Mock: Starting battery updates (interval: \(interval)s)")
        
        // Stop existing timer
        batteryTimer?.invalidate()
        
        // Start new timer with specified interval
        batteryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if self.isConnected {
                self.readBatteryLevel()
            }
        }
    }
    
    func stopBatteryUpdates() {
        print("Mock: Stopping battery updates")
        batteryTimer?.invalidate()
        batteryTimer = nil
    }
    
    // MARK: - Analysis Methods
    func analyzeSignalQuality() -> (ch1: SignalQualityMetrics?, ch2: SignalQualityMetrics?) {
        guard isConnected else { return (nil, nil) }
        
        let ch1Metrics = SignalQualityMetrics(
            dynamicRange: DynamicRange(
                linear: ch1ConnectionStatus.quality,
                db: 20 * log10(max(ch1ConnectionStatus.quality, 0.001)),
                peakToPeak: ch1ConnectionStatus.quality * 2000,
                rms: ch1ConnectionStatus.quality * 500,
                max: ch1ConnectionStatus.quality * 1000,
                min: -ch1ConnectionStatus.quality * 1000
            ),
            snr: SignalToNoiseRatio(
                totalSNRdB: ch1ConnectionStatus.quality * 30,
                bandSNR: [
                    "delta": ch1ConnectionStatus.quality * 25,
                    "theta": ch1ConnectionStatus.quality * 28,
                    "alpha": ch1ConnectionStatus.quality * 32,
                    "beta": ch1ConnectionStatus.quality * 30
                ],
                signalPower: ch1ConnectionStatus.quality * 1000,
                noisePower: (1.0 - ch1ConnectionStatus.quality) * 100
            )
        )
        
        let ch2Metrics = SignalQualityMetrics(
            dynamicRange: DynamicRange(
                linear: ch2ConnectionStatus.quality,
                db: 20 * log10(max(ch2ConnectionStatus.quality, 0.001)),
                peakToPeak: ch2ConnectionStatus.quality * 2000,
                rms: ch2ConnectionStatus.quality * 500,
                max: ch2ConnectionStatus.quality * 1000,
                min: -ch2ConnectionStatus.quality * 1000
            ),
            snr: SignalToNoiseRatio(
                totalSNRdB: ch2ConnectionStatus.quality * 30,
                bandSNR: [
                    "delta": ch2ConnectionStatus.quality * 25,
                    "theta": ch2ConnectionStatus.quality * 28,
                    "alpha": ch2ConnectionStatus.quality * 32,
                    "beta": ch2ConnectionStatus.quality * 30
                ],
                signalPower: ch2ConnectionStatus.quality * 1000,
                noisePower: (1.0 - ch2ConnectionStatus.quality) * 100
            )
        )
        
        return (ch1Metrics, ch2Metrics)
    }
    
    // MARK: - Feedback Processing
    func processFeedback(word: String) -> Double {
        let value: Double
        if isConnected {
            value = generateSimulatedValue(for: word)
            
            feedbackSubject.send(value)
            return value
        }
        
        return 0.0
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
        
        // Start periodic battery updates with default interval
        startBatteryUpdates()
    }
    
    private func clearEEGData() {
        testSignalData.removeAll()
        eegChannel1.removeAll()
        eegChannel2.removeAll()
    }
    
    private func startDataGeneration() {
        dataTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            self.generateMockEEGData()
        }
    }
    
    private func generateMockEEGData() {
        guard isStreamingEnabled else { return }

        let useTestSignal = self.isTestSignalEnabled
        let useLeadOff = self.isLeadOffDetectionEnabled

        let samplesPerPacket = 10
        var ch1Samples: [Double] = []
        var ch2Samples: [Double] = []

        for _ in 0..<samplesPerPacket {
            if useLeadOff {
                // Lead-off mode: low-amplitude noisy baseline to mimic diagnostic stream
                let v1 = Double.random(in: -15...15)
                let v2 = Double.random(in: -15...15)
                ch1Samples.append(v1)
                ch2Samples.append(v2)
            } else if useTestSignal {
                // Test signal (square/sine)
                let testValue1 = Double(sin(simPhase) > 0 ? 1000 : -1000)
                let testValue2 = Double(sin(simPhase * 2) * 800)
                ch1Samples.append(testValue1)
                ch2Samples.append(testValue2)
                testSignalData.append(Int32(testValue1))
            } else {
                // Normal EEG-like noise
                let noise1 = Double.random(in: -50...50)
                let noise2 = Double.random(in: -50...50)
                let base1 = Double(sin(simPhase * 0.1) * 30)
                let base2 = Double(cos(simPhase * 0.15) * 25)
                ch1Samples.append(base1 + noise1)
                ch2Samples.append(base2 + noise2)
            }

            simPhase += simStep
            if simPhase > .pi * 4 { simPhase -= .pi * 4 }
        }

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

    
    private func stopDataGeneration() {
        dataTimer?.invalidate()
        dataTimer = nil
    }
    
    private func generateMockEEGData(useTestSignal: Bool) {
        let samplesPerPacket = 10
        var ch1Samples: [Double] = []
        var ch2Samples: [Double] = []
        
        for _ in 0..<samplesPerPacket {
            if useTestSignal {
                // Generate test signal (square wave for channel 1, sine for channel 2)
                let testValue1 = Double(sin(simPhase) > 0 ? 1000 : -1000)
                let testValue2 = Double(sin(simPhase * 2) * 800)
                
                ch1Samples.append(testValue1)
                ch2Samples.append(testValue2)
                testSignalData.append(Int32(testValue1))
            } else {
                // Generate realistic EEG-like noise
                let noise1 = Double.random(in: -50...50)
                let noise2 = Double.random(in: -50...50)
                let base1 = Double(sin(simPhase * 0.1) * 30)
                let base2 = Double(cos(simPhase * 0.15) * 25)
                
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
    
    private func stopAllTimers() {
        dataTimer?.invalidate()
        dataTimer = nil
        
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = nil
        
        batteryTimer?.invalidate()
        batteryTimer = nil
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
