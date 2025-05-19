import SwiftUI
import Combine

// MARK: - PerformanceView
struct PerformanceView: View {
    @ObservedObject var viewModel: PerformanceViewModel
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()
            
            ScrollView {
                VStack {
                    
                    HStack {
                        Text("Your Current Attention Capacity level: ")
                            .font(.headline) +
                        Text("\(viewModel.batteryLevel ?? -1)%")
                            .font(.headline)
                            .foregroundColor(
                                viewModel.batteryLevel ?? 0 > 70 ? .green :
                                    viewModel.batteryLevel ?? 0 >= 40 ? .yellow : .red
                            )
                    }
                    .padding(.bottom, 8)
                    .padding(.top, 45)
                    
                    // Description after current battery level + separator
                    Text("This is your current level of attention capacity, comparing to your best")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(width: 280)  // Adjust this width to match the width of the text above
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                    
                    Divider()
                        .padding(.bottom, 50)
                    
                    Text("Brain Dashboard")
                        .font(.largeTitle)
                        .padding(.bottom, 2)
                    
                    Text("Below is a representation your attention capacity for the first minute of typical listening.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .frame(width: 280)  // Adjust width as needed
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 42)
                    
                    
                    Text("Your Average Attention Capacity Per Minutes")
                        .font(.subheadline)
                        .padding(.bottom, 8)
                    
                    
                    
                    // The animated chart
                    AnimatedLineChartView()
                        .frame(height: 300)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    
                    // Legend
                    HStack(spacing: 20) {
                        HStack {
                            Circle().fill(Color.gray).frame(width: 10, height: 10)
                            Text("Your Usual Attention")
                        }
                        HStack {
                            Circle().fill(Color.blue).frame(width: 10, height: 10)
                            Text("Your Utilized Attention")
                        }
                    }
                    .font(.caption)
                    .padding(.bottom, 16)
                    
                    // TrendView and HistoryView
                    VStack(spacing: 16) {
                        TrendView()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 1)
                        
                        HistoryView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 400)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 1)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical)
            }
        }
        .onAppear(perform: loadData)
    }
    
    func loadData() {
        viewModel.fetchBatteryLevel()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Failed to fetch battery level: \(error)")
                }
            }, receiveValue: { level in
                viewModel.batteryLevel = level
            })
            .store(in: &viewModel.cancellables)
    }
}
