//
//  EmptyStateView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 12/18/21.
//

import SwiftUI

struct EmptyStateView: View {
    let message: String
    var body: some View {
        ZStack {
            VStack {
                Text(message)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            }
        }
    }
}

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView(message: "Test")
    }
}
