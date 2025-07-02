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
                }
                .padding()
            }
        }
        .customNavigationBar(
            title: "Settings",
            onBackTap: {
                dismiss() // This will navigate back to the previous view
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


#Preview {
    SettingsView()
}
