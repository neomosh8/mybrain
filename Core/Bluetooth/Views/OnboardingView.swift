import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var bluetoothService: BluetoothService
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Main content
            if viewModel.isReconnecting {
                reconnectingView
            } else {
                contentView
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: viewModel.onboardingState)
    }
    
    // MARK: - Content Views
    private var contentView: some View {
        VStack {
            switch viewModel.onboardingState {
            case .welcome:
                welcomeView
            case .scanning:
                deviceScanningView
            case .connecting:
                connectingView
            case .connected:
                connectedView
            case .permissionIssue:
                permissionIssueView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(radius: 10)
        )
        .padding(.horizontal, 20)
    }
    
    private var reconnectingView: some View {
        VStack(spacing: 24) {
            Text("Connecting to Your Headset")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
                .tint(.white)
            
            Button(action: {
                bluetoothService.stopScanning()
                viewModel.isReconnecting = false
                viewModel.onboardingState = .welcome
            }) {
                Text("Cancel")
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(Color.white, lineWidth: 1.5)
                    )
            }
        }
    }
    
    // MARK: - Specific State Views
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Text("Connect Your Headset")
                .font(.title)
                .fontWeight(.bold)
            
            // Headphone image
            Image("Neurolink")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 150)
            
            Text(
                "To use all features of the app, you'll need to connect your Neocore headset."
            )
            .multilineTextAlignment(.center)
            .padding()
            
            Button(action: {
                viewModel.nextStep()
            }) {
                Text("Let's Connect")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            Button(action: {
                viewModel.skipOnboarding()
            }) {
                Text("Skip for now")
                    .foregroundColor(.gray)
            }
            .padding(.top, 5)
        }
        .padding()
    }
    
    private var deviceScanningView: some View {
        VStack(spacing: 20) {
            Text("Select Your Headset")
                .font(.title2)
                .fontWeight(.bold)
            
            if bluetoothService.isScanning && bluetoothService.discoveredDevices.isEmpty {
                ProgressView("Scanning...")
                    .padding()
            } else {
                List {
                    ForEach(bluetoothService.discoveredDevices) { device in
                        deviceRow(device)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectDevice(device)
                            }
                    }
                }
                .frame(height: 300)
                .listStyle(PlainListStyle())
            }
            
            HStack(spacing: 10) {
                Button(action: {
                    if bluetoothService.isScanning {
                        bluetoothService.stopScanning()
                    } else {
                        bluetoothService.startScanning()
                    }
                }) {
                    Text(
                        bluetoothService.isScanning ? "Stop Scanning" : "Scan Again"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    viewModel.skipOnboarding()
                }) {
                    Text("Skip")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }
    
    private var connectingView: some View {
        VStack(spacing: 30) {
            Text("Connecting...")
                .font(.title2)
                .fontWeight(.bold)
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Establishing connection to your Neocore headset")
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                viewModel.skipOnboarding()
                bluetoothService.stopScanning()
            }) {
                Text("Cancel")
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(Color.red, lineWidth: 1.5)
                    )
            }
        }
        .padding()
    }
    
    private var connectedView: some View {
        VStack(spacing: 30) {
            Text("Connected!")
                .font(.title)
                .fontWeight(.bold)
            
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .foregroundColor(.green)
                .frame(width: 80, height: 80)
            
            if let device = bluetoothService.connectedDevice {
                Text("Successfully connected to \(device.name)")
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                Text("Your Neocore headset is now connected and ready to use")
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Button(action: {
                viewModel.hasCompletedOnboarding = true
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private var permissionIssueView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.orange)
                .frame(width: 60, height: 60)
            
            Text("Bluetooth Issues")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(bluetoothPermissionMessage)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            Button(action: {
                viewModel.skipOnboarding()
            }) {
                Text("Skip for now")
                    .foregroundColor(.gray)
            }
            .padding(.top, 5)
        }
        .padding()
    }
    
    // MARK: - Helper Views and Properties
    private func deviceRow(_ device: DiscoveredDevice) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                
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
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(device.isPriority ? Color.blue.opacity(0.1) : Color.clear)
        )
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
