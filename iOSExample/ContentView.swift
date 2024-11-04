//
//  ContentView.swift
//  iOSExample
//
//  Created by Andre Herculano on 15.02.24.
//

import SwiftUI

struct ContentView: View {
    var networkRequest, acceptAll, acceptSome, rejectAll, resetStatus: () -> Void
    var currentStatus: String

    init(
        networkRequest: @escaping () -> Void,
        acceptAll: @escaping () -> Void,
        acceptSome: @escaping () -> Void,
        rejectAll: @escaping () -> Void,
        resetStatus: @escaping () -> Void,
        currentStatus: String
    ) {
        self.networkRequest = networkRequest
        self.acceptAll = acceptAll
        self.acceptSome = acceptSome
        self.rejectAll = rejectAll
        self.resetStatus = resetStatus
        self.currentStatus = currentStatus
    }

    var body: some View {
        VStack {
            Button("Request using URLSession", networkRequest)
            Button("Accept All", acceptAll)
            Button("Accept Some", acceptSome)
            Button("Reject All", rejectAll)
            Button("Reset Status", resetStatus)
            Text("Current Status: \(currentStatus)")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    struct ContentViewPreview: View {
        @State var status = "noAction"
        var body: some View {
            ContentView(
                networkRequest: { print("network request") },
                acceptAll: { status = "acceptedAll" },
                acceptSome: { status = "acceptedSome" },
                rejectAll: { status = "rejectedAll" },
                resetStatus: { status = "noAction" },
                currentStatus: status
            )
        }
    }
    return ContentViewPreview()
}

struct Button: View {
    let title: String
    let action: () -> Void

    init(_ title: String, _ action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        SwiftUI.Button(action: action) {
            Text(title)
        }.padding()
    }
}
