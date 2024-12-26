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

        // Start retrieving the shared item after UI is set
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
            print("No extension items found.")
            dismissAfterDelay()
            return
        }
        
        // Check attachments for PDF or URL
        for (itemIndex, item) in extensionItems.enumerated() {
            print("Processing NSExtensionItem at index \(itemIndex)")
            if let attachments = item.attachments {
                
                // 1) Check if there's a PDF
                if let provider = attachments.first(where: {
                    $0.hasItemConformingToTypeIdentifier("com.adobe.pdf") ||
                    $0.hasItemConformingToTypeIdentifier("public.pdf")
                }) {
                    print("Found a provider that might contain a PDF.")
                    provider.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { [weak self] (pdfItem, error) in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            if let pdfURL = pdfItem as? URL {
                                print("PDF URL received: \(pdfURL)")
                                self.startProgressAnimation()
                                self.createThoughtPDF(with: pdfURL)
                            } else {
                                print("Could not load PDF item or item is not a URL.")
                                self.dismissAfterDelay()
                            }
                        }
                    }
                    return
                }
                
                // 2) Check if there's a URL
                if let provider = attachments.first(where: {
                    $0.hasItemConformingToTypeIdentifier("public.url")
                }) {
                    print("Found a provider that might contain a URL.")
                    provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (urlItem, error) in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            if let url = urlItem as? URL {
                                print("URL received: \(url.absoluteString)")
                                self.startProgressAnimation()
                                self.createThought(with: url)
                            } else {
                                print("Could not load URL item or item is not a URL.")
                                self.dismissAfterDelay()
                            }
                        }
                    }
                    return
                }
            } else {
                print("No attachments in this NSExtensionItem.")
            }
        }
        
        // If neither PDF nor URL found in any attachment
        print("No PDF or URL found in extension items.")
        dismissAfterDelay()
    }
    
    private func startProgressAnimation() {
        // Simulate progress increment until request completes
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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

    // MARK: - Send URL (Raw JSON) => Original createThought(with:)
    func createThought(with url: URL) {
        guard let token = loadTokenFromAppGroup() else {
            print("No token found, user may not be logged in.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.finishAndDismiss()
            }
            return
        }

        let baseUrl = "https://brain.sorenapp.ir"
        guard let endpointURL = URL(string: "\(baseUrl)/api/v1/thoughts/create/") else {
            print("Invalid endpoint URL for createThought(with:).")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.finishAndDismiss()
            }
            return
        }
        
        print("Sending URL to server: \(url.absoluteString)")

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        // For URL or text, we send raw JSON
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
                    print("Error creating thought (URL):", error.localizedDescription)
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Status Code (URL):", httpResponse.statusCode)
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response (URL):", responseString)
                    }
                }

                // Set progress to 100% to show completion
                self.progressView.setProgress(1.0, animated: true)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.finishAndDismiss()
                }
            }
        }
        task.resume()
    }

    // MARK: - Send PDF (multipart/form-data) => New createThoughtPDF(with:)
    func createThoughtPDF(with fileURL: URL) {
        guard let token = loadTokenFromAppGroup() else {
            print("No token found, user may not be logged in.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.finishAndDismiss()
            }
            return
        }

        let baseUrl = "https://brain.sorenapp.ir"
        guard let endpointURL = URL(string: "\(baseUrl)/api/v1/thoughts/create/") else {
            print("Invalid endpoint URL for createThoughtPDF.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.finishAndDismiss()
            }
            return
        }
        
        print("Preparing to send PDF to server from local URL: \(fileURL)")

        // Attempt to access security-scoped resource (if applicable)
        var pdfData: Data?
        let accessed = fileURL.startAccessingSecurityScopedResource()
        if accessed {
            defer { fileURL.stopAccessingSecurityScopedResource() }
            
            do {
                pdfData = try Data(contentsOf: fileURL)
            } catch {
                print("ERROR reading PDF data from fileURL: \(error.localizedDescription)")
            }
        } else {
            print("Could not start accessing security-scoped resource for: \(fileURL)")
        }
        
        guard let fileData = pdfData, fileData.count > 0 else {
            print("Failed to read valid PDF data. Size: \(pdfData?.count ?? 0) bytes")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.finishAndDismiss()
            }
            return
        }

        print("Successfully read PDF data. Size: \(fileData.count) bytes")

        // Build multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        // 1) content_type = pdf
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"content_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("pdf\r\n".data(using: .utf8)!)

        // 2) file = PDF data
        let fileName = fileURL.lastPathComponent.isEmpty ? "uploaded.pdf" : fileURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        print("Multipart body prepared. Total body size: \(body.count) bytes")

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.stopProgressAnimation()
                
                if let error = error {
                    print("Error creating thought (PDF):", error.localizedDescription)
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Status Code (PDF):", httpResponse.statusCode)
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response (PDF):", responseString)
                    }
                }
                
                self.progressView.setProgress(1.0, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.finishAndDismiss()
                }
            }
        }
        task.resume()
    }

    // MARK: - Helper methods
    func loadTokenFromAppGroup() -> String? {
        // EXACTLY as in your original code:
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
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
