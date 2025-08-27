import Foundation
import CoreBluetooth
import Combine

enum DeviceMode {
    case normal
    case testSignal
    case leadOff
}

class BluetoothStreamer: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isTestSignalEnabled = false
    @Published var isStreamingEnabled = false
    @Published var isReceivingTestData = false
    @Published var isInNormalMode = false
    @Published var isLeadOffDetectionEnabled = false
    @Published var isInTestMode = false
    
    @Published var currentMode: DeviceMode = .normal
    
    // MARK: - Private Properties
    private var autoStartStreaming = false
    
    // MARK: - Callbacks
    var onSendCommand: ((UInt16, UInt16, UInt16, Data?) -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // NEW: pure mode setters (no streaming toggles)
    func setModeNormal() {
        // Disable test signal & lead-off; leave stream state untouched
        enableTestSignal(false)
        enableLeadOffDetection(false)
        currentMode = .normal
        isInTestMode = false
        isInNormalMode = true
        print("Mode set to NORMAL (no streaming side effects)")
    }

    func setModeTestSignal() {
        // Enable test signal; leave stream state untouched
        enableLeadOffDetection(false)
        enableTestSignal(true)
        currentMode = .testSignal
        isInTestMode = true
        isInNormalMode = false
        print("Mode set to TEST SIGNAL (no streaming side effects)")
    }

    func setModeLeadOff() {
        // Enable lead-off detection; test signal off; leave stream state untouched
        enableTestSignal(false)
        enableLeadOffDetection(true)
        currentMode = .leadOff
        isInTestMode = false
        isInNormalMode = false
        print("Mode set to LEAD-OFF (no streaming side effects)")
    }

    
    // MARK: - Public Streaming Control Methods
    func startRecording() {
        print("Starting EEG streaming (mode was set separately)")
        enableDataStreaming(true) // ONLY stream on/off here
        isStreamingEnabled = true
    }

    func stopRecording() {
        print("Stopping EEG streaming")
        enableDataStreaming(false) // ONLY stream on/off
        isStreamingEnabled = false
    }
    
    func enableDataStreaming(_ enable: Bool) {
        // Construct the Data Stream Control command
        // Feature ID: 0x01 (Sensor Configuration)
        // PDU Type: 0x00 (Command)
        // PDU Specific ID: 0x00 (Data Stream Control)
        
        let payload = Data([enable ? 0x01 : 0x00])
        onSendCommand?(
            BtConst.NEOCORE_SENSOR_CFG_FEATURE_ID,
            BtConst.PDU_TYPE_COMMAND,
            BtConst.NEOCORE_CMD_ID_DATA_STREAM_CTRL,
            payload
        )
        
        print("Data streaming \(enable ? "enabled" : "disabled")")
        isStreamingEnabled = enable
    }
    
    func enableTestSignal(_ enable: Bool) {
        // Construct the Test Signal Control command
        // Feature ID: 0x01 (Sensor Configuration)
        // PDU Type: 0x00 (Command)
        // PDU Specific ID: 0x01 (Test Signal Control)
        let payload = Data([enable ? 0x01 : 0x00])
        
        onSendCommand?(
            BtConst.NEOCORE_SENSOR_CFG_FEATURE_ID,
            BtConst.PDU_TYPE_COMMAND,
            BtConst.NEOCORE_CMD_ID_EEG_TEST_SIGNAL_CTRL,
            payload
        )
        
        print("Test signal \(enable ? "enabled" : "disabled")")
        isTestSignalEnabled = enable
        isReceivingTestData = enable
    }
    
    private func enableLeadOffDetection(_ enable: Bool) {
        // Construct the Lead-Off Detection Control command
        // Feature ID: 0x01 (Sensor Configuration)
        // PDU Type: 0x00 (Command)
        // PDU Specific ID: 0x02 (Lead-Off Detection Control)
        let payload = Data([enable ? 0x01 : 0x00])
        
        onSendCommand?(
            BtConst.NEOCORE_SENSOR_CFG_FEATURE_ID,
            BtConst.PDU_TYPE_COMMAND,
            BtConst.NEOCORE_CMD_ID_EEG_LEAD_OFF_CTRL,
            payload
        )
        
        print("Lead-off detection \(enable ? "enabled" : "disabled")")
        isLeadOffDetectionEnabled = enable
    }
    
    // MARK: - Helper Methods
    func setAutoStartStreaming(_ enable: Bool) {
        autoStartStreaming = enable
    }
    
    func shouldAutoStartStreaming() -> Bool {
        return autoStartStreaming
    }
    
    // MARK: - State Management
    func resetState() {
        isTestSignalEnabled = false
        isStreamingEnabled = false
        isReceivingTestData = false
        isInNormalMode = false
        isLeadOffDetectionEnabled = false
        isInTestMode = false
        autoStartStreaming = false
    }
}
