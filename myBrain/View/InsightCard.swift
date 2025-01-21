// InsightCard.swift

import SwiftUI

struct InsightCard: View {
    let title: String
    let description: String
    let iconName: String
    let iconColor: Color
    
    var body: some View {
        HStack {
            // Text Content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.leading)
            
            Spacer()
            
            // Icon on the Right
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(iconColor)
                .padding(.trailing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color(uiColor: .systemGray).opacity(0.1), radius: 5, x: 0, y: 5)
        )
        .frame(width: 300) // Adjust width as needed
    }
}
