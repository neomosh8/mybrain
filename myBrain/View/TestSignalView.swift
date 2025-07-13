import SwiftUI
import Combine

struct TestSignalView: View {
    @ObservedObject var bluetoothService: BluetoothService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isRecording = false
    @State private var showDebugInfo = false
    @State private var startTime: Date?
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var fftTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var normalized = true
    @State private var selectedChannel = 0 // 0 = both, 1 = channel1, 2 = channel2
    @State private var useTestSignal = true // Toggle between test signal and normal mode
    @State private var enableLeadOffDetection = false // Toggle for lead-off detection

    @State private var psdData: [Double] = [] // FFT data
    @State private var showShareSheet = false
    @State private var exportText = ""

    public init(bluetoothService: BluetoothService) {
        self.bluetoothService = bluetoothService
    }
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
                
                Toggle("Enable Lead-Off Detection", isOn: $enableLeadOffDetection)
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
            TabView {
                signalPlot
                    .tabItem { Label("Signal", systemImage: "waveform.path.ecg") }

                fftPlot
                    .tabItem { Label("FFT", systemImage: "chart.bar") }
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

                Button(action: {
                    exportText = exportSignalText()
                    showShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Data")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(minWidth: 150)
                    .background(Color.blue)
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
                        Text("Mode: \(useTestSignal ? "Test Signal" : "Normal")")
                        Text("Lead-Off Detection: \(enableLeadOffDetection ? "Enabled" : "Disabled")")
                        Text("Channel 1 Points: \(bluetoothService.eegChannel1.count)")
                        Text("Channel 2 Points: \(bluetoothService.eegChannel2.count)")
                        Text("Test Signal Active: \(bluetoothService.isTestSignalEnabled ? "Yes" : "No")")
                        Text("Lead-Off Active: \(bluetoothService.isLeadOffDetectionEnabled ? "Yes" : "No")")
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
        .onChange(of: selectedChannel) { _ in
            computeFFT()
        }
        .onReceive(fftTimer) { _ in
            if isRecording {
                computeFFT()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [exportText])
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
        .animation(.easeInOut, value: bluetoothService.isLeadOffDetectionEnabled)
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
                    .fill(getQualityColor(quality: quality, isConnected: isConnected))
                    .frame(width: max(0, min(geometry.size.width, CGFloat(quality / 100.0) * geometry.size.width)))
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

    // MARK: - Plot Components

    private var signalPlot: some View {
        ZStack {
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

                    if selectedChannel == 0 {
                        ZStack {
                            WaveformView(
                                dataPoints: bluetoothService.eegChannel1,
                                normalized: normalized,
                                color: .blue
                            )
                            WaveformView(
                                dataPoints: bluetoothService.eegChannel2,
                                normalized: normalized,
                                color: .green
                            )
                        }
                    } else if selectedChannel == 1 {
                        WaveformView(
                            dataPoints: bluetoothService.eegChannel1,
                            normalized: normalized,
                            color: .blue
                        )
                    } else {
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
    }

    private var fftPlot: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .cornerRadius(8)

            if psdData.isEmpty {
                Text("Waiting for FFT data...")
                    .foregroundColor(.gray)
            } else {
                SpectrumView(psd: psdData)
                    .padding(8)
            }
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

        // Start the timer for recording duration
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let startTime = startTime else { return }
            recordingDuration = Date().timeIntervalSince(startTime)
        }

        // Initial FFT calculation
        computeFFT()
        
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

    private func computeFFT() {
        let source: [Int32]
        switch selectedChannel {
        case 1:
            source = bluetoothService.eegChannel1
        case 2:
            source = bluetoothService.eegChannel2
        default:
            if bluetoothService.eegChannel1.isEmpty {
                source = bluetoothService.eegChannel2
            } else if bluetoothService.eegChannel2.isEmpty {
                source = bluetoothService.eegChannel1
            } else {
                let count = min(bluetoothService.eegChannel1.count, bluetoothService.eegChannel2.count)
                let ch1Segment = bluetoothService.eegChannel1.suffix(count)
                let ch2Segment = bluetoothService.eegChannel2.suffix(count)
                source = zip(ch1Segment, ch2Segment).map { val1, val2 in
                    let sum = Int64(val1) + Int64(val2)
                    let average = sum / 2
                    return Int32(clamping: average)
                }
            }
        }

        guard source.count >= 256 else {
            psdData = []
            return
        }
        let window = Array(source.suffix(256))
        psdData = SignalProcessing.welchPowerSpectrum(data: window, sampleRate: 250.0, maxFrequency: 100.0)
    }

    private func exportSignalText() -> String {
        let count = max(bluetoothService.eegChannel1.count, bluetoothService.eegChannel2.count)
        var lines: [String] = ["ch1,ch2"]
        for i in 0..<count {
            let ch1 = i < bluetoothService.eegChannel1.count ? bluetoothService.eegChannel1[i] : 0
            let ch2 = i < bluetoothService.eegChannel2.count ? bluetoothService.eegChannel2[i] : 0
            lines.append("\(ch1),\(ch2)")
        }
        return lines.joined(separator: "\n")
    }
}


// MARK: - Waveform View for Signal Display

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

                // Convert to Double to avoid overflow when dealing with large Int32 values
                let doubleDataPoints = dataPoints.map { Double($0) }

                if normalized {
                    // Find min and max for normalization
                    let minValue = doubleDataPoints.min() ?? 0.0
                    let maxValue = doubleDataPoints.max() ?? 1.0
                    let range = maxValue - minValue

                    // Avoid division by zero
                    let scaleFactor = range != 0 ? 1.0 / range : 1.0

                    // Scale to 80% of height with 10% padding top and bottom
                    let heightPadding = height * 0.1
                    let drawingHeight = height - (2 * heightPadding)

                    // Calculate step size for x-axis
                    let step = width / CGFloat(doubleDataPoints.count - 1)

                    // Start path at first point
                    let normalizedY1 = (doubleDataPoints[0] - minValue) * scaleFactor
                    let y1 = height - heightPadding - CGFloat(normalizedY1) * drawingHeight
                    path.move(to: CGPoint(x: 0, y: y1))

                    // Add lines to all other points
                    for i in 1..<doubleDataPoints.count {
                        let x = step * CGFloat(i)
                        let normalizedValue = (doubleDataPoints[i] - minValue) * scaleFactor
                        let y = height - heightPadding - CGFloat(normalizedValue) * drawingHeight
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                } else {
                    // Raw values - use a simple auto-scaling approach
                    let minValue = doubleDataPoints.min() ?? 0.0
                    let maxValue = doubleDataPoints.max() ?? 1.0
                    let range = maxValue - minValue

                    // Avoid division by zero with fallback
                    let scaleFactor = range != 0 ? Double(height) / range : 1.0

                    // Calculate step size for x-axis
                    let step = width / CGFloat(doubleDataPoints.count - 1)

                    // Start path at first point
                    let scaledY1 = (doubleDataPoints[0] - minValue) * scaleFactor
                    let y1 = height - CGFloat(scaledY1)
                    path.move(to: CGPoint(x: 0, y: y1))

                    // Add lines to all other points
                    for i in 1..<doubleDataPoints.count {
                        let x = step * CGFloat(i)
                        let scaledY = (doubleDataPoints[i] - minValue) * scaleFactor
                        let y = height - CGFloat(scaledY)
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

