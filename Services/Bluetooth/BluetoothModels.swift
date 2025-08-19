import Foundation
import CoreBluetooth

// MARK: - Permission Status
enum PermissionStatus {
    case unknown, notDetermined, denied, authorized, poweredOff, unsupported
}

// MARK: - Discovered Device
struct DiscoveredDevice: Identifiable {
    let id: String
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral?
    let isPriority: Bool
}

// MARK: - BLE Device
struct BLEDevice {
    let id: String
    let name: String
    let peripheral: CBPeripheral?
}


// MARK: - Quality Analysis Data Structures
struct SignalQualityMetrics {
    let dynamicRange: DynamicRange
    let snr: SignalToNoiseRatio
}

struct DynamicRange {
    let linear: Double
    let db: Double
    let peakToPeak: Double
    let rms: Double
    let max: Double
    let min: Double
}

struct SignalToNoiseRatio {
    let totalSNRdB: Double
    let bandSNR: [String: Double]
    let signalPower: Double
    let noisePower: Double
}
