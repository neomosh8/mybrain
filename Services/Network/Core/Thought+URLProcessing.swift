import Foundation

extension Thought {
    /// Process relative URLs to full URLs by adding base URL
    func withProcessedURLs() -> Thought {
        return Thought(
            id: self.id,
            name: self.name,
            description: self.description,
            contentType: self.contentType,
            cover: processURL(self.cover),
            model3d: processURL(self.model3d),
            status: self.status,
            progress: self.progress,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
    
    private func processURL(_ urlPath: String?) -> String? {
        guard let path = urlPath, !path.isEmpty else {
            return nil
        }
        
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return path
        }
        
        return NetworkConstants.baseURL + (path.hasPrefix("/") ? path : "/" + path)
    }
}

extension ThoughtCreationResponse {
    /// Process relative URLs to full URLs by adding base URL
    func withProcessedURLs() -> ThoughtCreationResponse {
        return ThoughtCreationResponse(
            id: self.id,
            name: self.name,
            cover: processURL(self.cover),
            model3d: processURL(self.model3d),
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            status: self.status
        )
    }
    
    private func processURL(_ urlPath: String?) -> String? {
        guard let path = urlPath, !path.isEmpty else {
            return nil
        }
        
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return path
        }
        
        return NetworkConstants.baseURL + (path.hasPrefix("/") ? path : "/" + path)
    }
}
