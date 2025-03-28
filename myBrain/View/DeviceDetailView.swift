//
//  DeviceDetailView.swift
//  myBrain by neocore
//
//  Created by Mojtaba Rabiei on 2025-03-27.
//


import SwiftUI

struct DeviceDetailView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Device image
                    Image(colorScheme == .dark ? "headphone" : "headphone_b")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 150)
                        .opacity(bleManager.isConnected ? 1.0 : 0.5)
                        .padding(.top, 20)
                    
                    if bleManager.isConnected {
                        connectedDeviceContent
                    } else {
                        disconnectedDeviceContent
                    }
                }
                .padding()
            }
            .navigationTitle("Headphones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bleManager.isConnected {
                        Button("Disconnect") {
                            bleManager.disconnect()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    // MARK: - Connected Device Content
    private var connectedDeviceContent: some View {
        VStack(spacing: 24) {
            // Status card
            statusCard
            
            // Device info card
            detailsCard
            
            // Battery card
            batteryCard
            
            // Refresh button
            Button(action: {
                bleManager.requestBatteryLevel()
                bleManager.requestSerialNumber()
                bleManager.requestFirmwareVersion()
            }) {
                Text("Refresh Device Info")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Disconnected Device Content
    private var disconnectedDeviceContent: some View {
        VStack(spacing: 20) {
            Text("Not Connected")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Your NeoBrain headphones are not connected")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                bleManager.startScanning()
            }) {
                Text("Scan for Devices")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding()
    }
    
    // MARK: - Status Card
    private var statusCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Connected")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Details")
                .font(.headline)
                .foregroundColor(.secondary)
            
            detailRow(title: "Name", value: bleManager.deviceName ?? "NeoBrain Headphones")
            
            if let serial = bleManager.serialNumber {
                detailRow(title: "Serial Number", value: serial)
            }
            
            if let firmware = bleManager.firmwareVersion {
                detailRow(title: "Firmware", value: firmware)
            }
            
            detailRow(title: "Model", value: "QCC5181")
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Battery Card
    private var batteryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Battery")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if let battery = bleManager.batteryLevel {
                    Text("\(battery)%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(batteryColor(for: battery))
                } else {
                    Text("Unknown")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let level = bleManager.batteryLevel {
                Image(systemName: batteryIcon(for: level))
                    .font(.largeTitle)
                    .foregroundColor(batteryColor(for: level))
            } else {
                Image(systemName: "battery.0")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Views
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Functions
    private func batteryColor(for level: Int) -> Color {
        if level > 70 {
            return .green
        } else if level > 30 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func batteryIcon(for level: Int) -> String {
        if level > 75 {
            return "battery.100"
        } else if level > 50 {
            return "battery.75"
        } else if level > 25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }
}