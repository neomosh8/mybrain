import Foundation
import CoreBluetooth
import Combine
import Accelerate

//typealias BTService = BluetoothService
typealias BTService = MockBluetoothService

class BluetoothService: NSObject, ObservableObject {
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
    
    // MARK: - Simulation state
    private var simPhase: Double = 0.0
    private let simStep: Double = 0.15
    
    // Scanner properties
    @Published var isScanning = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isConnected = false
    @Published var connectedDevice: BLEDevice?
    @Published var permissionStatus: PermissionStatus = .unknown
    
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
    func startRecording(useTestSignal: Bool, enableLeadOff: Bool = false) {
        // Reset parser state
        parser.clearEEGData()
        parser.resetOnlineFilter()
        parser.updateReceivingState(isReceiving: true, inTestMode: useTestSignal)
        
        // Reset quality analyzer
        qualityAnalyzer.resetConnectionStatus()
        SignalProcessing.resetLeadoffData()
        
        // Update local state
        isInTestMode = useTestSignal
        
        // Start streaming
        streamer.startRecording(useTestSignal: useTestSignal, enableLeadOff: enableLeadOff)
        
        // Start lead-off analysis if enabled
        if enableLeadOff {
            qualityAnalyzer.startLeadOffAnalysis(channel1: eegChannel1, channel2: eegChannel2)
        }
    }
    
    func stopRecording() {
        streamer.stopRecording()
        qualityAnalyzer.stopAllAnalysis()
        parser.updateReceivingState(isReceiving: false, inTestMode: false)
        isInTestMode = false
    }
    
    // Device Information Commands
    func readSerialNumber() {
        sendCommand(featureId: NEOCORE_CORE_FEATURE_ID,
                    pduType: PDU_TYPE_COMMAND,
                    pduId: NEOCORE_CMD_ID_GET_SERIAL_NUM,
                    data: nil)
    }
    
    func readBatteryLevel() {
        sendCommand(featureId: NEOCORE_BATTERY_FEATURE_ID,
                    pduType: PDU_TYPE_COMMAND,
                    pduId: NEOCORE_CMD_ID_GET_BATTERY_LEVEL,
                    data: nil)
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
        } else {
            value = generateSimulatedValue(for: word)
        }
        
        feedbackSubject.send(value)
        return value
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
    
    private func generateSimulatedValue(for word: String) -> Double {
        let raw = sin(simPhase)
        
        // [0..100]
        let value = raw * 50 + 50
        
        simPhase += simStep
        if simPhase > .pi * 2 { simPhase -= .pi * 2 }
        
        return value
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
                peripheral.discoverCharacteristics([writeCharacteristicUUID, notifyCharacteristicUUID], for: service)
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
            
            // Auto-start streaming if configured
            if streamer.shouldAutoStartStreaming() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startRecording(useTestSignal: true, enableLeadOff: true)
                }
            }
            
            // Read device info
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.readSerialNumber()
                self.readBatteryLevel()
            }
        }
    }
}
