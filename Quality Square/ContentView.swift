//
//  ContentView.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            if authManager.isAuthenticated {
                // Show appropriate dashboard based on role
                if authManager.userRole == .admin {
                    AdminDashboard()
                } else {
                    EmployeeTabView()
                }
            } else {
                // Login Screen
                LoginView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
