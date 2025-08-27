import Foundation
import Combine
import CoreBluetooth

#if DEBUG
/// In Debug (simulator/development) use the mock
typealias BTService = MockBluetoothService
#else
/// In Release (or on-device) use the real one
typealias BTService = BluetoothService
#endif

/// Facade interface for Bluetooth EEG service
protocol BTServiceProtocol: ObservableObject {
    // MARK: - Singleton & Feedback
    
    /// Shared instance
    static var shared: Self { get }
    /// Stream of feedback values
    var feedbackPublisher: AnyPublisher<Double, Never> { get }
    
    // MARK: - Scanner State
    
    /// Whether a scan is in progress
    var isScanning: Bool { get }
    /// Discovered peripherals
    var discoveredDevices: [DiscoveredDevice] { get }
    /// Connection status
    var isConnected: Bool { get }
    /// Currently connected device (if any)
    var connectedDevice: BLEDevice? { get }
    /// Bluetooth permission state
    var permissionStatus: PermissionStatus { get }
    
    // MARK: - Parser State
    
    /// Last read battery level
    var batteryLevel: Int? { get }
    /// Device serial number
    var serialNumber: String? { get }
    /// Raw test‐signal samples
    var testSignalData: [Int32] { get }
    /// EEG channel 1 samples
    var eegChannel1: [Int32] { get }
    /// EEG channel 2 samples
    var eegChannel2: [Int32] { get }
    
    // MARK: - Streamer State
    
    /// Test-signal mode enabled
    var isTestSignalEnabled: Bool { get }
    /// Live-stream mode enabled
    var isStreamingEnabled: Bool { get }
    /// Receiving data indicator
    var isReceivingTestData: Bool { get }
    /// Normal (non-test) mode flag
    var isInNormalMode: Bool { get }
    /// Lead-off detection enabled
    var isLeadOffDetectionEnabled: Bool { get }
    
    // MARK: - Quality Analyzer State
    
    /// Channel 1 connection & quality
    var ch1ConnectionStatus: (connected: Bool, quality: Double) { get }
    /// Channel 2 connection & quality
    var ch2ConnectionStatus: (connected: Bool, quality: Double) { get }
    
    // MARK: - Scanner Control
    
    func startScanning()
    func stopScanning()
    func autoConnect()
    func connect(to device: DiscoveredDevice)
    func disconnect()
    func checkPermissions()
    
    
    // MARK: - Streaming Control
    
    func setModeNormal()
    func setModeTestSignal()
    func setModeLeadOff()
    
    func startRecording(useTestSignal: Bool, enableLeadOff: Bool)
    func stopRecording()
    
    
    // MARK: - Device Info
    
    func readSerialNumber()
    func readBatteryLevel()
    
    func startBatteryUpdates(interval: TimeInterval)
    func stopBatteryUpdates()
    
    
    // MARK: - Analysis
    
    /// One-off signal-quality metrics
    func analyzeSignalQuality() -> (ch1: SignalQualityMetrics?, ch2: SignalQualityMetrics?)
    
    // MARK: - Feedback
    
    /// Process a feedback “word” into a numeric value
    func processFeedback(word: String) -> Double
}
