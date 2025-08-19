import Foundation
import CoreBluetooth

struct BtConst {
    // MARK: - Service and Characteristic UUIDs
    static let SERVICE_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let WRITE_CHARACTERISTIC_UUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let NOTIFY_CHARACTERISTIC_UUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    // MARK: - Feature IDs
    static let NEOCORE_CORE_FEATURE_ID: UInt16 = 0x00
    static let NEOCORE_SENSOR_CFG_FEATURE_ID: UInt16 = 0x01
    static let NEOCORE_SENSOR_STREAM_FEATURE_ID: UInt16 = 0x02
    static let NEOCORE_BATTERY_FEATURE_ID: UInt16 = 0x03
    static let NEOCORE_CHARGER_STATUS_FEATURE_ID: UInt16 = 0x04
    
    // MARK: - PDU Types
    static let PDU_TYPE_COMMAND: UInt16 = 0
    static let PDU_TYPE_NOTIFICATION: UInt16 = 1
    static let PDU_TYPE_RESPONSE: UInt16 = 2
    static let PDU_TYPE_ERROR: UInt16 = 3
    
    // MARK: - Command IDs
    static let NEOCORE_CMD_ID_GET_SERIAL_NUM: UInt16 = 0x01
    static let NEOCORE_CMD_ID_GET_BATTERY_LEVEL: UInt16 = 0x00
    static let NEOCORE_CMD_ID_DATA_STREAM_CTRL: UInt16 = 0x00
    static let NEOCORE_CMD_ID_EEG_TEST_SIGNAL_CTRL: UInt16 = 0x01
    static let NEOCORE_CMD_ID_EEG_LEAD_OFF_CTRL: UInt16 = 0x02
    static let NEOCORE_NOTIFY_ID_EEG_DATA: UInt16 = 0x00
    
    // MARK: - Parser
    static let EEG_PACKET_TYPE: UInt8 = 0x02 // Updated from 0x04 to match Python
    static let HEADER_BYTES: Int = 2       // Feature + PDU header trimmed by Python client
    static let SAMPLES_PER_CHUNK = 27
    static let NUM_CHANNELS = 2
    static let EEG_DATA_HEADER: UInt16 = 0x0480
    
    // MARK: - Other
    static let TARGET_DEVICES = ["QCC5181", "QCC5181-LE", "NEOCORE"]
    
    // MARK: - Signal Processing
    static let SAMPLE_RATE: Int = 250
    static let WINDOW_SIZE: Int = 250
    static let OVERLAP_FRACTION: Double = 0.75
    static let POWER_SCALE: Double = 0.84
    static let TARGET_BIN: Int = 8
    static let NOISE_BAND = (45.0, 100.0)
    static let SIGNAL_BANDS: [String: (low: Double, high: Double)] = [
        "delta": (1, 4),
        "theta": (4, 8),
        "alpha": (8, 12),
        "beta": (13, 30),
        "gamma": (30, 45)
    ]
}
