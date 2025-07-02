import SwiftUI

struct DeviceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            // Device content
            ScrollView {
                VStack(spacing: 20) {
                    // Device connection content
                    Text("Device settings here")
                }
                .padding()
            }
        }
        .customNavigationBar(
            title: "Device",
            onBackTap: {
                dismiss()
            }
        )
        // No trailing content needed for this view
    }
}


#Preview {
    DeviceView()
}
