import Foundation
import Combine

class TestSignalViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordedData: [Int32] = []
    @Published var displayData: [CGPoint] = []
    @Published var yAxisRange: ClosedRange<CGFloat> = -10000...10000
    @Published var recordingDuration: TimeInterval = 0
    @Published var normalizedData = true
    
    // MARK: - Private Properties
    private var bluetoothService: BluetoothService
    private var cancellables = Set<AnyCancellable>()
    private var startTime: Date?
    private var timer: Timer?
    
    // MARK: - Initialization
    init(bluetoothService: BluetoothService) {
        self.bluetoothService = bluetoothService
        
        // Subscribe to test signal data updates
        bluetoothService.$testSignalData
            .sink { [weak self] newData in
                guard let self = self else { return }
                
                // Print debug info
                print(
                    "TestSignalViewModel: Received \(newData.count) data points"
                )
                
                if self.isRecording && !newData.isEmpty {
                    // Process the new data for display
                    self.processData(newData)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func startRecording() {
        guard !isRecording, bluetoothService.isConnected else { return }
        
        print("TestSignalViewModel: Starting recording")
        
        // Reset data
        recordedData = []
        displayData = []
        recordingDuration = 0
        
        // Set recording flag first
        isRecording = true
        
        // Set start time
        startTime = Date()
        
        // Start the test signal and data streaming
        bluetoothService.startTestDrive()
        
        // Start timer to track duration
        timer = Timer
            .scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let startTime = self.startTime else {
                    return
                }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        
        print("TestSignalViewModel: Recording started")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        print("TestSignalViewModel: Stopping recording")
        
        // Stop the test signal and data streaming
        bluetoothService.stopTestDrive()
        
        // Stop recording
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        print("TestSignalViewModel: Recording stopped")
    }
    
    func toggleNormalization() {
        normalizedData.toggle()
        
        // Reprocess the data with the new normalization setting
        if !recordedData.isEmpty {
            processData(recordedData)
        }
    }
    
    // MARK: - Private Methods
    private func processData(_ data: [Int32]) {
        print("TestSignalViewModel: Processing \(data.count) data points")
        
        // Store the complete data
        recordedData = data
        
        // Skip processing if no data
        guard !data.isEmpty else { return }
        
        // Calculate min/max for Y-axis and stats display
        if let minValue = data.min(), let maxValue = data.max() {
            let minY = CGFloat(minValue)
            let maxY = CGFloat(maxValue)
            
            // Add 10% padding to range
            let padding = Swift.max(1.0, (maxY - minY) * 0.1)
            let newMin = minY - padding
            let newMax = maxY + padding
            
            print(
                "TestSignalViewModel: Y Range - min: \(newMin), max: \(newMax)"
            )
            
            // Always update range for stats
            DispatchQueue.main.async {
                self.yAxisRange = newMin...newMax
            }
        }
        
        // Convert data to points
        var dataPoints: [CGPoint]
        
        if normalizedData {
            // Normalize the data to range from 0 to 1
            let intMin = data.min() ?? 0
            let intMax = data.max() ?? 1
            let range = intMax - intMin
            
            // Avoid division by zero
            let scaleFactor = range != 0 ? 1.0 / CGFloat(range) : 1.0
            
            dataPoints = data.enumerated().map { (index, value) in
                let normalizedY = CGFloat(value - intMin) * scaleFactor
                return CGPoint(x: CGFloat(index), y: normalizedY)
            }
        } else {
            // Use raw values
            dataPoints = data.enumerated().map { (index, value) in
                CGPoint(x: CGFloat(index), y: CGFloat(value))
            }
        }
        
        // Downsample for display
        let maxPoints = 1000 // Maximum points to display for performance
        let finalPoints: [CGPoint]
        
        if dataPoints.count > maxPoints {
            // Simple downsampling - take every nth point
            let stride = dataPoints.count / maxPoints
            finalPoints = stride > 1 ?
            dataPoints.enumerated()
                .filter { $0.offset % stride == 0 }
                .map { $0.element } :
            dataPoints
        } else {
            finalPoints = dataPoints
        }
        
        // Update display data on main thread
        DispatchQueue.main.async {
            self.displayData = finalPoints
            print(
                "TestSignalViewModel: Display data updated with \(finalPoints.count) points"
            )
        }
    }
}
