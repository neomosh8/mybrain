import SwiftUI
import CoreBluetooth

struct OnboardingView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                // Pages
                if currentPage == 0 {
                    WelcomeView(
                        onNext: { currentPage = 1 },
                        colorScheme: colorScheme
                    )
                    .transition(.opacity)
                } else {
                    DeviceScanView(
                        bleManager: bleManager,
                        onSkip: { isOnboardingComplete = true }
                    )
                    .transition(.opacity)
                }
            }
            
            // Connection success overlay
            if bleManager.isConnected {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                ConnectionSuccessView {
                    isOnboardingComplete = true
                }
                .transition(.scale)
            }
            
            // Bluetooth not available overlay
            if bleManager.bluetoothState == .poweredOff {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                BluetoothOffView {
                    isOnboardingComplete = true
                }
            }
        }
        .animation(.easeInOut, value: currentPage)
        .animation(.spring(), value: bleManager.isConnected)
    }
}

// MARK: - Welcome Page
struct WelcomeView: View {
    var onNext: () -> Void
    var colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Headphone image with multiple fallbacks
            HeadphoneImageView()
                .frame(width: 200, height: 200)
            
            Text("Connect Your NeoBrain Headphones")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Connect your NeoBrain headphones to enhance your experience")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onNext) {
                Text("Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

// Separated view for better headphone image handling
struct HeadphoneImageView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if let darkImage = UIImage(named: "headphone"),
               let lightImage = UIImage(named: "headphone_b") {
                // If both assets exist, use the appropriate one based on color scheme
                Image(uiImage: colorScheme == .dark ? darkImage : lightImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let darkImage = UIImage(named: "headphone") {
                // If only dark image exists
                Image(uiImage: darkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let lightImage = UIImage(named: "headphone_b") {
                // If only light image exists
                Image(uiImage: lightImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback to SF Symbol
                Image(systemName: "headphones")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.primary)
                    .padding(40)
            }
        }
    }
}
// MARK: - Device Scan Page
struct DeviceScanView: View {
    @ObservedObject var bleManager: BLEManager
    var onSkip: () -> Void
    
    @State private var deviceCount = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Your Device")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 30)
            
            // Status text based on BLE state
            Text(bleManager.connectionState.rawValue)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Debug information
            Text("Found \(bleManager.discoveredDevices.count) devices")
                .font(.caption)
                .foregroundColor(.gray)
            
            if bleManager.isScanning && bleManager.discoveredDevices.isEmpty {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Scanning for devices...")
                        .foregroundColor(.secondary)
                }
                .frame(height: 300)
            } else {
                if bleManager.discoveredDevices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("No devices found")
                            .font(.headline)
                        
                        Text("Make sure your headphones are in pairing mode and nearby")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(height: 300)
                } else {
                    // Device list
                    DeviceListView(bleManager: bleManager)
                        .frame(height: 300)
                }
            }
            
            // Scan control button
            Button(action: {
                if bleManager.isScanning {
                    bleManager.stopScanning()
                } else {
                    bleManager.startScanning()
                }
            }) {
                Text(bleManager.isScanning ? "Stop Scanning" : "Scan Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 30)
            
            // For testing when no device available
            Button("Simulate Connection") {
                bleManager.simulateConnection()
            }
            .font(.footnote)
            .padding(.top, 8)
            
            // Skip button
            Button(action: onSkip) {
                Text("Skip for Now")
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            bleManager.startScanning()
        }
        .onDisappear {
            if bleManager.isScanning {
                bleManager.stopScanning()
            }
        }
        .onChange(of: bleManager.discoveredDevices.count) { newCount in
            deviceCount = newCount
        }
    }
}

// Separated list view for better state handling
struct DeviceListView: View {
    @ObservedObject var bleManager: BLEManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                // Recommended devices (QCC5181 or Neocore)
                let recommendedDevices = bleManager.discoveredDevices.filter {
                    bleManager.isNeocore($0) || bleManager.isQCC($0)
                }
                
                if !recommendedDevices.isEmpty {
                    Text("Recommended Devices (\(recommendedDevices.count))")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    ForEach(recommendedDevices, id: \.identifier) { device in
                        DeviceRow(device: device, isHighlighted: true)
                            .onTapGesture {
                                bleManager.connect(to: device)
                            }
                    }
                }
                
                // Other devices
                let otherDevices = bleManager.discoveredDevices.filter {
                    !bleManager.isNeocore($0) && !bleManager.isQCC($0)
                }
                
                if !otherDevices.isEmpty {
                    Text("Other Devices (\(otherDevices.count))")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    ForEach(otherDevices, id: \.identifier) { device in
                        DeviceRow(device: device, isHighlighted: false)
                            .onTapGesture {
                                bleManager.connect(to: device)
                            }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// Device row remains mostly the same
struct DeviceRow: View {
    let device: CBPeripheral
    let isHighlighted: Bool
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: "headphones")
                .font(.title2)
                .foregroundColor(isHighlighted ? .blue : .gray)
                .frame(width: 40)
            
            // Device details
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name ?? "Unknown Device")
                    .font(.headline)
                
                Text(device.identifier.uuidString.prefix(8) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Highlight indicator
            if isHighlighted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHighlighted ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Connection Success View
struct ConnectionSuccessView: View {
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.green)
            
            Text("Connected!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your NeoBrain headphones are now connected and ready to use.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
        )
        .shadow(radius: 15)
    }
}

// MARK: - Bluetooth Off View
struct BluetoothOffView: View {
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "bluetooth.slash")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.orange)
            
            Text("Bluetooth is Off")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Please enable Bluetooth in your device settings to connect to your headphones.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            Button(action: onContinue) {
                Text("Continue Without Connecting")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
        )
        .shadow(radius: 15)
    }
}

// MARK: - Auto-connect Loading View
struct AutoConnectLoadingView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var isComplete: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Headphone image with fallback
            Group {
                if let image = UIImage(named: colorScheme == .dark ? "headphone" : "headphone_b") {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                } else {
                    Image(systemName: "headphones")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .foregroundColor(.primary)
                }
            }
            
            Text(bleManager.connectionState.rawValue)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Spacer()
            
            Button("Skip") {
                isComplete = true
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 40)
        }
        .animation(.easeInOut, value: bleManager.connectionState)
        .onChange(of: bleManager.connectionState) { newState in
            if newState == .connected {
                // Give a moment to see success before proceeding
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isComplete = true
                }
            } else if newState == .failed || newState == .disconnected {
                // Give a moment in case of failure before showing manual connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isComplete = true
                }
            }
        }
        .onAppear {
            // Set a timeout in case connection takes too long
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                if !bleManager.isConnected {
                    isComplete = true
                }
            }
        }
    }
}
