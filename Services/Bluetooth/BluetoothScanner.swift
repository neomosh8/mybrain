import Foundation
import CoreBluetooth
import Combine

class BluetoothScanner: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isConnected = false
    @Published var connectedDevice: BLEDevice?
    @Published var permissionStatus: PermissionStatus = .unknown
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var cancellables = Set<AnyCancellable>()
    private let savedDeviceKey = "savedBluetoothDeviceID"
    
    // MARK: - Callbacks
    var onDeviceConnected: ((CBPeripheral) -> Void)?
    var onDeviceDisconnected: ((CBPeripheral, Error?) -> Void)?
    var onConnectionFailure: ((CBPeripheral, Error?) -> Void)?
    var onServicesDiscovered: ((CBPeripheral, Error?) -> Void)?
    var onCharacteristicsDiscovered: ((CBPeripheral, CBService, Error?) -> Void)?
    var onCharacteristicValueUpdated: ((CBPeripheral, CBCharacteristic, Data?) -> Void)?
    var onNotificationStateChanged: ((CBPeripheral, CBCharacteristic, Error?) -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods for Device Discovery and Connection
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        discoveredDevices = []
        
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Auto-stop scanning after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func autoConnect() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not ready for reconnection")
            return
        }
        
        guard let savedID = UserDefaults.standard.string(forKey: savedDeviceKey) else { return }
        
        startScanning()
        
        $discoveredDevices
            .compactMap { devices in devices.first { $0.id == savedID } }
            .first()
            .sink { [weak self] device in
                self?.stopScanning()
                self?.connect(to: device)
            }
            .store(in: &cancellables)
    }
    
    func connect(to device: DiscoveredDevice) {
        guard let peripheral = device.peripheral else { return }
        self.peripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        removeSavedDevice()
    }
    
    func saveConnectedDevice() {
        guard let device = connectedDevice else { return }
        UserDefaults.standard.set(device.id, forKey: savedDeviceKey)
    }
    
    func removeSavedDevice() {
        UserDefaults.standard.removeObject(forKey: savedDeviceKey)
    }
    
    func checkPermissions() {
        switch centralManager.state {
        case .poweredOn:
            permissionStatus = .authorized
        case .unauthorized:
            permissionStatus = .denied
        case .poweredOff:
            permissionStatus = .poweredOff
        case .resetting:
            permissionStatus = .unknown
        case .unsupported:
            permissionStatus = .unsupported
        case .unknown:
            permissionStatus = .notDetermined
        @unknown default:
            permissionStatus = .unknown
        }
    }
    
    // MARK: - Helper Methods
    func writeToCharacteristic(data: Data, characteristic: CBCharacteristic) {
        guard let peripheral = characteristic.service?.peripheral else { return }

        let supportsWithResponse = characteristic.properties.contains(.write)
        let writeType: CBCharacteristicWriteType = supportsWithResponse ? .withResponse : .withoutResponse

        peripheral.writeValue(data, for: characteristic, type: writeType)
    }
    
    func enableNotifications(for characteristic: CBCharacteristic) {
        guard let peripheral = peripheral else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }
    
    func setNotifications(enabled: Bool, for characteristic: CBCharacteristic?) {
        guard let peripheral = peripheral,
              let notifyCharacteristic = characteristic else { return }
        peripheral.setNotifyValue(enabled, for: notifyCharacteristic)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        checkPermissions()
        
        switch central.state {
        case .poweredOn:
            print("Bluetooth powered on, ready for operations")
            autoConnect()
        case .poweredOff:
            print("Bluetooth powered off")
        case .unauthorized:
            print("Bluetooth unauthorized")
        default:
            print("Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown Device"
        
        // Skip unknown devices
        guard name != "Unknown Device" else { return }
        
        // Check if this is one of our target devices
        let isPriority = BtConst.TARGET_DEVICES.contains { deviceName in
            name.contains(deviceName)
        }
        
        let newDevice = DiscoveredDevice(
            id: peripheral.identifier.uuidString,
            name: name,
            rssi: RSSI.intValue,
            peripheral: peripheral,
            isPriority: isPriority
        )
        
        // Add if not already in list
        if !discoveredDevices.contains(where: { $0.id == newDevice.id }) {
            // Add and sort with priority devices first
            DispatchQueue.main.async {
                self.discoveredDevices.append(newDevice)
                self.discoveredDevices.sort {
                    if $0.isPriority && !$1.isPriority { return true }
                    if !$0.isPriority && $1.isPriority { return false }
                    return $0.name < $1.name
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        peripheral.delegate = self
        
        // Discover services - don't filter by UUID since we connected based on name
        peripheral.discoverServices(nil)
        
        let device = BLEDevice(
            id: peripheral.identifier.uuidString,
            name: peripheral.name ?? "Connected Device",
            peripheral: peripheral
        )
        
        DispatchQueue.main.async {
            self.connectedDevice = device
            self.isConnected = true
            self.saveConnectedDevice()
        }
        
        onDeviceConnected?(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        onConnectionFailure?(peripheral, error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let e = error as? CBError {
            print("Disconnected (\(e.code.rawValue)): \(e.code)")
        } else if let e = error {
            print("Disconnected (unknown): \(e.localizedDescription)")
        } else {
            print("Disconnected (no error provided)")
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDevice = nil
        }
        
        onDeviceDisconnected?(peripheral, error)
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothScanner: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        onServicesDiscovered?(peripheral, error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        onCharacteristicsDiscovered?(peripheral, service, error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else {
            print("Failed to read characteristic: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        onCharacteristicValueUpdated?(peripheral, characteristic, data)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Failed to write characteristic: \(error.localizedDescription)")
        } else {
            print("Successfully wrote to characteristic: \(characteristic.uuid)")
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Error changing notification state: \(error.localizedDescription)")
        } else {
            print("Notification state updated for \(characteristic.uuid): " +
                  (characteristic.isNotifying ? "enabled" : "disabled"))
        }
        
        onNotificationStateChanged?(peripheral, characteristic, error)
    }
    
}
