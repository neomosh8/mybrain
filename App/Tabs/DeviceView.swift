import SwiftUI

struct DeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bluetoothService: MockBluetoothService
    @State private var showTestSignalView = false
    @State private var showDeviceScanner = false
    @State private var showDeviceDetails = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if bluetoothService.isConnected, let device = bluetoothService.connectedDevice {
                    
                    deviceSetupHeaderView
                    
                    signalQualityView
                    
                    deviceSettingsView
                    
                    deviceTestingView
                    
                    liveEEGSignalsView
                    
                    electrodeStatusView
                    
                    deviceActionsView
                    
                    troubleshootingView
                    
                    availableDevicesView
                } else {
                    // No Device Connected
                    noDeviceConnectedView
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
        .appNavigationBar(
            title: "Device Setup",
            subtitle: "Connect your headset",
            onBackTap: {
                dismiss()
            }
        ) {
            // Skip button in navigation
            Button("Skip") {
                dismiss()
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.blue)
        }
        .sheet(isPresented: $showTestSignalView) {
            TestSignalView(bluetoothService: bluetoothService)
        }
        .sheet(isPresented: $showDeviceScanner) {
            DeviceDetailsView(bluetoothService: bluetoothService)
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
                if !showDeviceDetails {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showDeviceDetails = true
                        }
                    }) {
                        Text("Device Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                } else {
                    // Collapse button with modern pill design
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showDeviceDetails = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text("Collapse")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(20)
            
            // Expandable device details section
            if showDeviceDetails {
                deviceDetailsExpandedView
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
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
            leadOffDetectionView
            autoReconnectionView
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
    
    private var leadOffDetectionView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lead-off Detection")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Alert when electrodes disconnect")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Toggle switch
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
                    .frame(width: 50, height: 30)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .offset(x: 10) // Positioned to the right (on state)
            }
        }
    }
    
    private var autoReconnectionView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auto Reconnection")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Automatically reconnect when in range")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Toggle switch
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
                    .frame(width: 50, height: 30)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .offset(x: 10) // Positioned to the right (on state)
            }
        }
    }
}


// MARK: - Device Testing
extension DeviceView {
    private var deviceTestingView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Device Testing")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Test Drive Button
                Button(action: {
                    showTestSignalView = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Test Drive")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // View Signals Button
                Button(action: {
                    // Handle view signals action
                }) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 60, height: 50)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
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

// MARK: - Electrode Status
extension DeviceView {
    private var electrodeStatusView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("All Electrodes Connected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("No lead-off detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
}

// MARK: - Device Actions
extension DeviceView {
    private var deviceActionsView: some View {
        VStack(spacing: 12) {
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
}

// MARK: - Troubleshooting
extension DeviceView {
    private var troubleshootingView: some View {
        Button(action: {
            // Handle troubleshooting guide
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
}

// MARK: - Available Devices
extension DeviceView {
    private var availableDevicesView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Available Devices")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Scan") {
                    bluetoothService.startScanning()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                // Connected device
                HStack(spacing: 12) {
                    Image("Neurolink")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NeuroLink Pro")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(bluetoothService.batteryLevel ?? 78)% battery")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
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
                
                // Other available devices (if any)
                if bluetoothService.discoveredDevices.count > 1 {
                    ForEach(bluetoothService.discoveredDevices.filter { $0.id != bluetoothService.connectedDevice?.id }, id: \.id) { device in
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
                                
                                Text("Available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Connect") {
                                bluetoothService.connect(to: device)
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
            }
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
}

// MARK: - No Device Connected
extension DeviceView {
    private var noDeviceConnectedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
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
                    Text("No Device Connected")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Connect your NeuroLink Pro to get started with brain monitoring")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            Button(action: {
                showDeviceScanner = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Find Device")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
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
