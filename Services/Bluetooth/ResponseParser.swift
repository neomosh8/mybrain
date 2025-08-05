import Foundation
import CoreBluetooth
import Combine

class ResponseParser: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var batteryLevel: Int?
    @Published var serialNumber: String?
    @Published var testSignalData: [Int32] = []
    @Published var eegChannel1: [Int32] = []
    @Published var eegChannel2: [Int32] = []
    @Published var chargerStatus: Bool?
    @Published var lastError: String?
    
    // MARK: - Private Properties
    private let EEG_PACKET_TYPE: UInt8 = 0x02 // Updated from 0x04 to match Python
    private let HEADER_BYTES: Int = 2       // Feature + PDU header trimmed by Python client
    private let SAMPLE_RATE = 250
    private let SAMPLES_PER_CHUNK = 27
    private let NUM_CHANNELS = 2
    private let EEG_DATA_HEADER: UInt16 = 0x0480
    
    private var onlineFilter = OnlineFilter()
    
    // Neocore Protocol Constants
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
    
    // MARK: - Callbacks
    var onEEGDataReceived: (([Int32], [Int32]) -> Void)?
    var isReceivingTestData: Bool = false
    var isInTestMode: Bool = false
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Main Parsing Methods
    func parseResponse(from data: Data) {
        guard data.count >= HEADER_BYTES else {
            print("Response too short: \(data.count) bytes")
            return
        }
        
        let payload = data.dropFirst(HEADER_BYTES)
        guard let packetType = payload.first else { return }
        
        if packetType == EEG_PACKET_TYPE {
            handleEEGDataPacket(Data(payload))
            return
        }
        
        // Parse header
        let header = UInt16(data[0]) << 8 | UInt16(data[1])
        let featureId = (header >> 9) & 0x7F
        let pduType = (header >> 7) & 0x03
        let pduId = header & 0x7F
        
        print("Parsed response - Feature: 0x\(String(featureId, radix: 16)), PDU Type: \(pduType), PDU ID: 0x\(String(pduId, radix: 16))")
        
        if pduType == PDU_TYPE_ERROR {
            handleErrorResponse(featureId: featureId, pduId: pduId, raw: data)
            return
        }
        
        switch featureId {
        case NEOCORE_CORE_FEATURE_ID:
            handleCoreResponse(pduType: pduType, pduId: pduId, data: data)
            
        case NEOCORE_BATTERY_FEATURE_ID:
            handleBatteryResponse(pduType: pduType, pduId: pduId, data: data)
            
        case NEOCORE_SENSOR_STREAM_FEATURE_ID:
            handleSensorStreamResponse(pduType: pduType, pduId: pduId, data: data)
            
        case NEOCORE_CHARGER_STATUS_FEATURE_ID:
            handleChargerStatusResponse(pduType: pduType, pduId: pduId, data: data)
            
        default:
            print("Unknown feature ID: 0x\(String(featureId, radix: 16))")
        }
    }
    
    // MARK: - Response Handlers
    private func handleCoreResponse(pduType: UInt16, pduId: UInt16, data: Data) {
        switch pduId {
        case NEOCORE_CMD_ID_GET_SERIAL_NUM:
            handleSerialNumberResponse(data)
        default:
            print("Unknown core command ID: 0x\(String(pduId, radix: 16))")
        }
    }
    
    private func handleBatteryResponse(pduType: UInt16, pduId: UInt16, data: Data) {
        switch pduId {
        case NEOCORE_CMD_ID_GET_BATTERY_LEVEL:
            handleBatteryLevelResponse(data)
        default:
            print("Unknown battery command ID: 0x\(String(pduId, radix: 16))")
        }
    }
    
    private func handleSensorStreamResponse(pduType: UInt16, pduId: UInt16, data: Data) {
        switch pduId {
        case NEOCORE_NOTIFY_ID_EEG_DATA:
            handleEEGDataPacket(data)
        default:
            print("Unknown sensor stream ID: 0x\(String(pduId, radix: 16))")
        }
    }
    
    private func handleSerialNumberResponse(_ data: Data) {
        guard data.count > 2 else { return }
        
        let serialData = data.dropFirst(2) // Skip header
        if let serialString = String(data: serialData, encoding: .utf8) {
            DispatchQueue.main.async {
                self.serialNumber = serialString
            }
            print("Device serial number: \(serialString)")
        }
    }
    
    private func handleBatteryLevelResponse(_ data: Data) {
        guard data.count > 2 else { return }
        
        let batteryData = data.dropFirst(2) // Skip header
        if batteryData.count >= 1 {
            let level = Int(batteryData[0])
            DispatchQueue.main.async {
                self.batteryLevel = level
            }
            print("Battery level: \(level)%")
        }
    }
    
    func handleEEGDataPacket(_ data: Data) {
        // Skip first 2 bytes (header)
        let eegData = data.dropFirst(HEADER_BYTES)
        
        // Parse EEG samples
        let (ch1Samples, ch2Samples) = parseEEGSamples(from: Data(eegData))
        
        // Apply filtering before storing
        var ch1Doubles = ch1Samples.map { Double($0) }
        var ch2Doubles = ch2Samples.map { Double($0) }
        
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
        
        // Notify callback if available
        onEEGDataReceived?(filteredCh1, filteredCh2)
    }
    
    private func handleChargerStatusResponse(pduType: UInt16, pduId: UInt16, data: Data) {
        // Skip header bytes
        guard data.count > HEADER_BYTES else { return }
        let statusByte = data[HEADER_BYTES]    // first payload byte
        let isCharging = (statusByte != 0)
        DispatchQueue.main.async {
            self.chargerStatus = isCharging
        }
        print("⚡ Charger status: \(isCharging ? "charging" : "not charging")")
    }
    
    private func handleErrorResponse(featureId: UInt16, pduId: UInt16, raw data: Data) {
        print("🔴 Error response – feature=0x\(String(featureId, radix:16)), id=0x\(String(pduId, radix:16)): \(data.hexDescription)")
        self.lastError = "feature=0x\(String(featureId, radix:16)), id=0x\(String(pduId, radix:16)): \(data.hexDescription)"
    }
    
    private func parseEEGSamples(from data: Data) -> ([Int32], [Int32]) {
        var ch1Samples: [Int32] = []
        var ch2Samples: [Int32] = []
        
        // Each sample is 3 bytes (24-bit) per channel, and we have 2 channels
        let bytesPerSample = 3
        let totalBytesPerSamplePair = bytesPerSample * NUM_CHANNELS
        
        var offset = 0
        while offset + totalBytesPerSamplePair <= data.count {
            // Parse Channel 1 (first 3 bytes)
            let ch1Bytes = data.subdata(in: offset..<offset + bytesPerSample)
            let ch1Value = parseSignedInt24(from: ch1Bytes)
            ch1Samples.append(ch1Value)
            
            // Parse Channel 2 (next 3 bytes)
            let ch2Bytes = data.subdata(in: (offset + bytesPerSample)..<(offset + totalBytesPerSamplePair))
            let ch2Value = parseSignedInt24(from: ch2Bytes)
            ch2Samples.append(ch2Value)
            
            offset += totalBytesPerSamplePair
        }
        
        return (ch1Samples, ch2Samples)
    }
    
    private func parseSignedInt24(from data: Data) -> Int32 {
        guard data.count == 3 else { return 0 }
        
        // Convert 3 bytes to Int32 (little endian, sign-extended)
        let value = Int32(data[0]) | (Int32(data[1]) << 8) | (Int32(data[2]) << 16)
        
        // Sign extend from 24-bit to 32-bit
        if value & 0x800000 != 0 {
            return value | Int32(bitPattern: 0xFF000000)
        } else {
            return value
        }
    }
    
    // MARK: - Characteristic UUID Helpers
    func isTargetService(_ service: CBService) -> Bool {
        return service.uuid == serviceUUID
    }
    
    func isWriteCharacteristic(_ characteristic: CBCharacteristic) -> Bool {
        return characteristic.uuid == writeCharacteristicUUID
    }
    
    func isNotifyCharacteristic(_ characteristic: CBCharacteristic) -> Bool {
        return characteristic.uuid == notifyCharacteristicUUID
    }
    
    // MARK: - State Management
    func resetOnlineFilter() {
        onlineFilter = OnlineFilter()
    }
    
    func clearEEGData() {
        DispatchQueue.main.async {
            self.eegChannel1 = []
            self.eegChannel2 = []
            self.testSignalData = []
        }
    }
    
    func updateReceivingState(isReceiving: Bool, inTestMode: Bool) {
        isReceivingTestData = isReceiving
        isInTestMode = inTestMode
    }
}

extension Data {
    var hexDescription: String {
        return self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
