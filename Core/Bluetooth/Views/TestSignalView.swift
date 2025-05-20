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
    @State private var useTestSignal = true // Toggle between test signal and normal mode
    @State private var enableLeadOffDetection = false // Toggle for lead-off detection
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text(useTestSignal ? "Test Signal" : "EEG Recording")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            // Mode toggles
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Use Test Signal", isOn: $useTestSignal)
                    .disabled(isRecording) // Can't change mode while recording
                
                Toggle(
                    "Enable Lead-Off Detection",
                    isOn: $enableLeadOffDetection
                )
                .disabled(isRecording) // Can't change mode while recording
            }
            .padding(.horizontal)
            
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
                        // Status bar with channel and mode info
                        HStack {
                            if selectedChannel == 0 {
                                Text("Ch 1 & 2")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if selectedChannel == 1 {
                                Text("Ch 1")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Ch 2")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            // Mode indicators
                            HStack(spacing: 4) {
                                if useTestSignal {
                                    Text("Test Signal")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.7))
                                        .cornerRadius(4)
                                }
                                
                                if bluetoothService.isLeadOffDetectionEnabled {
                                    Text("Lead-Off")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.7))
                                        .cornerRadius(4)
                                }
                                
                                if !useTestSignal && !bluetoothService.isLeadOffDetectionEnabled {
                                    Text("Normal Mode")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.7))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 12)
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
            .frame(height: 260)
            .padding(.horizontal)
            
            // Recording duration
            Text(String(format: "Recording: %.1f seconds", recordingDuration))
                .font(.headline)
                .foregroundColor(isRecording ? .green : .secondary)
            
            // Recording controls
            HStack(spacing: 30) {
                Button(action: toggleRecording) {
                    HStack {
                        Image(
                            systemName: isRecording ? "stop.fill" : "play.fill"
                        )
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
            .padding(.bottom, 8)
            
            // Connection quality indicators
            connectionQualityIndicators
                .padding(.bottom, 8)
            
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
                            Text(
                                "Samples: \(bluetoothService.eegChannel1.count)"
                            )
                            Spacer()
                            Text(
                                "Min: \(bluetoothService.eegChannel1.min() ?? 0)"
                            )
                            Spacer()
                            Text(
                                "Max: \(bluetoothService.eegChannel1.max() ?? 0)"
                            )
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
                            Text(
                                "Samples: \(bluetoothService.eegChannel2.count)"
                            )
                            Spacer()
                            Text(
                                "Min: \(bluetoothService.eegChannel2.min() ?? 0)"
                            )
                            Spacer()
                            Text(
                                "Max: \(bluetoothService.eegChannel2.max() ?? 0)"
                            )
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
                        Text(
                            "Mode: \(useTestSignal ? "Test Signal" : "Normal")"
                        )
                        Text(
                            "Lead-Off Detection: \(enableLeadOffDetection ? "Enabled" : "Disabled")"
                        )
                        Text(
                            "Channel 1 Points: \(bluetoothService.eegChannel1.count)"
                        )
                        Text(
                            "Channel 2 Points: \(bluetoothService.eegChannel2.count)"
                        )
                        Text(
                            "Test Signal Active: \(bluetoothService.isTestSignalEnabled ? "Yes" : "No")"
                        )
                        Text(
                            "Lead-Off Active: \(bluetoothService.isLeadOffDetectionEnabled ? "Yes" : "No")"
                        )
                        Text(
                            "Streaming Enabled: \(bluetoothService.isStreamingEnabled ? "Yes" : "No")"
                        )
                        Text(
                            "Receiving Data: \(bluetoothService.isReceivingTestData ? "Yes" : "No")"
                        )
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
    
    // MARK: - Connection Quality Components
    
    private var connectionQualityIndicators: some View {
        VStack(spacing: 8) {
            // Only show if lead-off detection is enabled
            if bluetoothService.isLeadOffDetectionEnabled {
                Text("Connection Quality")
                    .font(.headline)
                    .padding(.top, 4)
                
                // Channel 1 quality
                HStack {
                    Text("Channel 1:")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                        .frame(width: 80, alignment: .leading)
                    
                    connectionQualityBar(
                        quality: bluetoothService.ch1ConnectionStatus.quality,
                        isConnected: bluetoothService.ch1ConnectionStatus.connected
                    )
                    
                    let qualityText = getQualityText(
                        quality: bluetoothService.ch1ConnectionStatus.quality,
                        isConnected: bluetoothService.ch1ConnectionStatus.connected
                    )
                    Text(qualityText)
                        .font(.caption)
                        .foregroundColor(getQualityColor(
                            quality: bluetoothService.ch1ConnectionStatus.quality,
                            isConnected: bluetoothService.ch1ConnectionStatus.connected
                        ))
                        .frame(width: 80, alignment: .trailing)
                }
                
                // Channel 2 quality
                HStack {
                    Text("Channel 2:")
                        .foregroundColor(.green)
                        .font(.subheadline)
                        .frame(width: 80, alignment: .leading)
                    
                    connectionQualityBar(
                        quality: bluetoothService.ch2ConnectionStatus.quality,
                        isConnected: bluetoothService.ch2ConnectionStatus.connected
                    )
                    
                    let qualityText = getQualityText(
                        quality: bluetoothService.ch2ConnectionStatus.quality,
                        isConnected: bluetoothService.ch2ConnectionStatus.connected
                    )
                    Text(qualityText)
                        .font(.caption)
                        .foregroundColor(getQualityColor(
                            quality: bluetoothService.ch2ConnectionStatus.quality,
                            isConnected: bluetoothService.ch2ConnectionStatus.connected
                        ))
                        .frame(width: 80, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal)
        .animation(
            .easeInOut,
            value: bluetoothService.isLeadOffDetectionEnabled
        )
    }
    
    private func connectionQualityBar(quality: Double, isConnected: Bool) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .cornerRadius(4)
                
                // Foreground (filled portion)
                Rectangle()
                    .fill(
                        getQualityColor(
                            quality: quality,
                            isConnected: isConnected
                        )
                    )
                    .frame(
                        width: max(
                            0,
                            min(
                                geometry.size.width,
                                CGFloat(quality / 100.0) * geometry.size.width
                            )
                        )
                    )
                    .cornerRadius(4)
            }
        }
        .frame(height: 12)
    }
    
    private func getQualityText(quality: Double, isConnected: Bool) -> String {
        if !isConnected {
            return "Not Connected"
        }
        
        if quality >= 80 {
            return "Excellent"
        } else if quality >= 60 {
            return "Good"
        } else if quality >= 40 {
            return "Fair"
        } else if quality >= 20 {
            return "Poor"
        } else {
            return "Very Poor"
        }
    }
    
    private func getQualityColor(quality: Double, isConnected: Bool) -> Color {
        if !isConnected {
            return .red
        }
        
        if quality >= 80 {
            return .green
        } else if quality >= 60 {
            return .blue
        } else if quality >= 40 {
            return .yellow
        } else if quality >= 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Recording Control Methods
    
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
        timer = Timer
            .scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                guard let startTime = startTime else { return }
                recordingDuration = Date().timeIntervalSince(startTime)
            }
        
        // Start recording with current mode settings
        bluetoothService.startRecording(
            useTestSignal: useTestSignal,
            enableLeadOff: enableLeadOffDetection
        )
    }
    
    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        // Stop recording
        bluetoothService.stopRecording()
    }
    
    private func stopRecordingIfNeeded() {
        if isRecording {
            stopRecording()
        }
    }
}

// MARK: - Waveform View for Signal Display

struct WaveformView: View {
    let dataPoints: [Int32]
    let normalized: Bool
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            Canvas {
 context,
 size in
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
                    let y1 = height - heightPadding - (
                        CGFloat(dataPoints[0]) - minValue
                    ) * scaleFactor * drawingHeight
                    path.move(to: CGPoint(x: 0, y: y1))
                    
                    // Add lines to all other points
                    for i in 1..<dataPoints.count {
                        let x = step * CGFloat(i)
                        let normalizedValue = (
                            CGFloat(dataPoints[i]) - minValue
                        ) * scaleFactor
                        let y = height - heightPadding - (
                            normalizedValue * drawingHeight
                        )
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
                    let y1 = height - (
                        (CGFloat(dataPoints[0]) - minValue) * scaleFactor
                    )
                    path.move(to: CGPoint(x: 0, y: y1))
                    
                    // Add lines to all other points
                    for i in 1..<dataPoints.count {
                        let x = step * CGFloat(i)
                        let y = height - (
                            (CGFloat(dataPoints[i]) - minValue) * scaleFactor
                        )
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                // Draw the path
                context.stroke(
                    path,
                    with: .color(color),
                    lineWidth: 2
                )
            }
        }
    }
}

