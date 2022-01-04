//
//  EditRxView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 12/30/21.
//

import SwiftUI

struct EditRxView: View {
    @State var name = ""
    @State var count = ""
    @State var refills = ""
    @Binding var isShowingDetail: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Edit")) {
                        TextField("Rx Name", text: $name)
                        TextField("Number of Pills", text: $count)
                            .keyboardType(.numberPad)
                        TextField("Refills", text: $refills)
                            .keyboardType(.numberPad)
                    }.navigationTitle("Edit Prescription")
                }.listStyle(PlainListStyle())
                Spacer()
                Button {
                    isShowingDetail = false
                } label: {
                    SaveButtonView()
                }
            }
        }
    }
}

struct EditRxView_Previews: PreviewProvider {
    static var previews: some View {
        EditRxView(isShowingDetail: .constant(true))
    }
}
