import UIKit
import WebKit

class ShareViewController: UIViewController {
    private let webView = WKWebView()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var progressTimer: Timer?
    private var gifURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Attempt to present as a card with round corners
        modalPresentationStyle = .formSheet
        preferredContentSize = CGSize(width: 320, height: 400)
        
        // Rounded corners and custom background
        view.layer.cornerRadius = 20.0
        view.clipsToBounds = true
        view.backgroundColor = UIColor(red: 0.0235, green: 0.1137, blue: 0.1216, alpha: 1.0) // #061d1f
        
        setupUI()
        // Store the URL now, load in viewDidAppear so user sees background instantly
        gifURL = Bundle.main.url(forResource: "myAnimation", withExtension: "gif")

        // Start retrieving the URL to process after UI is set
        retrieveURLAndProcess()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Load the GIF after the view appears, so user sees the background and layout first
        if let gifURL = gifURL {
            webView.loadFileURL(gifURL, allowingReadAccessTo: gifURL)
        }
    }

    private func setupUI() {
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0.0
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            webView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            webView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            webView.widthAnchor.constraint(equalToConstant: 150),
            webView.heightAnchor.constraint(equalToConstant: 150),

            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressView.topAnchor.constraint(equalTo: webView.bottomAnchor, constant: 20)
        ])
    }

    private func retrieveURLAndProcess() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            dismissAfterDelay()
            return
        }
        
        for item in extensionItems {
            if let attachments = item.attachments {
                for provider in attachments {
                    if provider.hasItemConformingToTypeIdentifier("public.url") {
                        provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (urlItem, error) in
                            DispatchQueue.main.async {
                                guard let self = self else { return }
                                if let url = urlItem as? URL {
                                    self.startProgressAnimation()
                                    self.createThought(with: url)
                                } else {
                                    // If no URL, just finish
                                    self.dismissAfterDelay()
                                }
                            }
                        }
                        return
                    }
                }
            }
        }
        
        // If no URL found in any attachment
        dismissAfterDelay()
    }
    
    private func startProgressAnimation() {
        // Simulate progress increment until request completes
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            let newValue = self.progressView.progress + 0.02
            if newValue < 0.9 {
                self.progressView.setProgress(newValue, animated: true)
            }
        }
    }

    private func stopProgressAnimation() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func createThought(with url: URL) {
        guard let token = loadTokenFromAppGroup() else {
            print("No token found, user may not be logged in.")
            // Show briefly then dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.finishAndDismiss()
            }
            return
        }

        let baseUrl = "https://brain.sorenapp.ir"
        guard let endpointURL = URL(string: "\(baseUrl)/api/v1/thoughts/create/") else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.finishAndDismiss()
            }
            return
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "content_type": "url",
            "source": url.absoluteString
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.stopProgressAnimation()
                
                if let error = error {
                    print("Error creating thought:", error)
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Status Code:", httpResponse.statusCode)
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response:", responseString)
                    }
                }

                // Set progress to 100% to show completion
                self.progressView.setProgress(1.0, animated: true)
                
                // Wait a bit so user sees completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.finishAndDismiss()
                }
            }
        }
        task.resume()
    }

    func loadTokenFromAppGroup() -> String? {
        let appGroupID = "group.tech.neocore.MyBrain" // Update to your actual App Group
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        return defaults.string(forKey: "accessToken")
    }

    func dismissAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.finishAndDismiss()
        }
    }

    func finishAndDismiss() {
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
