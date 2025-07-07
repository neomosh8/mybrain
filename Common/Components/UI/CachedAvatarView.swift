import SwiftUI

struct CachedAvatarView: View {
    let avatarUrl: String?
    let size: CGFloat
    let initials: String
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.8),
                            Color.purple.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: avatarUrl) {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let avatarUrl = avatarUrl, !avatarUrl.isEmpty else {
            image = nil
            return
        }
        
        let secureUrl = avatarUrl.hasPrefix("http://") ?
            avatarUrl.replacingOccurrences(of: "http://", with: "https://") : avatarUrl
        
        if let cachedImage = AvatarImageCache.shared.getImage(for: secureUrl) {
            image = cachedImage
            return
        }
        
        isLoading = true
        AvatarImageCache.shared.downloadAndCacheImage(from: secureUrl) { downloadedImage in
            self.image = downloadedImage
            self.isLoading = false
        }
    }
}
