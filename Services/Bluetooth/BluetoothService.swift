import Foundation
import CoreBluetooth
import Combine
import Accelerate

final class BluetoothService: NSObject, BTServiceProtocol {
    // MARK: - Composed Components
    private let scanner = BluetoothScanner()
    private let streamer = BluetoothStreamer()
    private let parser = ResponseParser()
    private let qualityAnalyzer = QualityAnalyzer()
    
    // MARK: - Published Properties (Delegated to Components)
    static let shared = BluetoothService()
    
    private let feedbackSubject = PassthroughSubject<Double, Never>()
    
    var feedbackPublisher: AnyPublisher<Double, Never> {
        feedbackSubject.eraseToAnyPublisher()
    }
    
    // Scanner properties
    @Published var isScanning = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isConnected = false
    @Published var connectedDevice: BLEDevice?
    @Published var permissionStatus: PermissionStatus = .unknown
    private var batteryTimer: Timer?
    
    // Parser properties
    @Published var batteryLevel: Int?
    @Published var serialNumber: String?
    @Published var testSignalData: [Int32] = []
    @Published var eegChannel1: [Int32] = []
    @Published var eegChannel2: [Int32] = []
    
    // Streamer properties
    @Published var isTestSignalEnabled = false
    @Published var isStreamingEnabled = false
    @Published var isReceivingTestData = false
    @Published var isInNormalMode = false
    @Published var isLeadOffDetectionEnabled = false
    private var isInTestMode = false
    
