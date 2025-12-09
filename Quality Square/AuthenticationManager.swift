//
//  AuthenticationManager.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum UserRole {
    case admin
    case employee
}

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userRole: UserRole?
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    struct User {
        let id: String
        let email: String?
        let role: UserRole
        let name: String?
    }
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        if let firebaseUser = Auth.auth().currentUser {
            // Check if user is admin or employee
            fetchUserRole(userId: firebaseUser.uid)
        }
    }
    
    // MARK: - Admin Login (Email & Password)
    func loginAdmin(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let userId = result?.user.uid else {
                    self?.errorMessage = "Failed to get user ID"
                    return
                }
                
                // Verify user is admin
                self?.fetchUserRole(userId: userId)
            }
        }
    }
    
    // MARK: - Employee Login (PIN)
    func loginEmployee(pin: String) {
        isLoading = true
        errorMessage = nil

        // First, authenticate anonymously with Firebase to get proper permissions
        Auth.auth().signInAnonymously { [weak self] authResult, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                }
                return
            }

            // Now query Firestore for employee with matching PIN
            self.db.collection("employees")
                .whereField("pin", isEqualTo: pin)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        self.isLoading = false

                        if let error = error {
                            self.errorMessage = error.localizedDescription
                            // Sign out the anonymous user since PIN was invalid
                            try? Auth.auth().signOut()
                            return
                        }

                        guard let documents = snapshot?.documents, !documents.isEmpty else {
                            self.errorMessage = "Invalid PIN. Please try again."
                            // Sign out the anonymous user since PIN was invalid
                            try? Auth.auth().signOut()
                            return
                        }

                        // Get first matching employee
                        let employeeData = documents[0].data()
                        let employeeId = documents[0].documentID
                        let employeeName = employeeData["name"] as? String
                        let employeeStatus = employeeData["status"] as? String

                        // Check if employee is active
                        if employeeStatus?.lowercased() != "active" {
                            self.errorMessage = "Your account is currently inactive. Please contact an administrator."
                            // Sign out the anonymous user since account is inactive
                            try? Auth.auth().signOut()
                            return
                        }

                        self.currentUser = User(
                            id: employeeId,
                            email: nil,
                            role: .employee,
                            name: employeeName
                        )
                        self.userRole = .employee
                        self.isAuthenticated = true
                    }
                }
        }
    }
    
    // MARK: - Fetch User Role
    private func fetchUserRole(userId: String) {
        // Check if user is in admins collection
        db.collection("admins").document(userId).getDocument { [weak self] document, error in
            if let document = document, document.exists {
                let data = document.data()
                let email = data?["email"] as? String
                let name = data?["name"] as? String
                
                DispatchQueue.main.async {
                    self?.currentUser = User(
                        id: userId,
                        email: email,
                        role: .admin,
                        name: name
                    )
                    self?.userRole = .admin
                    self?.isAuthenticated = true
                }
            } else {
                DispatchQueue.main.async {
                    self?.errorMessage = "User not found in admin records"
                    try? Auth.auth().signOut()
                }
            }
        }
    }
    
    // MARK: - Logout
    func logout() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.userRole = nil
                self.currentUser = nil
                self.errorMessage = nil
            }
        } catch {
            errorMessage = "Failed to logout: \(error.localizedDescription)"
        }
    }
}

