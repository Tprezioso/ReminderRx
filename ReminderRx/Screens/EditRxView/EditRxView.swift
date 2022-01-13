//
//  EditRxView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 12/30/21.
//

import SwiftUI

struct EditRxView: View {
    @Binding var isShowingDetail: Bool
    @ObservedObject var prescription: Prescriptions
    @Environment(\.managedObjectContext) var moc
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    List {
                        Section(header: Text("Edit")) {
                            TextField("Rx Name", text: Binding($prescription.name, ""))
                            TextField("Number of Pills", text: Binding($prescription.count, ""))
                                .keyboardType(.numberPad)
                            TextField("Refills", text: Binding($prescription.refills, ""))
                                .keyboardType(.numberPad)
                            Toggle("Marked as Checked", isOn: $prescription.isOn)
                        }.navigationTitle("Edit Prescription")
                    }.listStyle(PlainListStyle())
                    Spacer()
                    Button {
                        isShowingDetail = false
                        try? moc.save()
                    } label: {
                        SaveButtonView()
                    }
                }
            }
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isShowingDetail = false
                    } label: {
                        XDismissButton()
                    }
                }
                Spacer()
            }
        }
    }
}

struct EditRxView_Previews: PreviewProvider {
    static var previews: some View {
        EditRxView(isShowingDetail: .constant(true), prescription: Prescriptions())
    }
}

extension Binding {
    init(_ source: Binding<Value?>, _ defaultValue: Value) {
        // Ensure a non-nil value in `source`.
        if source.wrappedValue == nil {
            source.wrappedValue = defaultValue
        }
        // Unsafe unwrap because *we* know it's non-nil now.
        self.init(source)!
    }
}
