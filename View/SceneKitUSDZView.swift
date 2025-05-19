import SwiftUI
import SceneKit

struct SceneKitView: UIViewRepresentable {
    let localFileURL: URL

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        
        do {
            let scene = try SCNScene(url: localFileURL, options: nil)
            
            // Create and configure directional light for shadows
            let directionalLight = SCNNode()
            let light = SCNLight()
            light.type = .directional
            light.intensity = 3000
            light.temperature = 6500
            light.castsShadow = true
            light.shadowRadius = 5
            light.shadowColor = UIColor.black.withAlphaComponent(0.5)
            light.orthographicScale = 10
            directionalLight.light = light
            
            // Position the light for good coverage
            directionalLight.position = SCNVector3(x: 5, y: 10, z: 5)
            directionalLight.eulerAngles = SCNVector3(x: -Float.pi/4, y: Float.pi/4, z: 0)
            scene.rootNode.addChildNode(directionalLight)
            
            // Add ambient light for better overall illumination
            let ambientLight = SCNNode()
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 400
            ambient.temperature = 6500
            ambientLight.light = ambient
            scene.rootNode.addChildNode(ambientLight)
            
            // Configure shadow properties for the scene
            scene.lightingEnvironment.intensity = 1.0
            
            // Ensure all geometry in the scene can cast and receive shadows
            scene.rootNode.enumerateChildNodes { (node, _) in
                node.castsShadow = true
                if let geometry = node.geometry {
                    geometry.firstMaterial?.lightingModel = .physicallyBased
                }
            }
            
            scnView.scene = scene
        } catch {
            print("Failed to load scene from \(localFileURL). Error: \(error.localizedDescription)")
        }

        scnView.antialiasingMode = .multisampling4X
        scnView.rendersContinuously = true
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = .clear
        
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update logic if needed
    }
}
