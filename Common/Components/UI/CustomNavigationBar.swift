import SwiftUI

struct CustomNavigationBar<TrailingContent: View>: View {
    let title: String
    let onBackTap: () -> Void
    let trailingContent: () -> TrailingContent
    
    init(
        title: String,
        onBackTap: @escaping () -> Void,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self.title = title
        self.onBackTap = onBackTap
        self.trailingContent = trailingContent
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBackTap) {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
            }
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            trailingContent()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }
}

// MARK: - View Extension for Easy Integration

extension View {
    func customNavigationBar<TrailingContent: View>(
        title: String,
        onBackTap: @escaping () -> Void,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) -> some View {
        VStack(spacing: 0) {
            CustomNavigationBar(
                title: title,
                onBackTap: onBackTap,
                trailingContent: trailingContent
            )
            
            self
        }
        .navigationBarHidden(true)
    }
    
    func customNavigationBar(
        title: String,
        onBackTap: @escaping () -> Void
    ) -> some View {
        customNavigationBar(title: title, onBackTap: onBackTap) {
            EmptyView()
        }
    }
}

