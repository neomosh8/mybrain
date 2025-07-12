import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            // Your existing settings content
            ScrollView {
                VStack(spacing: 20) {
                    // Settings items
                    Text("Settings content here")

                    privacyTermsSection
                }
                .padding()
            }
        }
        .customNavigationBar(
            title: "Settings",
            onBackTap: {
                dismiss()  // This will navigate back to the previous view
            }
        ) {
            // Optional: Add a trailing button
            Button(action: {
                print("More options tapped")
            }) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Privacy and Terms Section
extension SettingsView {
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private var privacyTermsSection: some View {
        VStack(spacing: 12) {
            ActionRow(
                icon: "doc.text",
                title: "Terms of Service",
                subtitle: "Read our terms and conditions",
                iconColor: .blue
            ) {
                openURL("https://neocore.com/terms")
            }

            ActionRow(
                icon: "shield",
                title: "Privacy Policy",
                subtitle: "How we protect your data",
                iconColor: .green
            ) {
                openURL("https://neocore.com/privacy")
            }
        }
    }
}

#Preview {
    SettingsView()
}
