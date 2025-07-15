import SwiftUI

struct AppNavigationBar<TrailingContent: View>: View {
    let title: String
    let subtitle: String?
    let onBackTap: () -> Void
    let trailingContent: () -> TrailingContent
    
    init(
        title: String,
        subtitle: String? = nil,
        onBackTap: @escaping () -> Void,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
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
            
            if let subtitle = subtitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
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
    func appNavigationBar<TrailingContent: View>(
        title: String,
        subtitle: String? = nil,
        onBackTap: @escaping () -> Void,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) -> some View {
        VStack(spacing: 0) {
            AppNavigationBar(
                title: title,
                subtitle: subtitle,
                onBackTap: onBackTap,
                trailingContent: trailingContent
            )
            
            self
        }
        .navigationBarHidden(true)
    }
    
    func appNavigationBar(
        title: String,
        subtitle: String? = nil,
        onBackTap: @escaping () -> Void
    ) -> some View {
        appNavigationBar(
            title: title,
            subtitle: subtitle,
            onBackTap: onBackTap
        ) {
            EmptyView()
        }
    }
}
