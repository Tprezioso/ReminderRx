//
//  Validation.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 2/27/22.
//

import Foundation

enum Validation {
    case success
    case failure(message: String)
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}
