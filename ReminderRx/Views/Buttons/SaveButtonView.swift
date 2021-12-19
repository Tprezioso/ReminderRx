//
//  SaveButtonView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 12/18/21.
//

import SwiftUI

struct SaveButtonView: View {
    var body: some View {
        Text("Save")
            .font(.title3)
            .fontWeight(.semibold)
            .frame(width: 300, height: 50)
            .foregroundColor(.white)
            .background(Color.green)
            .cornerRadius(10)
            .padding(.bottom)
    }
}

struct SaveButtonView_Previews: PreviewProvider {
    static var previews: some View {
        SaveButtonView()
    }
}
