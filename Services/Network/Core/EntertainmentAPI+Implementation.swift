import Foundation
import Combine

extension HTTPNetworkService: EntertainmentAPI {
    
    func getEntertainmentTypes() -> AnyPublisher<NetworkResult<[EntertainmentType]>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.entertainmentTypes,
            method: .GET
        )
        return request(endpoint, responseType: [EntertainmentType].self)
    }
    
    func getEntertainmentGenres() -> AnyPublisher<NetworkResult<[EntertainmentGenre]>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.entertainmentGenres,
            method: .GET
        )
        return request(endpoint, responseType: [EntertainmentGenre].self)
    }
    
    func getEntertainmentContexts() -> AnyPublisher<NetworkResult<[EntertainmentContext]>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.entertainmentContexts,
            method: .GET
        )
        return request(endpoint, responseType: [EntertainmentContext].self)
    }
    
    func getAllEntertainmentOptions() -> AnyPublisher<NetworkResult<EntertainmentOptions>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.entertainmentOptions,
            method: .GET
        )
        return request(endpoint, responseType: EntertainmentOptions.self)
    }
}
