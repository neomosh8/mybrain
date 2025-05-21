import SwiftUI
import Lottie

struct ShareExtensionProgressView: View {
    /// Called when the animation/progress is done
    var onDismiss: () -> Void
    
    @State private var progress: Double = 0.0
    @State private var isComplete: Bool = false
    @State private var progressBarHeight: CGFloat = 8
    @State private var showPercentage: Bool = true
    
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            LottieView(animationName: "loadingAnimation", loopMode: .loop, animationSpeed: 1.0)
                .frame(height: 259)
                .padding()
            
            ZStack {
                if progressBarHeight > 0 {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(width: 200, height: progressBarHeight)
                }
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                        .transition(.scale)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: progressBarHeight)
            .animation(.easeInOut(duration: 0.3), value: isComplete)
            
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            startProgressSimulation()
        }
    }
    
    // MARK: - Simulation
    private func startProgressSimulation() {
        // This timer just fakes increments until ~80%
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            guard !isComplete else { return }
            
            if progress < 0.8 {
                let increment = Double.random(in: 0.1...0.2)
                withAnimation {
                    progress = min(progress + increment, 0.8)
                }
            } else if progress < 1.0 {
                // Stop the timer, wait, then jump to 100% and show completion
                timer?.invalidate()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        progress = 1.0
                    }
                    completeProgress()
                }
            } else {
                completeProgress()
            }
        }
    }
    
    private func completeProgress() {
        guard !isComplete else { return }
        isComplete = true
        withAnimation(.easeInOut(duration: 0.3)) {
            progressBarHeight = 0
        }
        showPercentage = false
        
        timer?.invalidate()
        timer = nil
        
        // Call onDismiss() after a short delay, so user sees the checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onDismiss()
        }
    }
}
