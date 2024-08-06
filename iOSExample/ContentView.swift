//
//  ContentView.swift
//  iOSExample
//
//  Created by Andre Herculano on 15.02.24.
//

import SwiftUI

func sendRequestTo(_ url: String) {
    guard let url = URL(string: url) else { return }
    URLSession(configuration: .default)
        .dataTask(with: URLRequest(url: url))
        .resume()
}

struct ContentView: View {
    var acceptAll: () -> Void
    var rejectAll: () -> Void

    init(
        acceptAll: @escaping () -> Void,
        rejectAll: @escaping () -> Void
    ) {
        self.acceptAll = acceptAll
        self.rejectAll = rejectAll
    }

    var body: some View {
        VStack {
            Button(action: {
                sendRequestTo("https://sourcepoint.com")
            }, label: {
                Text("Request using URLSession")
            }).padding()
            Button(action: acceptAll, label: {
                Text("Accept All")
            }).padding()
            Button(action: rejectAll, label: {
                Text("Reject All")
            }).padding()
        }
        .padding()
    }
}

#Preview {
    ContentView {} rejectAll: {}
}
