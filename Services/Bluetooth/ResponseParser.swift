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
    @Published var eegChannel1D: [Double] = []
    @Published var eegChannel2D: [Double] = []
    @Published var chargerStatus: Bool?
    @Published var lastError: String?
    
    enum Mode { case normal, testSignal, leadOff }

    private(set) var isRecording: Bool = false
    private(set) var mode: Mode = .normal

    func setRecording(_ on: Bool) {
        isRecording = on
    }

    func setMode(_ newMode: Mode) {
        mode = newMode
    }
    
    private var onlineFilter = OnlineFilter()
    
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
        guard data.count >= BtConst.HEADER_BYTES else {
            print("Response too short: \(data.count) bytes")
            return
        }
        
        let payload = data.dropFirst(BtConst.HEADER_BYTES)
        guard let packetType = payload.first else { return }
        
        if packetType == BtConst.EEG_PACKET_TYPE {
            handleEEGDataPacket(Data(payload))
            return
        }
        
        // Parse header
        let header = UInt16(data[0]) << 8 | UInt16(data[1])
        let featureId = (header >> 9) & 0x7F
        let pduType = (header >> 7) & 0x03
        let pduId = header & 0x7F
        
        print("Parsed response - Feature: 0x\(String(featureId, radix: 16)), PDU Type: \(pduType), PDU ID: 0x\(String(pduId, radix: 16))")
        
        if pduType == BtConst.PDU_TYPE_ERROR {
            handleErrorResponse(featureId: featureId, pduId: pduId, raw: data)
            return
        }
        
        switch featureId {
        case BtConst.NEOCORE_CORE_FEATURE_ID:
            handleCoreResponse(pduType: pduType, pduId: pduId, data: data)
            
        case BtConst.NEOCORE_BATTERY_FEATURE_ID:
            handleBatteryResponse(pduType: pduType, pduId: pduId, data: data)
            
        case BtConst.NEOCORE_SENSOR_STREAM_FEATURE_ID:
            handleSensorStreamResponse(pduType: pduType, pduId: pduId, data: data)
            
        case BtConst.NEOCORE_CHARGER_STATUS_FEATURE_ID:
            handleChargerStatusResponse(pduType: pduType, pduId: pduId, data: data)
            
        default:
            print("Unknown feature ID: 0x\(String(featureId, radix: 16))")
        }
    }
    
    // MARK: - Response Handlers
    private func handleCoreResponse(pduType: UInt16, pduId: UInt16, data: Data) {
        switch pduId {
        case BtConst.NEOCORE_CMD_ID_GET_SERIAL_NUM:
            handleSerialNumberResponse(data)
        default:
            print("Unknown core command ID: 0x\(String(pduId, radix: 16))")
        }
    }
    
    private func handleBatteryResponse(pduType: UInt16, pduId: UInt16, data: Data) {
        switch pduId {
        case BtConst.NEOCORE_CMD_ID_GET_BATTERY_LEVEL:
            handleBatteryLevelResponse(data)
        default:
            print("Unknown battery command ID: 0x\(String(pduId, radix: 16))")
        }
    }
    
    private func handleSensorStreamResponse(pduType: UInt16, pduId: UInt16, data: Data) {
        switch pduId {
        case BtConst.NEOCORE_NOTIFY_ID_EEG_DATA:
            let payload = data.dropFirst(BtConst.HEADER_BYTES)
            handleEEGDataPacket(Data(payload))
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
        
        let payloadLength = Int(data[1])
        let expected = BtConst.SAMPLES_PER_CHUNK * BtConst.NUM_CHANNELS * 4
        guard payloadLength == expected else { return }
        
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
        
        onlineFilter.apply(to: &ch1Doubles, &ch2Doubles)
        
        if isRecording {
            DispatchQueue.main.async {
                self.eegChannel1D.append(contentsOf: ch1Doubles)
                self.eegChannel2D.append(contentsOf: ch2Doubles)
                
                let maxStored = 1500
                if self.eegChannel1D.count > maxStored {
                    self.eegChannel1D.removeFirst(self.eegChannel1D.count - maxStored)
                }
                if self.eegChannel2D.count > maxStored {
                    self.eegChannel2D.removeFirst(self.eegChannel2D.count - maxStored)
                }
            }
        }
        
        //        let filteredCh1 = ch1Doubles.map { Int32($0) }
        //        let filteredCh2 = ch2Doubles.map { Int32($0) }
        //        
        //        if isRecording {
        //            DispatchQueue.main.async {
        //                self.eegChannel1.append(contentsOf: filteredCh1)
        //                self.eegChannel2.append(contentsOf: filteredCh2)
        //                
        //                let maxStored = 1500
        //                if self.eegChannel1.count > maxStored {
        //                    self.eegChannel1.removeFirst(self.eegChannel1.count - maxStored)
        //                }
        //                if self.eegChannel2.count > maxStored {
        //                    self.eegChannel2.removeFirst(self.eegChannel2.count - maxStored)
        //                }
        //            }
        //        }
    }
    
    private func handleChargerStatusResponse(pduType: UInt16, pduId: UInt16, data: Data) {
        // Skip header bytes
        guard data.count > BtConst.HEADER_BYTES else { return }
        let statusByte = data[BtConst.HEADER_BYTES]    // first payload byte
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
        var ch1: [Int32] = []
        var ch2: [Int32] = []
        let pairBytes = 8
        for offset in stride(from: 0, to: data.count - pairBytes + 1, by: pairBytes) {
            let p = data.subdata(in: offset..<(offset + pairBytes))
            let w1 = p.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self) }
            let w2 = p.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
            ch1.append(Int32(littleEndian: Int32(bitPattern: w1)))
            ch2.append(Int32(littleEndian: Int32(bitPattern: w2)))
        }
        return (ch1, ch2)
    }

    
    // MARK: - Characteristic UUID Helpers
    func isTargetService(_ service: CBService) -> Bool {
        return service.uuid == BtConst.SERVICE_UUID
    }
    
    func isWriteCharacteristic(_ characteristic: CBCharacteristic) -> Bool {
        return characteristic.uuid == BtConst.WRITE_CHARACTERISTIC_UUID
    }
    
    func isNotifyCharacteristic(_ characteristic: CBCharacteristic) -> Bool {
        return characteristic.uuid == BtConst.NOTIFY_CHARACTERISTIC_UUID
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