    // Quality Analyzer properties
    @Published var ch1ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    @Published var ch2ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    
    // MARK: - Private Properties
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()
    private var keepAliveTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupComponentBindings()
        setupComponentCallbacks()
    }
    
    // MARK: - Component Binding Setup
    private func setupComponentBindings() {
        // Bind scanner properties
        scanner.$isScanning.assign(to: &$isScanning)
        scanner.$discoveredDevices.assign(to: &$discoveredDevices)
        scanner.$isConnected.assign(to: &$isConnected)
        scanner.$connectedDevice.assign(to: &$connectedDevice)
        scanner.$permissionStatus.assign(to: &$permissionStatus)
        
        // Bind parser properties
        parser.$batteryLevel.assign(to: &$batteryLevel)
        parser.$serialNumber.assign(to: &$serialNumber)
        parser.$testSignalData.assign(to: &$testSignalData)
        parser.$eegChannel1.assign(to: &$eegChannel1)
        parser.$eegChannel2.assign(to: &$eegChannel2)
        
        // Bind streamer properties
        streamer.$isTestSignalEnabled.assign(to: &$isTestSignalEnabled)
        streamer.$isStreamingEnabled.assign(to: &$isStreamingEnabled)
        streamer.$isReceivingTestData.assign(to: &$isReceivingTestData)
        streamer.$isInNormalMode.assign(to: &$isInNormalMode)
        streamer.$isLeadOffDetectionEnabled.assign(to: &$isLeadOffDetectionEnabled)
        
        // Bind quality analyzer properties
        qualityAnalyzer.$ch1ConnectionStatus.assign(to: &$ch1ConnectionStatus)
        qualityAnalyzer.$ch2ConnectionStatus.assign(to: &$ch2ConnectionStatus)
    }
    
    private func setupComponentCallbacks() {
        // Scanner callbacks
        scanner.onDeviceConnected = { [weak self] peripheral in
            self?.handleDeviceConnection(peripheral)
        }
        
        scanner.onDeviceDisconnected = { [weak self] peripheral, error in
            self?.handleDeviceDisconnection(peripheral, error)
        }
        
        scanner.onConnectionFailure = { [weak self] peripheral, error in
            print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        }
        
        scanner.onServicesDiscovered = { [weak self] peripheral, error in
            self?.handleServicesDiscovered(peripheral, error)
        }
        
        scanner.onCharacteristicsDiscovered = { [weak self] peripheral, service, error in
            self?.handleCharacteristicsDiscovered(peripheral, service, error)
        }
        
        scanner.onCharacteristicValueUpdated = { [weak self] peripheral, characteristic, data in
            if let data = data {
                self?.parser.parseResponse(from: data)
            }
        }
        
        scanner.onNotificationStateChanged = { [weak self] peripheral, characteristic, error in
            if let error = error {
                print("Failed to change notification state for \(characteristic.uuid): \(error.localizedDescription)")
            } else {
                print("Notification state for \(characteristic.uuid) is now " +
                      (characteristic.isNotifying ? "ENABLED" : "DISABLED"))
            }
        }
        
        // Streamer callbacks
        streamer.onSendCommand = { [weak self] featureId, pduType, pduId, data in
            self?.sendCommand(featureId: featureId, pduType: pduType, pduId: pduId, data: data)
        }
        
        // Parser callbacks
        parser.onEEGDataReceived = { [weak self] ch1, ch2 in
            // Start quality analysis when EEG data is received
            if let self = self {
                self.qualityAnalyzer.startQualityAnalysis(channel1: self.eegChannel1, channel2: self.eegChannel2)
            }
        }
    }
    
    // MARK: - Public Interface (Delegated to Components)
    
    // Scanner methods
    func startScanning() {
        scanner.startScanning()
    }
    
    func stopScanning() {
        scanner.stopScanning()
    }
    
    func autoConnect() {
        scanner.autoConnect()
    }
    
    func connect(to device: DiscoveredDevice) {
        scanner.connect(to: device)
    }
    
    func disconnect() {
        scanner.disconnect()
        streamer.stopRecording()
        qualityAnalyzer.stopAllAnalysis()
        parser.clearEEGData()
    }
    
    func checkPermissions() {
        scanner.checkPermissions()
    }
    
    // Streamer methods
    
    // NEW: expose mode-only methods
    func setModeNormal() {
        streamer.setModeNormal()
        parser.setMode(.normal)
    }

    func setModeTestSignal() {
        streamer.setModeTestSignal()
        parser.setMode(.testSignal)
    }

    func setModeLeadOff() {
        streamer.setModeLeadOff()
        parser.setMode(.leadOff)
    }

    
    func startRecording(useTestSignal: Bool, enableLeadOff: Bool = false) {
        // BACK-COMPAT: if callers still pass flags, map them to the new API first.
        if enableLeadOff {
            setModeLeadOff()
        } else if useTestSignal {
            setModeTestSignal()
        } else {
            setModeNormal()
        }

        // Reset/prepare parsing & quality
        parser.clearEEGData()
        parser.resetOnlineFilter()
        parser.setRecording(true)

        qualityAnalyzer.resetConnectionStatus()
        SignalProcessing.resetLeadoffData()

        streamer.startRecording()
        
//        if !useTestSignal && !enableLeadOff {
//            startKeepAliveIfNeeded()
//        } else {
//            stopKeepAlive()
//        }

        if streamer.currentMode == .leadOff {
            qualityAnalyzer.startLeadOffAnalysis(channel1: eegChannel1, channel2: eegChannel2)
        } else {
            qualityAnalyzer.stopLeadOffAnalysis()
        }
    }

    func stopRecording() {
//        stopKeepAlive()
        streamer.stopRecording()
        qualityAnalyzer.stopAllAnalysis()
        parser.setRecording(false)

//        if let notifyChar = notifyCharacteristic {
//            scanner.setNotifications(enabled: false, for: notifyChar)
//            print("Notifications disabled for EEG characteristic")
//        }
    }

    // Device Information Commands
    func readSerialNumber() {
        sendCommand(featureId: BtConst.NEOCORE_CORE_FEATURE_ID,
                    pduType: BtConst.PDU_TYPE_COMMAND,
                    pduId: BtConst.NEOCORE_CMD_ID_GET_SERIAL_NUM,
                    data: nil)
    }
    
    func readBatteryLevel() {
        sendCommand(featureId: BtConst.NEOCORE_BATTERY_FEATURE_ID,
                    pduType: BtConst.PDU_TYPE_COMMAND,
                    pduId: BtConst.NEOCORE_CMD_ID_GET_BATTERY_LEVEL,
                    data: nil)
    }
    
    func startBatteryUpdates(interval: TimeInterval = 300.0) {
        stopBatteryUpdates()
        
        print("Starting battery monitoring with interval: \(interval)s")
        
        readBatteryLevel()
        
        batteryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.readBatteryLevel()
        }
    }
    
    func stopBatteryUpdates() {
        batteryTimer?.invalidate()
        batteryTimer = nil
        print("Stopped battery monitoring")
    }
    
    
    // Quality Analysis
    func analyzeSignalQuality() -> (ch1: SignalQualityMetrics?, ch2: SignalQualityMetrics?) {
        return qualityAnalyzer.analyzeSignalQuality(channel1: eegChannel1, channel2: eegChannel2)
    }
    
    // Feedback Processing
    func processFeedback(word: String) -> Double {
        let value: Double
        if isConnected {
            value = calculateSignalValue()
            
            feedbackSubject.send(value)
            return value
        }
        
        return 0.0
    }
    
    // MARK: - Private Helper Methods
    private func calculateSignalValue() -> Double {
        // Take last few samples from each channel and average them
        let ch1Samples = eegChannel1.suffix(10)
        let ch2Samples = eegChannel2.suffix(10)
        
        if ch1Samples.isEmpty && ch2Samples.isEmpty {
            return 0.0 // Fallback if no data
        }
        
        let ch1Avg = ch1Samples.isEmpty ? 0 : Double(ch1Samples.reduce(0, +)) / Double(ch1Samples.count)
        let ch2Avg = ch2Samples.isEmpty ? 0 : Double(ch2Samples.reduce(0, +)) / Double(ch2Samples.count)
        
        let raw = (ch1Avg + ch2Avg) / 2.0
        return raw
    }
    
    private func startKeepAliveIfNeeded() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected, self.isStreamingEnabled else { return }
            self.readBatteryLevel()
        }
    }

    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }
    
    // MARK: - Command and Response Handling
    private func sendCommand(featureId: UInt16, pduType: UInt16, pduId: UInt16, data: Data?) {
        guard let writeCharacteristic = writeCharacteristic else {
            print("Write characteristic not available")
            return
        }
        
        // Build command header
        let commandId = (featureId << 9) | (pduType << 7) | pduId
        var commandData = Data()
        commandData.append(UInt8((commandId >> 8) & 0xFF))
        commandData.append(UInt8(commandId & 0xFF))
        
        // Append payload if present
        if let payload = data {
            commandData.append(payload)
        }
        
        // Send command
        scanner.writeToCharacteristic(data: commandData, characteristic: writeCharacteristic)
        print("Sent command - Feature: 0x\(String(featureId, radix: 16)), Type: \(pduType), ID: 0x\(String(pduId, radix: 16))")
    }
    
    // MARK: - Connection Event Handlers
    private func handleDeviceConnection(_ peripheral: CBPeripheral) {
        // Connection handled by scanner, just log
        print("Device connected: \(peripheral.name ?? "Unknown")")
    }
    
    private func handleDeviceDisconnection(_ peripheral: CBPeripheral, _ error: Error?) {
        // Reset characteristics
        writeCharacteristic = nil
        notifyCharacteristic = nil
        
        // Reset component states
        streamer.resetState()
        qualityAnalyzer.resetConnectionStatus()
        parser.clearEEGData()
        
        // Reset local state
        isInTestMode = false
        
        print("Device disconnected: \(peripheral.name ?? "Unknown")")
    }
    
    private func handleServicesDiscovered(_ peripheral: CBPeripheral, _ error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if parser.isTargetService(service) {
                print("Found target service: \(service.uuid)")
                peripheral.discoverCharacteristics([BtConst.WRITE_CHARACTERISTIC_UUID, BtConst.NOTIFY_CHARACTERISTIC_UUID], for: service)
            }
        }
    }
    
    private func handleCharacteristicsDiscovered(_ peripheral: CBPeripheral, _ service: CBService, _ error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if parser.isWriteCharacteristic(characteristic) {
                writeCharacteristic = characteristic
                print("Found write characteristic")
            } else if parser.isNotifyCharacteristic(characteristic) {
                notifyCharacteristic = characteristic
                scanner.setNotifications(enabled: true, for: characteristic)
                print("Found and enabled notify characteristic")
            }
        }
        
        // Once we have both characteristics, we're fully connected
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            print("Device fully connected and ready")
            
            self.isConnected = true
            print("Device marked as connected")
            
            let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
            print("MTU: \(mtu)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.readSerialNumber()
                self.readBatteryLevel()
            }
            
//            // Auto-start streaming if configured
//            if streamer.shouldAutoStartStreaming() {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    self.startRecording(useTestSignal: true, enableLeadOff: true)
//                }
//            }
        }
    }
}
