import SwiftUI

struct TestSignalView: View {
    @ObservedObject var bluetoothService: BluetoothService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isRecording = false
    @State private var showDebugInfo = false
    @State private var startTime: Date?
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var normalized = true
    @State private var selectedChannel = 0 // 0 = both, 1 = channel1, 2 = channel2
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Test Signal")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            // Channel selection
            Picker("Channel", selection: $selectedChannel) {
                Text("Both Channels").tag(0)
                Text("Channel 1").tag(1)
                Text("Channel 2").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Signal plot
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .cornerRadius(8)
                
                if bluetoothService.eegChannel1.isEmpty && bluetoothService.eegChannel2.isEmpty {
                    if isRecording {
                        ProgressView("Waiting for data...")
                    } else {
                        Text("No signal data - Press Start Recording")
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack {
                        // Channel selection label
                        HStack {
                            if selectedChannel == 0 {
                                Text("Channel 1 & 2")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if selectedChannel == 1 {
                                Text("Channel 1")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Channel 2")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.leading, 12)
                        .padding(.top, 4)
                        
                        // Channel waveforms
                        if selectedChannel == 0 {
                            // Both channels
                            ZStack {
                                // Channel 1 (blue)
                                WaveformView(
                                    dataPoints: bluetoothService.eegChannel1,
                                    normalized: normalized,
                                    color: .blue
                                )
                                
                                // Channel 2 (green)
                                WaveformView(
                                    dataPoints: bluetoothService.eegChannel2,
                                    normalized: normalized,
                                    color: .green
                                )
                            }
                        } else if selectedChannel == 1 {
                            // Only Channel 1
                            WaveformView(
                                dataPoints: bluetoothService.eegChannel1,
                                normalized: normalized,
                                color: .blue
                            )
                        } else {
                            // Only Channel 2
                            WaveformView(
                                dataPoints: bluetoothService.eegChannel2,
                                normalized: normalized,
                                color: .green
                            )
                        }
                    }
                    .padding(8)
                }
            }
            .frame(height: 280)
            .padding(.horizontal)
            
            // Recording duration
            Text(String(format: "Recording: %.1f seconds", recordingDuration))
                .font(.headline)
                .foregroundColor(isRecording ? .green : .secondary)
            
            // Recording controls
            HStack(spacing: 30) {
                Button(action: toggleRecording) {
                    HStack {
                        Image(systemName: isRecording ? "stop.fill" : "play.fill")
                        Text(isRecording ? "Stop Recording" : "Start Recording")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(minWidth: 200)
                    .background(isRecording ? Color.red : Color.green)
                    .cornerRadius(10)
                }
            }
            .padding(.bottom, 10)
            
            // Normalization toggle
            Toggle("Normalize Signal", isOn: $normalized)
                .padding(.horizontal)
            
            // Stats
            if !bluetoothService.eegChannel1.isEmpty || !bluetoothService.eegChannel2.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signal Statistics:")
                        .font(.headline)
                    
                    // Channel 1 stats
                    if !bluetoothService.eegChannel1.isEmpty {
                        HStack {
                            Text("CH1:")
                                .foregroundColor(.blue)
                                .bold()
                            Text("Samples: \(bluetoothService.eegChannel1.count)")
                            Spacer()
                            Text("Min: \(bluetoothService.eegChannel1.min() ?? 0)")
                            Spacer()
                            Text("Max: \(bluetoothService.eegChannel1.max() ?? 0)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    // Channel 2 stats
                    if !bluetoothService.eegChannel2.isEmpty {
                        HStack {
                            Text("CH2:")
                                .foregroundColor(.green)
                                .bold()
                            Text("Samples: \(bluetoothService.eegChannel2.count)")
                            Spacer()
                            Text("Min: \(bluetoothService.eegChannel2.min() ?? 0)")
                            Spacer()
                            Text("Max: \(bluetoothService.eegChannel2.max() ?? 0)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // Debug toggle
            Toggle("Show Debug Info", isOn: $showDebugInfo)
                .padding(.horizontal)
            
            // Debug info
            if showDebugInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Information:")
                        .font(.headline)
                    
                    Group {
                        Text("Channel 1 Points: \(bluetoothService.eegChannel1.count)")
                        Text("Channel 2 Points: \(bluetoothService.eegChannel2.count)")
                        Text("Test Signal Enabled: \(bluetoothService.isTestSignalEnabled ? "Yes" : "No")")
                        Text("Streaming Enabled: \(bluetoothService.isStreamingEnabled ? "Yes" : "No")")
                        Text("Receiving Data: \(bluetoothService.isReceivingTestData ? "Yes" : "No")")
                        if let device = bluetoothService.connectedDevice {
                            Text("Device: \(device.name)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Spacer()
            
            Button("Close") {
                stopRecordingIfNeeded()
                presentationMode.wrappedValue.dismiss()
            }
            .padding(.bottom)
        }
        .onDisappear {
            stopRecordingIfNeeded()
        }
    }
    
    // Toggle recording functions remain the same
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        startTime = Date()
        
        // Start the timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let startTime = startTime else { return }
            recordingDuration = Date().timeIntervalSince(startTime)
        }
        
        // Start the test drive
        bluetoothService.startTestDrive()
    }
    
    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        // Stop the test drive
        bluetoothService.stopTestDrive()
    }
    
    private func stopRecordingIfNeeded() {
        if isRecording {
            stopRecording()
        }
    }
}

// Updated waveform view with color parameter
struct WaveformView: View {
    let dataPoints: [Int32]
    let normalized: Bool
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard !dataPoints.isEmpty else { return }
                
                let width = size.width
                let height = size.height
                
                var path = Path()
                
                if normalized {
                    // Find min and max for normalization
                    let minValue = CGFloat(dataPoints.min() ?? 0)
                    let maxValue = CGFloat(dataPoints.max() ?? 1)
                    let range = maxValue - minValue
                    
                    // Avoid division by zero
                    let scaleFactor = range != 0 ? 1.0 / range : 1.0
                    
                    // Scale to 80% of height with 10% padding top and bottom
                    let heightPadding = height * 0.1
                    let drawingHeight = height - (2 * heightPadding)
                    
                    // Calculate step size for x-axis
                    let step = width / CGFloat(dataPoints.count - 1)
                    
                    // Start path at first point
                    let y1 = height - heightPadding - (CGFloat(dataPoints[0]) - minValue) * scaleFactor * drawingHeight
                    path.move(to: CGPoint(x: 0, y: y1))
                    
                    // Add lines to all other points
                    for i in 1..<dataPoints.count {
                        let x = step * CGFloat(i)
                        let normalizedValue = (CGFloat(dataPoints[i]) - minValue) * scaleFactor
                        let y = height - heightPadding - (normalizedValue * drawingHeight)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                } else {
                    // Raw values - use a simple auto-scaling approach
                    let minValue = CGFloat(dataPoints.min() ?? 0)
                    let maxValue = CGFloat(dataPoints.max() ?? 1)
                    let range = maxValue - minValue
                    
                    // Avoid division by zero with fallback
                    let scaleFactor = range != 0 ? height / range : 1.0
                    
                    // Calculate step size for x-axis
                    let step = width / CGFloat(dataPoints.count - 1)
                    
                    // Start path at first point
                    let y1 = height - ((CGFloat(dataPoints[0]) - minValue) * scaleFactor)
                    path.move(to: CGPoint(x: 0, y: y1))
                    
                    // Add lines to all other points
                    for i in 1..<dataPoints.count {
                        let x = step * CGFloat(i)
                        let y = height - ((CGFloat(dataPoints[i]) - minValue) * scaleFactor)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                // Draw the path with the specified color
                context.stroke(
                    path,
                    with: .color(color),
                    lineWidth: 2
                )
            }
        }
    }
}
