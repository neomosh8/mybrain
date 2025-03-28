//
//  DeviceDetailsView.swift
//  myBrain by neocore
//
//  Created by Mojtaba Rabiei on 2025-03-28.
//


import SwiftUI // Add this import at the top of DeviceDetailsView.swift (already present, ensuring it's here)

struct DeviceDetailsView: View {
    @ObservedObject var bluetoothService: BluetoothService
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    // Add this state variable in DeviceDetailsView struct
    @State private var showTestSignalView = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                // Header with device image
                Image(colorScheme == .dark ? "headphone" : "headphone_b")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
                    .padding(.top, 30)
                
                if let device = bluetoothService.connectedDevice {
                    // Connected device details
                    Text(device.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 10)
                    
                    deviceStatusCard
                    
                    deviceControlsView
                } else {
                    // Not connected
                    noDeviceView
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Device")
        .navigationBarTitleDisplayMode(.inline)
        // Add this sheet presentation to the end of the body in DeviceDetailsView
        // Modify the sheet presentation in DeviceDetailsView.swift
        .sheet(isPresented: $showTestSignalView) {
            TestSignalView(bluetoothService: bluetoothService)
        }

    }
    
    private var deviceStatusCard: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Device Status")
                    .font(.headline)
                    .padding(.bottom, 5)
                Spacer()
            }
            
            // Battery status
            deviceInfoRow(
                icon: getBatteryIconName(),
                title: "Battery",
                value: "\(bluetoothService.batteryLevel ?? 0)%",
                iconColor: getBatteryColor()
            )
            
            // Serial number
            deviceInfoRow(
                icon: "number",
                title: "Serial Number",
                value: bluetoothService.serialNumber ?? "Unknown"
            )
            
            // Connection status
            deviceInfoRow(
                icon: "wifi",
                title: "Connection",
                value: "Connected",
                iconColor: .green
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func deviceInfoRow(icon: String, title: String, value: String, iconColor: Color = .blue) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 8)
    }
    
    private var deviceControlsView: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Device Controls")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 5)

            // Add this Button to deviceControlsView in DeviceDetailsView
            Button(action: {
                showTestSignalView = true
            }) {
                HStack {
                    Image(systemName: "waveform")
                    Text("Test Drive")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.vertical, 8) // Added padding as specified in the snippet

            // Existing Disconnect Button
            Button(action: {
                bluetoothService.disconnect()
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "link.badge.minus")
                    Text("Disconnect Device")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var noDeviceView: some View {
        VStack(spacing: 20) {
            Text("No Device Connected")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding(.top, 30)
            
            Image(systemName: "wifi.slash")
                .resizable()
                .scaledToFit()
                .foregroundColor(.secondary)
                .frame(width: 60, height: 60)
                .padding()
            
            Button(action: {
                bluetoothService.startScanning()
            }) {
                Text("Find Device")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
    
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
