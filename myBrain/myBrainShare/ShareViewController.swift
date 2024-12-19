import UIKit
import Social

class ShareViewController: SLComposeServiceViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Attempt to get the shared URL
        if let items = self.extensionContext?.inputItems as? [NSExtensionItem] {
            for item in items {
                if let attachments = item.attachments {
                    for provider in attachments {
                        if provider.hasItemConformingToTypeIdentifier("public.url") {
                            provider.loadItem(forTypeIdentifier: "public.url", options: nil) { (urlItem, error) in
                                if let url = urlItem as? URL {
                                    self.createThought(with: url)
                                } else {
                                    // If we can't get a URL, just complete
                                    self.completeRequest()
                                }
                            }
                            return
                        }
                    }
                }
            }
        }
    }

    func createThought(with url: URL) {
        guard let token = loadTokenFromAppGroup() else {
            print("No token found, user may not be logged in.")
            completeRequest()
            return
        }

        let baseUrl = "https://brain.sorenapp.ir"
        guard let endpointURL = URL(string: "\(baseUrl)/api/v1/thoughts/create/") else {
            completeRequest()
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
                if let error = error {
                    print("Error creating thought:", error)
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Status Code:", httpResponse.statusCode)
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response:", responseString)
                    }
                }
                self.completeRequest()
            }
        }
        task.resume()
    }

    func loadTokenFromAppGroup() -> String? {
        let appGroupID = "group.tech.neocore.MyBrain" // same group ID as the main app
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        return defaults.string(forKey: "accessToken")
    }

    func completeRequest() {
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        // Called after the user taps Post but we handle immediately in viewDidLoad for URL loading
        completeRequest()
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}
