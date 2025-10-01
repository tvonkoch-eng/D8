//
//  D8App.swift
//  D8
//
//  Created by Tobias  Vonkoch  on 9/2/25.
//

import SwiftUI
import Firebase

@main
struct D8App: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
