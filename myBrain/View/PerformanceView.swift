import SwiftUI

struct PerformanceView: View {
    @ObservedObject var viewModel: PerformanceViewModel

    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()
            
            VStack {
                Text("Performance")
                    .font(.largeTitle)
                    .padding(.bottom, 32)
                
                Text("Battery Level: \(viewModel.batteryLevel ?? -1 )")
                    .font(.title)
                    .padding(.bottom, 32)
                
                // Placeholder image
                Image(systemName: "chart.bar.fill")
                  .font(.system(size: 100))
                .padding(32)
                
               Spacer()
            }
        }
        .onAppear(perform: loadData)
    }
    
    func loadData(){
        viewModel.fetchBatteryLevel()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Failed to fetch battery level: \(error)")
                }
            }, receiveValue: { level in
                viewModel.batteryLevel = level
            })
            .store(in: &viewModel.cancellables)
    }
}
