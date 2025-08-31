import SwiftUI
import Combine

struct DeviceView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onNavigateToHome: (() -> Void)?
    
    init(onNavigateToHome: (() -> Void)? = nil) {
        self.onNavigateToHome = onNavigateToHome
    }
    
    @EnvironmentObject var bluetoothService: BTService
    @State private var showDeviceDetails = false
    
    
    @State private var leadoffDetection = true
    @State private var autoReconnection = true
    
    // Test Signal states
    @State private var showTestSignalOverlay = false
    @State private var isRecording = false
    @State private var showDebugInfo = false
    @State private var startTime: Date?
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var normalized = true
    @State private var selectedChannel = 0 // 0 = both, 1 = channel1, 2 = channel2
    @State private var useTestSignal = true // Toggle between test signal and normal mode
    @State private var enableLeadOffDetection = false // Toggle for lead-off detection
    
    // Onboarding states
    @State private var onboardingState: OnboardingState = .welcome
    @State private var isReconnecting = false
    
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if bluetoothService.isConnected, let device = bluetoothService.connectedDevice {
                    
                    deviceSetupHeaderView
                    
                    signalQualityView
                    
                    deviceSettingsView
                    
                    liveEEGSignalsView
                    
                    troubleshootingView
                    
                    deviceActionsView
                } else {
                    noDeviceConnectedView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .appNavigationBar(
            title: "Device Setup",
            subtitle: "Connect your headset",
            onBackTap: {
                onNavigateToHome?() ?? dismiss()
            }
        )
        .onAppear {
            setupBluetoothObservers()
            checkForPreviousDevice()
        }
        .fullScreenCover(isPresented: $showTestSignalOverlay) {
            TestSignalOverlayView()
        }
    }
}

// MARK: - No Device Connected View with Integrated Onboarding
extension DeviceView {
    private var noDeviceConnectedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if isReconnecting {
                reconnectingView
            } else {
                switch onboardingState {
                case .welcome:
                    welcomeConnectionView
                case .scanning:
                    deviceScanningView
                case .connecting:
                    connectingView
                case .permissionIssue:
                    permissionIssueView
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Reconnecting View
    private var reconnectingView: some View {
        VStack(spacing: 24) {
            Text("Connecting to Your Headset")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Button(action: {
                bluetoothService.stopScanning()
                isReconnecting = false
                onboardingState = .welcome
            }) {
                Text("Cancel")
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(Color.blue, lineWidth: 1.5)
                    )
            }
        }
    }
    
    // MARK: - Welcome View
    private var welcomeConnectionView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                // Device Icon
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image("Neurolink")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                    )
                
