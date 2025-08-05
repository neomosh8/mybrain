import Foundation
import CoreBluetooth
import Combine

class BluetoothStreamer: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isTestSignalEnabled = false
    @Published var isStreamingEnabled = false
    @Published var isReceivingTestData = false
    @Published var isInNormalMode = false
    @Published var isLeadOffDetectionEnabled = false
    @Published var isInTestMode = false
    
    // MARK: - Private Properties
    private var autoStartStreaming = false
    
    // MARK: - Neocore Protocol Constants
    private let NEOCORE_SENSOR_CFG_FEATURE_ID: UInt16 = 0x01
    private let PDU_TYPE_COMMAND: UInt16 = 0
    private let NEOCORE_CMD_ID_DATA_STREAM_CTRL: UInt16 = 0x00
    private let NEOCORE_CMD_ID_EEG_TEST_SIGNAL_CTRL: UInt16 = 0x01
    private let NEOCORE_CMD_ID_EEG_LEAD_OFF_CTRL: UInt16 = 0x02
    
    // MARK: - Callbacks
    var onSendCommand: ((UInt16, UInt16, UInt16, Data?) -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Public Streaming Control Methods
    func startRecording(useTestSignal: Bool, enableLeadOff: Bool = false) {
        // Reset state
        isTestSignalEnabled = false
        isStreamingEnabled = false
        isReceivingTestData = false
        isLeadOffDetectionEnabled = false
        isInTestMode = true
        isInNormalMode = !useTestSignal
        
        print("Starting recording in \(useTestSignal ? "test signal" : "normal") mode with lead-off detection \(enableLeadOff ? "enabled" : "disabled")")
        
        // 1. Enable lead-off detection first if requested
        if enableLeadOff {
            enableLeadOffDetection(true)
            
            // Wait a bit before enabling test signal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if useTestSignal {
                    self.enableTestSignal(true)
                } else {
                    self.enableDataStreaming(true)
                }
            }
        } else {
            // Start directly with test signal or data streaming
            if useTestSignal {
                enableTestSignal(true)
            } else {
                enableDataStreaming(true)
            }
        }
    }
    
    func stopRecording() {
        print("Stopping EEG recording")
        
        // Stop all streaming
        enableTestSignal(false)
        enableDataStreaming(false)
        enableLeadOffDetection(false)
        
        // Reset state
        isTestSignalEnabled = false
        isStreamingEnabled = false
        isReceivingTestData = false
        isLeadOffDetectionEnabled = false
        isInTestMode = false
        isInNormalMode = false
    }
    
    func enableDataStreaming(_ enable: Bool) {
        // Construct the Data Stream Control command
        // Feature ID: 0x01 (Sensor Configuration)
        // PDU Type: 0x00 (Command)
        // PDU Specific ID: 0x00 (Data Stream Control)
        
        let payload = Data([enable ? 0x01 : 0x00])
        onSendCommand?(
            NEOCORE_SENSOR_CFG_FEATURE_ID,
            PDU_TYPE_COMMAND,
            NEOCORE_CMD_ID_DATA_STREAM_CTRL,
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
            NEOCORE_SENSOR_CFG_FEATURE_ID,
            PDU_TYPE_COMMAND,
            NEOCORE_CMD_ID_EEG_TEST_SIGNAL_CTRL,
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
            NEOCORE_SENSOR_CFG_FEATURE_ID,
            PDU_TYPE_COMMAND,
            NEOCORE_CMD_ID_EEG_LEAD_OFF_CTRL,
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
