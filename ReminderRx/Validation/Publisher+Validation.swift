//
//  Publisher+Validation.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 2/27/22.
//

import Foundation
import Combine
//import Regex

extension Published.Publisher where Value == String {
    
    func nonEmptyValidator(_ errorMessage: @autoclosure @escaping ValidationErrorClosure) -> ValidationPublisher {
        return ValidationPublishers.nonEmptyValidation(for: self, errorMessage: errorMessage())
    }
    
//    func matcherValidation(_ pattern: String, _ errorMessage: @autoclosure @escaping ValidationErrorClosure) -> ValidationPublisher {
//        return ValidationPublishers.matcherValidation(for: self, withPattern: pattern.r!, errorMessage: errorMessage())
//    }
    
}

//extension Published.Publisher where Value == Date {
//     func dateValidation(afterDate after: Date = .distantPast,
//                         beforeDate before: Date = .distantFuture,
//                         errorMessage: @autoclosure @escaping ValidationErrorClosure) -> ValidationPublisher {
//        return ValidationPublishers.dateValidation(for: self, afterDate: after, beforeDate: before, errorMessage: errorMessage())
//    }
//}
