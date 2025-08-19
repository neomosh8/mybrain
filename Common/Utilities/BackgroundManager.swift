import AVFoundation
import Foundation
import UIKit

class BackgroundManager: ObservableObject {
    static let shared = BackgroundManager()

    @Published var isInBackground = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    init() {
        setupNotifications()
        configureAudioSession()

        setupAudioInterruptionHandling()
        setupAudioRouteChangeListener()
    }

    private func setupNotifications() {
        // Register for app state change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(
                "Failed to set up audio session: \(error.localizedDescription)"
            )
        }
    }

    @objc private func appDidEnterBackground() {
        isInBackground = true
        registerBackgroundTask()
    }

    @objc private func appWillEnterForeground() {
        isInBackground = false
        endBackgroundTask()
    }

    private func registerBackgroundTask() {
        // End any existing task first
        endBackgroundTask()

        // Start a new background task
        backgroundTask = UIApplication.shared.beginBackgroundTask {
            [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // Call this when streaming audio starts
    func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                true,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            print(
                "Failed to activate audio session: \(error.localizedDescription)"
            )
        }
    }

    // Call this when audio streaming ends
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            print(
                "Failed to deactivate audio session: \(error.localizedDescription)"
            )
        }
    }

    // Handle audio interruptions (phone calls, etc.)
    @objc func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey]
                as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        // Post a notification that other components can observe
        switch type {
        case .began:
            // Audio session interrupted (e.g., phone call)
            NotificationCenter.default.post(
                name: Notification.Name("AudioInterruptionBegan"),
                object: nil
            )

        case .ended:
            // Interruption ended
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey]
                as? UInt
            {
                let options = AVAudioSession.InterruptionOptions(
                    rawValue: optionsValue
                )
                if options.contains(.shouldResume) {
                    // We should resume playback
                    NotificationCenter.default.post(
                        name: Notification.Name("AudioInterruptionEnded"),
                        object: nil,
                        userInfo: ["shouldResume": true]
                    )
                } else {
                    // We can resume but must do so manually
                    NotificationCenter.default.post(
                        name: Notification.Name("AudioInterruptionEnded"),
                        object: nil,
                        userInfo: ["shouldResume": false]
                    )
                }
            }

        @unknown default:
            break
        }
    }

    func setupAudioInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    // This method to handle audio route changes
    func setupAudioRouteChangeListener() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    // This method to handle route changes
    @objc func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey]
                as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return
        }

        // Handle route changes that need special attention
        switch reason {
        case .oldDeviceUnavailable:
            // This is triggered when headphones are unplugged
            NotificationCenter.default.post(
                name: Notification.Name("AudioRouteChanged"),
                object: nil,
                userInfo: ["reason": "deviceDisconnected"]
            )

        case .newDeviceAvailable:
            // This is triggered when headphones are connected
            NotificationCenter.default.post(
                name: Notification.Name("AudioRouteChanged"),
                object: nil,
                userInfo: ["reason": "deviceConnected"]
            )

        default:
            break
        }
    }
}
