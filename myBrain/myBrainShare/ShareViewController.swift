import UIKit
import SwiftUI
import Lottie

class ShareViewController: UIViewController {
    
    private var pdfOrUrlProcessed = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Attempt to present as a card with round corners
        modalPresentationStyle = .formSheet
        preferredContentSize = CGSize(width: 320, height: 400)
        
        // Rounded corners and custom background
        view.layer.cornerRadius = 20.0
        view.clipsToBounds = true
        view.backgroundColor = UIColor(red: 0.0235, green: 0.1137, blue: 0.1216, alpha: 1.0) // #061d1f
        
        // Embed our SwiftUI Lottie progress view
        let progressView = UIHostingController(
            rootView: ShareExtensionProgressView(onDismiss: { [weak self] in
                // Once the SwiftUI progress completes, dismiss the extension
                self?.finishAndDismiss()
            })
        )
        
        addChild(progressView)
        progressView.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView.view)
        
        NSLayoutConstraint.activate([
            progressView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.view.topAnchor.constraint(equalTo: view.topAnchor),
            progressView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        progressView.didMove(toParent: self)
        
        // Start retrieving the shared item
        retrieveURLAndProcess()
    }
    
    // The main logic for reading extension items
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
    
    // MARK: - Send URL (Raw JSON)
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
                if let error = error {
                    print("Error creating thought (URL):", error.localizedDescription)
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Status Code (URL):", httpResponse.statusCode)
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response (URL):", responseString)
                    }
                }
                // Let the SwiftUI progress handle itself; just wait a short bit then dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.finishAndDismiss()
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Send PDF (multipart/form-data)
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
                if let error = error {
                    print("Error creating thought (PDF):", error.localizedDescription)
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Status Code (PDF):", httpResponse.statusCode)
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response (PDF):", responseString)
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.finishAndDismiss()
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Helper methods
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
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
