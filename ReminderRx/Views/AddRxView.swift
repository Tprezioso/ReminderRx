//
//  AddRxView.swift
//  ReminderRx
//
//  Created by Thomas Prezioso Jr on 11/20/21.
//

import SwiftUI

struct AddRxView: View {
    @State var name = ""
    @State var count = ""
    @State var refills = ""
    @Binding var isShowingDetail: Bool
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    List {
                        Section(header: Text("New Rx")) {
                            TextField("Rx Name", text: $name)
                            TextField("Number of Pills", text: $count)
                                .keyboardType(.numberPad)
                            TextField("Refills", text: $refills)
                                .keyboardType(.numberPad)
                        }.navigationTitle("Add Prescription")
                    }.listStyle(PlainListStyle())
                    Spacer()
                    Button {
                        print("Save pill")
                        isShowingDetail = false
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

struct AddRxView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AddRxView(isShowingDetail: .constant(true))
        }
    }
}

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
