import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat

    // Create the LottieAnimationView directly
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        // This is the updated class name in Lottie 4.0+
        let animationView = LottieAnimationView()
        
        // This is the updated function in Lottie 4.0+
        let animation = LottieAnimation.named(animationName)
        
        animationView.animation = animation
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.contentMode = .scaleAspectFit
        
        // Start playing
        animationView.play()
        
        // Add Lottie view to a UIKit container so SwiftUI can display it
        view.addSubview(animationView)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: view.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // If you need to update the animation based on new props, do so here.
    }
}
