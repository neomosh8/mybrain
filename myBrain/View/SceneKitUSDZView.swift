import SwiftUI
import SceneKit

struct SceneKitView: UIViewRepresentable {
    /// The local file URL of your downloaded .usdz file
    let localFileURL: URL

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        
        // Attempt to create a SceneKit scene from the local file URL
        do {
            let scene = try SCNScene(url: localFileURL, options: nil)
            scnView.scene = scene
        } catch {
            // Handle any errors in loading the file
            print("Failed to load scene from \(localFileURL). Error: \(error.localizedDescription)")
        }

        // Optional user interactions
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true

        // Customize the background as needed
        scnView.backgroundColor = .clear

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update logic if needed
    }
}
