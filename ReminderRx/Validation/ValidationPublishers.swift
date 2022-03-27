//
//  ValidationPublishers.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 2/27/22.
//

import Foundation
import Combine

typealias ValidationErrorClosure = () -> String
typealias ValidationPublisher = AnyPublisher<Validation, Never>

class ValidationPublishers {
    static func nonEmptyValidation(for publisher: Published<String>.Publisher,
                                   errorMessage: @autoclosure @escaping ValidationErrorClosure) -> ValidationPublisher {
        return publisher.map { value in
            guard value.count > 0 else {
                return .failure(message: errorMessage())
            }
            return .success
        }
        .dropFirst()
        .debounce(for: 1.0, scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}
