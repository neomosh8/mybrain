import Foundation
import UIKit

class AvatarImageCache {
    static let shared = AvatarImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("AvatarCache")
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        cache.countLimit = 10
        cache.totalCostLimit = 50 * 1024 * 1024
    }
    
    // MARK: - Public Methods
    
    func getImage(for urlString: String) -> UIImage? {
        let key = NSString(string: urlString)
        
        if let image = cache.object(forKey: key) {
            return image
        }
        
        if let image = loadImageFromDisk(urlString: urlString) {
            cache.setObject(image, forKey: key)
            return image
        }
        
        return nil
    }
    
    func setImage(_ image: UIImage, for urlString: String) {
        let key = NSString(string: urlString)
        
        cache.setObject(image, forKey: key)
        
        saveImageToDisk(image: image, urlString: urlString)
    }
    
    func downloadAndCacheImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        let secureUrlString = ensureHTTPS(urlString)
        
        guard let url = URL(string: secureUrlString) else {
            completion(nil)
            return
        }
        
        if let cachedImage = getImage(for: secureUrlString) {
            completion(cachedImage)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            
            self?.setImage(image, for: secureUrlString)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func updateAvatarCache(with newUrlString: String?) {
        cache.removeAllObjects()
        
        let cachedFiles = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        cachedFiles?.forEach { url in
            try? fileManager.removeItem(at: url)
        }
        
        if let newUrlString = newUrlString, !newUrlString.isEmpty {
            downloadAndCacheImage(from: newUrlString) { _ in
                // Image is now cached for future use
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func ensureHTTPS(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") {
            return urlString.replacingOccurrences(of: "http://", with: "https://")
        }
        return urlString
    }
    
    private func loadImageFromDisk(urlString: String) -> UIImage? {
        let fileName = hashString(urlString)
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    private func saveImageToDisk(image: UIImage, urlString: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileName = hashString(urlString)
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        try? data.write(to: fileURL)
    }
    
    private func hashString(_ string: String) -> String {
        return "\(string.hashValue)"
    }
}
