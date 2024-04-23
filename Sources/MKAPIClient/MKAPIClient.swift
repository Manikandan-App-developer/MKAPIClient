// The Swift Programming Language
// https://docs.swift.org/swift-book

import Combine
import Foundation
import Network


protocol APIClient {}

public enum NetworkError: Error {
    case noInternet
    case invalidURL
    case encodingError
    case decodingError
    case invalidResponse
    case customError(error: Error)
}

public enum HttpMethod: String {
    case post = "POST"
    case get = "GET"
    case delete = "DELETE"
}

public class MKAPIClient: APIClient {
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    public init() {
        monitor.start(queue: queue)
    }
    
    @available(iOS 13.0, *)
    public func get<D: Decodable>(url: String) -> AnyPublisher<D, NetworkError> {
        guard let url = URL(string: url) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
            
        }
        var request = URLRequest(url: url)
        request.httpMethod = HttpMethod.get.rawValue
        return self.request(request: request)
            .eraseToAnyPublisher()
    }
    
    @available(iOS 13.0, *)
    public func post<D: Decodable, E: Encodable>(url: String, data: E) -> AnyPublisher<D, NetworkError> {
        
        guard let url = URL(string: url) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        guard let body = try? JSONEncoder().encode(data) else {
            return Fail(error: NetworkError.encodingError)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = HttpMethod.post.rawValue
        request.httpBody = body
        
        return self.request(request: request)
            .eraseToAnyPublisher()
    }
    
    @available(iOS 13.0, *)
    func request<D: Decodable>(request: URLRequest) -> AnyPublisher<D, NetworkError> {
        if !checkInternetConnection() {
            return Fail(error: NetworkError.noInternet)
                .eraseToAnyPublisher()
        }
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let respone = response as? HTTPURLResponse, respone.statusCode == 200  else {
                    print(response)
                    throw NetworkError.invalidResponse
                }
                return data
            }
            .decode(type: D.self, decoder: JSONDecoder())
            
            .mapError { error in
                if let error = error as? NetworkError {
                    return error
                } else {
                    return NetworkError.decodingError
                }
            }.eraseToAnyPublisher()
    }
    
    
    private func checkInternetConnection() -> Bool {
        return monitor.currentPath.status == .satisfied
    }
    
}
