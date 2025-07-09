import SwiftUICore

struct InsightCardView: View {
    let insight: InsightItem

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(insight.iconColor.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: insight.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(insight.iconColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Text(insight.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(insight.iconColor)

                Text(insight.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .frame(width: 300)
    }
}
