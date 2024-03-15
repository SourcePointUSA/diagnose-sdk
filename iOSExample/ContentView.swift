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
    var body: some View {
        VStack {
            Button(action: {
                sendRequestTo("https://sourcepoint.com")
            }, label: {
                Text("Request using URLSession")
            })
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
