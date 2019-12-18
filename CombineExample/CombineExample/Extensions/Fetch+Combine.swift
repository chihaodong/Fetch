//
//  Fetch+Combine.swift
//  CombineExample
//
//  Created by Matthias Buchetics on 18.12.19.
//  Copyright © 2019 allaboutapps GmbH. All rights reserved.
//

import Foundation
import Combine
import Fetch

// MARK: - FetchPublisher

class FetchPublisher<Output>: Publisher {

    internal typealias Failure = FetchError

    private class Subscription: Combine.Subscription {

        private let cancellable: Cancellable?

        init(subscriber: AnySubscriber<Output, FetchError>, callback: @escaping (AnySubscriber<Output, FetchError>) -> Cancellable?) {
            self.cancellable = callback(subscriber)
        }

        func request(_ demand: Subscribers.Demand) {
            // We don't care for the demand right now
        }

        func cancel() {
            cancellable?.cancel()
        }
    }

    private let callback: (AnySubscriber<Output, FetchError>) -> Cancellable?

    init(callback: @escaping (AnySubscriber<Output, FetchError>) -> Cancellable?) {
        self.callback = callback
    }

    internal func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = Subscription(subscriber: AnySubscriber(subscriber), callback: callback)
        subscriber.receive(subscription: subscription)
    }
}

extension RequestToken: Cancellable { }

// MARK: - Resource+Request

public extension Resource {
    
    func requestPublisher(callbackQueue: DispatchQueue = .main) -> AnyPublisher<NetworkResponse<T>, FetchError> {
        return FetchPublisher { (subscriber) in
            return self.request(queue: callbackQueue) { (result) in
                switch result {
                case let .success(response):
                    _ = subscriber.receive(response)
                    subscriber.receive(completion: .finished)
                case let .failure(error):
                    subscriber.receive(completion: .failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func requestModel(callbackQueue: DispatchQueue = .main) -> AnyPublisher<T, FetchError> {
        return requestPublisher(callbackQueue: callbackQueue)
            .map { $0.model }
            .eraseToAnyPublisher()
    }
}

// MARK: - Resource+Fetch
    
public extension Resource where T: Cacheable {
    
    func fetchPublisher(cachePolicy: CachePolicy? = nil, callbackQueue: DispatchQueue = .main) -> AnyPublisher<FetchResponse<T>, FetchError> {
        return FetchPublisher { (subscriber) in
            return self.fetch(cachePolicy: cachePolicy, queue: callbackQueue) { (result, isFinished) in
                switch result {
                case let .success(response):
                    _ = subscriber.receive(response)
                    if isFinished {
                        subscriber.receive(completion: .finished)
                    }
                case let .failure(error):
                    subscriber.receive(completion: .failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func fetchModel(callbackQueue: DispatchQueue = .main) -> AnyPublisher<T, FetchError> {
        return fetchPublisher(callbackQueue: callbackQueue)
            .map { $0.model }
            .eraseToAnyPublisher()
    }
}
