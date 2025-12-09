//
//  Quality_SquareApp.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import SwiftUI
import FirebaseCore

@main
struct Quality_SquareApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}
