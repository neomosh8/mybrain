//
//  OnboardingViewModel.swift
//  myBrain by neocore
//
//  Created by Mojtaba Rabiei on 2025-03-28.
//


import Foundation
import Combine

class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var onboardingState: OnboardingState = .welcome
    @Published var hasCompletedOnboarding = false
    @Published var isReconnecting = false
    
    // MARK: - Private Properties
    private var bluetoothService: BluetoothService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(bluetoothService: BluetoothService) {
        self.bluetoothService = bluetoothService
        
        // Monitor connection status
        bluetoothService.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                if isConnected {
                    self.onboardingState = .connected
                    self.isReconnecting = false
                    
                    // After a delay, complete onboarding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.hasCompletedOnboarding = true
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor permission status
        bluetoothService.$permissionStatus
            .sink { [weak self] status in
                if status == .poweredOff || status == .denied || status == .unsupported {
                    self?.onboardingState = .permissionIssue
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func nextStep() {
        switch onboardingState {
        case .welcome:
            onboardingState = .scanning
            bluetoothService.startScanning()
        case .scanning, .connecting, .connected, .permissionIssue:
            // These states are handled by the Bluetooth service events
            break
        }
    }
    
    func selectDevice(_ device: DiscoveredDevice) {
        onboardingState = .connecting
        bluetoothService.connect(to: device)
    }
    
    func skipOnboarding() {
        hasCompletedOnboarding = true
    }
    
    func checkForPreviousDevice() {
        isReconnecting = true
        // This will try to reconnect if a device was previously saved
        bluetoothService.reconnectToPreviousDevice()
        
        // Set a timeout for auto-reconnection
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if !(self?.bluetoothService.isConnected ?? false) {
                self?.isReconnecting = false
                self?.onboardingState = .welcome
            }
        }
    }
}

// MARK: - Onboarding States
enum OnboardingState {
    case welcome
    case scanning
    case connecting
    case connected
    case permissionIssue
}