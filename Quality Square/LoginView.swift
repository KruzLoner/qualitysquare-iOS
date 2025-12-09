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
        ZStack {
            // Subtle gradient background
            Color(.systemGray6)
                .ignoresSafeArea()
            
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
                
                // Glass Card Container
                VStack(spacing: 0) {
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
                    .padding(.top, 20)
                    
                    // Content Area
                    TabView(selection: $selectedTab) {
                        AdminLoginView()
                            .tag(0)
                        
                        EmployeeLoginView()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Admin Access")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Enter your credentials")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)
                .padding(.bottom, 8)
                
                VStack(spacing: 16) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            TextField("admin@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .password
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.thinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .email ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
                                )
                        )
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            SecureField("Enter password", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    loginAdmin()
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.thinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .password ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
                                )
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                // Error Message
                if let error = authManager.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.red.opacity(0.1))
                    )
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
                            .fill(isFormValid ? Color.primary.opacity(0.9) : Color.secondary.opacity(0.3))
                    )
                    .foregroundColor(.white)
                }
                .disabled(!isFormValid || authManager.isLoading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer()
                    .frame(height: 40)
            }
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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Employee Login")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Enter your PIN")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)
                .padding(.bottom, 8)
                
                // PIN Display
                VStack(spacing: 20) {
                    HStack(spacing: 10) {
                        ForEach(0..<6, id: \.self) { index in
                            PINDigitView(
                                digit: index < pin.count ? String(pin[pin.index(pin.startIndex, offsetBy: index)]) : nil,
                                isActive: index == pin.count
                            )
                        }
                    }
                    .padding(.vertical, 16)
                    
                    // Hidden TextField for PIN input
                    TextField("", text: $pin)
                        .keyboardType(.numberPad)
                        .focused($isPinFocused)
                        .opacity(0)
                        .frame(height: 0)
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
                }
                .padding(.horizontal, 24)
                .onTapGesture {
                    isPinFocused = true
                }
                
                // Error Message
                if let error = authManager.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.red.opacity(0.1))
                    )
                    .padding(.horizontal, 24)
                }
                
                // Number Pad
                VStack(spacing: 12) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 12) {
                            ForEach(1..<4) { col in
                                let number = row * 3 + col
                                NumberButton(number: "\(number)") {
                                    if pin.count < 6 {
                                        pin += "\(number)"
                                    }
                                }
                            }
                        }
                    }
                    
                    // Last row with 0 and delete
                    HStack(spacing: 12) {
                        Color.clear
                            .frame(width: 70, height: 70)
                        
                        NumberButton(number: "0") {
                            if pin.count < 6 {
                                pin += "0"
                            }
                        }
                        
                        Button(action: {
                            if !pin.isEmpty {
                                pin.removeLast()
                            }
                        }) {
                            Image(systemName: "delete.left.fill")
                                .font(.title3)
                                .fontWeight(.medium)
                                .frame(width: 70, height: 70)
                                .background(
                                    Circle()
                                        .fill(.thinMaterial)
                                )
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            isPinFocused = true
        }
    }
    
    private func loginEmployee() {
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

struct PINDigitView: View {
    let digit: String?
    let isActive: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
                .frame(width: 48, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.primary.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: isActive ? 2 : 1)
                )
            
            if let digit = digit {
                Text(digit)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            } else if isActive {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primary.opacity(0.6))
                    .frame(width: 2, height: 26)
            }
        }
    }
}

struct NumberButton: View {
    let number: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Text(number)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                )
                .foregroundColor(.primary)
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}

