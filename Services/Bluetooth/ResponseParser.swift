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
        if let str = String(data: serialData, encoding: .utf8) {
            DispatchQueue.main.async {
                self.serialNumber = str
                print("Device serial number: \(str)")
            }
        } else {
            let hex = serialData.hexDescription
            DispatchQueue.main.async {
                self.serialNumber = hex
                print("Device serial number (hex): \(hex)")
            }
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
    
    // MARK: – EEG Packet Handler (Version 2 style)
    private func handleEEGDataPacket(_ data: Data) {
        // [0] Packet Type, [1] Payload length, [2…3] Message index, [4…] Interleaved samples
        guard data.count >= 4 else {
            print("EEG packet too short: \(data.count) bytes")
            return
        }
        
        let packetType = data[0]
        let payloadLength = Int(data[1])
        let messageIndex = UInt16(data[2]) | (UInt16(data[3]) << 8)
        
        print("EEG Packet: Type=0x\(String(format: "%02X", packetType)), Length=\(payloadLength), Index=\(messageIndex)")
        
        // sanity-check length (max 27 samples × 2 channels × 4 bytes = 216)
        guard payloadLength > 0 && payloadLength <= 216 else {
            print("Invalid payload length: \(payloadLength)")
            return
        }
        
        let expectedSize = 4 + payloadLength
        guard data.count >= expectedSize else {
            print("Packet size mismatch: expected \(expectedSize), got \(data.count)")
            return
        }
        
        // extract just the raw samples
        let samplesData = data.subdata(in: 4..<4 + payloadLength)
        
        // parse into Int32 arrays, then to Double for filtering
        let (rawCh1, rawCh2) = parseEEGSamples(from: samplesData)
        var ch1Doubles = rawCh1.map { Double($0) }
        var ch2Doubles = rawCh2.map { Double($0) }
        
        // apply your online filter
        onlineFilter.apply(to: &ch1Doubles, &ch2Doubles)
        
        // convert filtered back to Int32
        let filteredCh1 = ch1Doubles.map { Int32($0) }
        let filteredCh2 = ch2Doubles.map { Int32($0) }
        
        // append & bound buffer
        if isReceivingTestData && isInTestMode {
            DispatchQueue.main.async {
                self.eegChannel1.append(contentsOf: filteredCh1)
                self.eegChannel2.append(contentsOf: filteredCh2)
                
                let maxStoredSamples = 5000 // 20 s @250 Hz
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
    
    // MARK: – Sample Parsing (4-byte Int32 per channel)
    private func parseEEGSamples(from data: Data) -> ([Int32], [Int32]) {
        var ch1Samples: [Int32] = []
        var ch2Samples: [Int32] = []
        
        // Each sample-pair is 8 bytes: 4 bytes for channel 1 + 4 bytes for channel 2
        let bytesPerPair = MemoryLayout<Int32>.size * 2
        
        for offset in stride(from: 0, to: data.count - bytesPerPair + 1, by: bytesPerPair) {
            let pair = data.subdata(in: offset..<(offset + bytesPerPair))
            let ch1Val = pair.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: Int32.self) }
            let ch2Val = pair.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: Int32.self) }
            ch1Samples.append(ch1Val)
            ch2Samples.append(ch2Val)
        }
        
        return (ch1Samples, ch2Samples)
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
