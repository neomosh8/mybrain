import Foundation
import Combine

class PerformanceViewModel: ObservableObject {
    @Published var batteryLevel: Int?
    var cancellables = Set<AnyCancellable>()

    func fetchBatteryLevel() -> AnyPublisher<Int, Error> {
        guard let url = URL(string: "https://httpbin.org/get") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: TestResponse.self, decoder: JSONDecoder())
            .map { response in
                Int.random(in: 0...100)
            }
            .receive(on: DispatchQueue.main) // <<<< Switch to main thread
            .eraseToAnyPublisher()
    }
}


struct TestResponse: Decodable {
    let args: [String: String]?
    let headers: [String: String]?
    let origin: String?
    let url: String?
}
