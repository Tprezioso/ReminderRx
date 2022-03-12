//
//  Publisher+Validation.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 2/27/22.
//

import Foundation
import Combine

extension Published.Publisher where Value == String {
    func nonEmptyValidator(_ errorMessage: @autoclosure @escaping ValidationErrorClosure) -> ValidationPublisher {
        return ValidationPublishers.nonEmptyValidation(for: self, errorMessage: errorMessage())
    }
}