                VStack(spacing: 8) {
                    Text("Connect Your Headset")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("To use all features of the app, you'll need to connect your Neocore headset.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            VStack(spacing: 12) {
                Button(action: nextStep) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Let's Connect")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 40)
                
                Button(action: skipOnboarding) {
                    Text("Skip for now")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
    }
    
    // MARK: - Device Scanning View
    private var deviceScanningView: some View {
        VStack(spacing: 24) {
            Text("Looking for your headset")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if bluetoothService.isScanning {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            }
            
            Text("Make sure your Neocore headset is turned on and nearby")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            if bluetoothService.discoveredDevices.count > 1 {
                ForEach(bluetoothService.discoveredDevices) { device in
                    HStack(spacing: 12) {
                        Image("Neurolink")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Signal: \(device.rssi) dBm")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                        }
                        
                        Spacer()
                        
                        Button("Connect") {
                            selectDevice(device)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                    )
                }
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    if bluetoothService.isScanning {
                        bluetoothService.stopScanning()
                    } else {
                        bluetoothService.startScanning()
                    }
                }) {
                    Text(bluetoothService.isScanning ? "Stop Scan" : "Scan Again")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
                
                Button(action: {
                    onboardingState = .welcome
                }) {
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Connecting View
    private var connectingView: some View {
        VStack(spacing: 24) {
            Text("Connecting...")
                .font(.title2)
                .fontWeight(.bold)
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Please wait while we connect to your headset")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Permission Issue View
    private var permissionIssueView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("Bluetooth Issue")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(bluetoothPermissionMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                Text("Open Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Device Row
    private func deviceRow(_ device: DiscoveredDevice) -> some View {
        HStack {
            Image("Neurolink")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundColor(device.isPriority ? .blue : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Signal: \(device.rssi) dBm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if device.isPriority {
                Text("Neocore Device")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(device.isPriority ? Color.blue.opacity(0.1) : Color(.systemGray6))
        )
    }
    
    // MARK: - Onboarding Helper Methods
    private func nextStep() {
        switch onboardingState {
        case .welcome:
            onboardingState = .scanning
            bluetoothService.startScanning()
        case .scanning, .connecting, .permissionIssue:
            break
        }
    }
    
    private func selectDevice(_ device: DiscoveredDevice) {
        onboardingState = .connecting
        bluetoothService.connect(to: device)
    }
    
    private func skipOnboarding() {
        onNavigateToHome?() ?? dismiss()
    }
    
    private func checkForPreviousDevice() {
        isReconnecting = true
        bluetoothService.autoConnect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if !bluetoothService.isConnected {
                self.isReconnecting = false
                self.onboardingState = .welcome
            }
        }
    }
    
    private func setupBluetoothObservers() {
        // Monitor connection status
        bluetoothService.objectWillChange
            .sink {
                DispatchQueue.main.async {
                    let status = bluetoothService.permissionStatus
                    if status == .poweredOff || status == .denied || status == .unsupported {
                        onboardingState = .permissionIssue
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private var bluetoothPermissionMessage: String {
        switch bluetoothService.permissionStatus {
        case .poweredOff:
            return "Bluetooth is turned off. Please enable Bluetooth in your device settings."
        case .denied:
            return "Bluetooth permission is denied. Please allow Bluetooth access in Settings to connect to your Neocore headset."
        case .unsupported:
            return "Bluetooth is not supported on this device."
        default:
            return "There's an issue with Bluetooth. Please check your settings."
        }
    }
}

// MARK: - Device Setup Header
extension DeviceView {
    private var deviceSetupHeaderView: some View {
        VStack(spacing: 0) {
            // Main card content
            VStack(spacing: 16) {
                // Top row with device icon, info and status
                HStack(spacing: 12) {
                    // Device icon
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image("Neurolink")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.blue)
                        )
                    
                    // Device info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bluetoothService.connectedDevice?.name ?? "NeuroLink Pro")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Serial: \(bluetoothService.serialNumber ?? "Loading...")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Connection status
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Connected")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }
                
                // Device Details button or collapse button
                HStack {
                    if !showDeviceDetails {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showDeviceDetails = true
                            }
                        }) {
                            Text("Device Details")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(width: 120)
                                .background(
                                    Capsule()
                                        .fill(Color.white)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                        }
                    } else {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showDeviceDetails = false
                            }
                        }) {
                            Text("Collapse")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(width: 120)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                                        )
                                )
                        }
                    }
                }
            }
            .padding(20)
            
            // Expandable device details section
            deviceDetailsExpandedView
                .frame(height: showDeviceDetails ? nil : 0, alignment: .top)
                .clipped()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var deviceDetailsExpandedView: some View {
        VStack(spacing: 0) {
            // Separator line
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
                .padding(.horizontal, 20)
            
            // Device information content
            VStack(spacing: 16) {
                HStack {
                    Text("Device Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    deviceDetailRow(
                        title: "Model",
                        value: bluetoothService.connectedDevice?.name ?? "NeuroLink Pro"
                    )
                    
                    deviceDetailRow(
                        title: "Serial Number",
                        value: bluetoothService.serialNumber ?? "Loading..."
                    )
                    
                    deviceDetailRow(
                        title: "Firmware",
                        value: "v2.1.4"
                    )
                    
                    // Battery level with icon
                    HStack {
                        Text("Battery Level")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Image(systemName: getBatteryIconName())
                                .foregroundColor(getBatteryColor())
                                .font(.system(size: 16))
                            
                            Text("\(bluetoothService.batteryLevel ?? 0)%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    deviceDetailRow(
                        title: "Connection Time",
                        value: formatConnectionTime()
                    )
                }
            }
            .padding(20)
        }
    }
    
    private func deviceDetailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    private func formatConnectionTime() -> String {
        // This would ideally track actual connection time
        // For now, return a placeholder or calculate from connection timestamp
        return "00:24:18"
    }
    
}

// MARK: - Signal Quality
extension DeviceView {
    private var signalQualityView: some View {
        VStack(spacing: 16) {
            signalQualityHeader
            signalBarsVisualization
            channelQualityIndicators
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showTestSignalOverlay = true
                }
            }) {
                Text("Test Drive")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(width: 120)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .overlay(
                                Capsule()
                                    .stroke(Color.green.opacity(0.3), lineWidth: 0.5)
                            )
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    
    private var signalQualityHeader: some View {
        HStack {
            Text("Signal Quality")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("Excellent")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
    }
    
    private var signalBarsVisualization: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .frame(width: 12, height: CGFloat(20 + (index * 8)))
            }
        }
        .padding(.vertical, 8)
    }
    
    private var channelQualityIndicators: some View {
        HStack(spacing: 40) {
            VStack(spacing: 4) {
                Text("Ch1: \(Int(bluetoothService.ch1ConnectionStatus.quality * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Left Channel")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("Ch2: \(Int(bluetoothService.ch2ConnectionStatus.quality * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Right Channel")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Device Settings
extension DeviceView {
    private var deviceSettingsView: some View {
        VStack(spacing: 20) {
            signalQualityThresholdView
            
            ToggleRow(
                title: "Lead-off Detection",
                subtitle: "Alert when electrodes disconnect",
                isOn: $leadoffDetection
            )
            
            ToggleRow(
                title: "Auto Reconnection",
                subtitle: "Automatically reconnect when in range",
                isOn: $autoReconnection
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
    
    private var signalQualityThresholdView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Signal Quality Threshold")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Minimum signal quality for recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                Text("Low")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("75%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("High")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Slider representation
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 220, height: 4) // 75% of total width
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .offset(x: 220) // Position at 75%
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Live EEG Signals
extension DeviceView {
    private var liveEEGSignalsView: some View {
        VStack(spacing: 16) {
            liveEEGHeader
            liveEEGChannels
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
        )
    }
    
    private var liveEEGHeader: some View {
        HStack {
            Text("Live EEG Signals")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("Recording")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
    }
    
    private var liveEEGChannels: some View {
        VStack(spacing: 12) {
            eegChannelRow(channelName: "Channel 1", color: .blue, frequency: 4, amplitude: 8)
            eegChannelRow(channelName: "Channel 2", color: .green, frequency: 3.5, amplitude: 6)
        }
    }
    
    private func eegChannelRow(channelName: String, color: Color, frequency: Double, amplitude: Double) -> some View {
        HStack(spacing: 12) {
            Text(channelName)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 70, alignment: .leading)
            
            Rectangle()
                .fill(color)
                .frame(height: 2)
                .overlay(
                    Path { path in
                        let width: CGFloat = 200
                        let height: CGFloat = 20
                        
                        for x in stride(from: 0, through: width, by: 2) {
                            let y = height/2 + Darwin.sin(x * frequency * .pi / width) * amplitude
                            if x == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                        .stroke(color, lineWidth: 1.5)
                )
            
            Spacer()
            
            Text("125 Hz")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Device Actions
extension DeviceView {
    private var deviceActionsView: some View {
            Button(action: {
                bluetoothService.disconnect()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .medium))
                    Text("Disconnect Device")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
    }
}

// MARK: - Troubleshooting
extension DeviceView {
    private var troubleshootingView: some View {
        Button(action: {
            openURL("https://neocore.com/troubleshooting")
        }) {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                
                Text("Troubleshooting Guide")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
            )
        }
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}


// MARK: - Test Signal Overlay View

struct TestSignalOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bluetoothService: BTService
    
    // Test Signal states (moved from DeviceView)
    @State private var isRecording = false
    @State private var showDebugInfo = false
    @State private var startTime: Date?
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var normalized = true
    @State private var selectedChannel = 0 // 0 = both, 1 = channel1, 2 = channel2
    @State private var useTestSignal = true // Toggle between test signal and normal mode
    @State private var enableLeadOffDetection = false // Toggle for lead-off detection
    
    private func applySelectedMode() {
        // Lead-Off takes precedence (mutually exclusive with test signal)
        if enableLeadOffDetection {
            bluetoothService.setModeLeadOff()
            return
        }
        if useTestSignal {
            bluetoothService.setModeTestSignal()
        } else {
            bluetoothService.setModeNormal()
        }
    }

    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Button("Close") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Test Signal")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Empty space to balance the header
                        Text("Close")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.clear)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(Color.secondary.opacity(0.3))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            testSignalContent
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
        .onAppear {
            applySelectedMode()
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    // MARK: - Test Signal Content
    private var testSignalContent: some View {
        VStack(spacing: 20) {
            // Mode toggles
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: {
                        useTestSignal = false
                        enableLeadOffDetection = false
                        bluetoothService.setModeNormal()
                    }) {
                        Text("Normal")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(useTestSignal == false && enableLeadOffDetection == false ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(useTestSignal == false && enableLeadOffDetection == false ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .disabled(isRecording)

                    Button(action: {
                        useTestSignal = true
                        enableLeadOffDetection = false
                        bluetoothService.setModeTestSignal()
                    }) {
                        Text("Test Signal")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(useTestSignal && !enableLeadOffDetection ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(useTestSignal && !enableLeadOffDetection ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .disabled(isRecording)

                    Button(action: {
                        useTestSignal = false
                        enableLeadOffDetection = true
                        bluetoothService.setModeLeadOff()
                    }) {
                        Text("Lead-Off")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(enableLeadOffDetection ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(enableLeadOffDetection ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .disabled(isRecording)
                }

                
                ToggleRow(
                    title: "Normalize Signal",
                    subtitle: "Scale signal amplitude",
                    isOn: $normalized
                )
            }
            
            // Channel selection
            Picker("Channel", selection: $selectedChannel) {
                Text("Both Channels").tag(0)
                Text("Channel 1").tag(1)
                Text("Channel 2").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Signal plot
            signalPlotView
            
            // Recording duration
            Text(String(format: "Recording: %.1f seconds", recordingDuration))
                .font(.headline)
                .foregroundColor(isRecording ? .green : .secondary)
            
            // Recording controls
            Button(action: toggleRecording) {
                HStack {
                    Image(systemName: isRecording ? "stop.fill" : "play.fill")
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isRecording ? Color.red : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            
            // Connection quality indicators
            connectionQualityView
            
            // Signal statistics
            signalStatisticsView
        }
    }
    
    // MARK: - Signal Plot View
    private var signalPlotView: some View {
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
                    if selectedChannel == 0 {
                        // Both channels
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
    }
        
    // MARK: - Connection Quality
    private var connectionQualityView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection Quality")
                .font(.headline)
                .foregroundColor(.primary)
            
            if bluetoothService.isLeadOffDetectionEnabled {
                VStack {
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
                            .frame(width: 80, alignment: .leading)
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
                            .frame(width: 80, alignment: .leading)
                    }
                }
            }
            else {
                Text("Turn on the leadoff switch to see the connection quality.")
                    .font(.caption)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
    
    private func connectionQualityBar(quality: Double, isConnected: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(getBarColor(index: index, quality: quality, isConnected: isConnected))
                    .frame(width: 15, height: 8)
                    .cornerRadius(1)
            }
        }
    }
    
    private func getBarColor(index: Int, quality: Double, isConnected: Bool) -> Color {
        if !isConnected {
            return .gray
        }
        
        let threshold = Double(index + 1) * 0.2 // 0.2, 0.4, 0.6, 0.8, 1.0
        return quality >= threshold ? .green : .gray.opacity(0.3)
    }
    
    private func getQualityText(quality: Double, isConnected: Bool) -> String {
        if !isConnected {
            return "Disconnected"
        }
        
        let percentage = Int(quality * 100)
        if percentage >= 80 {
            return "Excellent (\(percentage)%)"
        } else if percentage >= 60 {
            return "Good (\(percentage)%)"
        } else if percentage >= 40 {
            return "Fair (\(percentage)%)"
        } else if percentage >= 20 {
            return "Poor (\(percentage)%)"
        } else {
            return "Very Poor (\(percentage)%)"
        }
    }
    
    private func getQualityColor(quality: Double, isConnected: Bool) -> Color {
        if !isConnected {
            return .gray
        }
        
        let percentage = quality * 100
        if percentage >= 60 {
            return .green
        } else if percentage >= 40 {
            return .yellow
        } else if percentage >= 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Signal Statistics
    private var signalStatisticsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signal Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Channel 1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(bluetoothService.eegChannel1.count) samples")
                        .font(.system(size: 14, weight: .medium))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Channel 2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(bluetoothService.eegChannel2.count) samples")
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Actions
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
        recordingDuration = 0

        // Start streaming; parsing happens automatically and WaveformView reads eegChannel1/2.
        bluetoothService.startRecording(
            useTestSignal: useTestSignal,
            enableLeadOff: enableLeadOffDetection
        )

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = startTime {
                recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        bluetoothService.stopRecording()
    }
}


// MARK: - Waveform View for Signal Display
struct WaveformView: View {
    let dataPoints: [Double]
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
                    // existing normalization
                    let minValue = CGFloat(dataPoints.min() ?? 0)
                    let maxValue = CGFloat(dataPoints.max() ?? 1)
                    let range = maxValue - minValue
                    let scaleFactor = range != 0 ? height / range : 1.0
                    
                    for (index, value) in dataPoints.enumerated() {
                        let x = CGFloat(index) / CGFloat(dataPoints.count - 1) * width
                        let normalizedValue = (CGFloat(value) - minValue) * scaleFactor
                        let y = height - normalizedValue
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                } else {
                    // Fixed Y axis range [-40, 40]
                    let minDisplayValue: CGFloat = -40
                    let maxDisplayValue: CGFloat = 40
                    let range = maxDisplayValue - minDisplayValue
                    
                    for (index, value) in dataPoints.enumerated() {
                        let x = CGFloat(index) / CGFloat(dataPoints.count - 1) * width
                        let y = height - ((CGFloat(value) - minDisplayValue) / range * height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                
                context.stroke(path, with: .color(color), lineWidth: 1.5)
            }
        }
        .frame(height: 100)
    }
}


// MARK: - Helper Methods
extension DeviceView {
    private func getBatteryIconName() -> String {
        guard let level = bluetoothService.batteryLevel else {
            return "battery.0"
        }
        
        switch level {
        case 76...100: return "battery.100"
        case 51...75: return "battery.75"
        case 26...50: return "battery.50"
        case 1...25: return "battery.25"
        default: return "battery.0"
        }
    }
    
    private func getBatteryColor() -> Color {
        guard let level = bluetoothService.batteryLevel else {
            return .gray
        }
        
        switch level {
        case 60...100: return .green
        case 30...59: return .yellow
        default: return .red
        }
    }
}
