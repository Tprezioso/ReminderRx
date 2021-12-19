//
//  AddButtonView.swift.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 12/18/21.
//

import SwiftUI

struct AddButtonView: View {
    var body: some View {
        ZStack {
            Circle()
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
            Image(systemName: "plus.circle.fill")
                .resizable()
                .frame(width: 75, height: 75)
                .foregroundColor(.blue)
                .padding()
        }
    }
}

struct AddButtonView_swift_Previews: PreviewProvider {
    static var previews: some View {
        AddButtonView()
    }
}
