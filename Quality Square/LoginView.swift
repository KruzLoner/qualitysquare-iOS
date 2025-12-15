//
//  LoginView.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = 1  // Default to Employee
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 60)

                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.primary.opacity(0.8))

                        Text("Quality Square")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 40)

                    // Tab Selector
                    HStack(spacing: 0) {
                        TabButton(
                            title: "Employee",
                            icon: "person.fill",
                            isSelected: selectedTab == 1
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = 1
                            }
                        }

                        TabButton(
                            title: "Admin",
                            icon: "lock.fill",
                            isSelected: selectedTab == 0
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = 0
                            }
                        }
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)

                    // Content Area
                    TabView(selection: $selectedTab) {
                        EmployeeLoginView()
                            .tag(1)

                        AdminLoginView()
                            .tag(0)
                    }
                    .frame(height: 350)
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    Spacer()
                        .frame(height: 60)
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.keyboard)
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.primary.opacity(0.1) : Color.clear)
            )
            .foregroundColor(isSelected ? .primary : .primary.opacity(0.5))
        }
    }
}

struct AdminLoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    // Email Field
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )

                    // Password Field
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            loginAdmin()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, 24)

                // Error Message
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                // Sign In Button
                Button(action: loginAdmin) {
                    HStack(spacing: 8) {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isFormValid ? Color.blue : Color.secondary.opacity(0.3))
                    )
                    .foregroundColor(.white)
                }
                .disabled(!isFormValid || authManager.isLoading)
                .padding(.horizontal, 24)
            }
            .padding(.top, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func loginAdmin() {
        focusedField = nil
        authManager.loginAdmin(email: email, password: password)
    }
}

struct EmployeeLoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var pin = ""
    @FocusState private var isPinFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // PIN Input Field
                TextField("Enter PIN (4-6 digits)", text: $pin)
                    .keyboardType(.numberPad)
                    .focused($isPinFocused)
                    .submitLabel(.go)
                    .onChange(of: pin) { oldValue, newValue in
                        // Limit to 6 digits
                        if newValue.count > 6 {
                            pin = String(newValue.prefix(6))
                        }

                        // Auto-login when 4 or 6 digits entered
                        if newValue.count == 4 || newValue.count == 6 {
                            loginEmployee()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                // Error Message
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                // Sign In Button
                Button(action: loginEmployee) {
                    HStack(spacing: 8) {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isFormValid ? Color.blue : Color.secondary.opacity(0.3))
                    )
                    .foregroundColor(.white)
                }
                .disabled(!isFormValid || authManager.isLoading)
                .padding(.horizontal, 24)
            }
            .padding(.top, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            isPinFocused = true
        }
    }

    private var isFormValid: Bool {
        pin.count >= 4 && pin.count <= 6
    }

    private func loginEmployee() {
        guard isFormValid else { return }
        isPinFocused = false

        // Small delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            authManager.loginEmployee(pin: pin)

            // Clear PIN after attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !authManager.isAuthenticated {
                    pin = ""
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
