//
//  EmployeeDashboard.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import SwiftUI

struct EmployeeDashboard: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var firestoreManager = FirestoreManager()
    
    @State private var clockRecord: ClockRecord?
    @State private var todayJobs: [Job] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingLogoutConfirm = false
    
    var isClockedIn: Bool {
        clockRecord?.isClocked ?? false
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Card
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome back,")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(authManager.currentUser?.name ?? "Employee")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                                
                                Spacer()
                                
                                Button(action: { showingLogoutConfirm = true }) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Clock Status
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(isClockedIn ? Color.green : Color.gray)
                                    .frame(width: 12, height: 12)
                                
                                Text(isClockedIn ? "Clocked In" : "Not Clocked In")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if let record = clockRecord, record.isClocked {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(formatTime(record.clockInTime))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Clock In/Out Button
                        Button(action: toggleClock) {
                            HStack {
                                Image(systemName: isClockedIn ? "clock.arrow.circlepath" : "clock.fill")
                                    .font(.title3)
                                
                                Text(isClockedIn ? "Clock Out" : "Clock In")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isClockedIn ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                            )
                            .foregroundColor(.white)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 20)
                        
                        // Error Message
                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error)
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.red.opacity(0.1))
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Today's Jobs Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Today's Jobs")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text("\(todayJobs.count)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            
                            if todayJobs.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    
                                    Text("No jobs scheduled for today")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                )
                                .padding(.horizontal, 20)
                            } else {
                                ForEach(todayJobs) { job in
                                    NavigationLink(destination: JobDetailView(job: job)) {
                                        JobRowView(job: job)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.top, 12)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
                .refreshable {
                    await loadData()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await loadData()
                }
            }
            .alert("Logout", isPresented: $showingLogoutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
    
    private func toggleClock() {
        guard let employeeId = authManager.currentUser?.id,
              let employeeName = authManager.currentUser?.name else { return }
        
        isLoading = true
        errorMessage = nil
        
        if isClockedIn {
            // Clock Out
            firestoreManager.clockOut(employeeId: employeeId) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success:
                        Task { await loadData() }
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            // Clock In
            firestoreManager.clockIn(employeeId: employeeId, employeeName: employeeName) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let record):
                        clockRecord = record
                        Task { await loadData() }
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func loadData() async {
        guard let employeeId = authManager.currentUser?.id else { return }
        
        // Load clock status
        firestoreManager.getTodayClockStatus(employeeId: employeeId) { result in
            DispatchQueue.main.async {
                if case .success(let record) = result {
                    clockRecord = record
                }
            }
        }
        
        // Load today's jobs
        firestoreManager.getEmployeeJobsForToday(employeeId: employeeId) { result in
            DispatchQueue.main.async {
                if case .success(let jobs) = result {
                    todayJobs = jobs
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Job Row View
struct JobRowView: View {
    let job: Job
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.clientName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.caption)
                        Text(job.jobType.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                JobStatusBadge(status: job.status)
            }
            
            HStack(spacing: 16) {
                Label(job.scheduledTime, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label(job.clientAddress, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            if let notes = job.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Job Status Badge
struct JobStatusBadge: View {
    let status: JobStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.15))
            )
            .foregroundColor(statusColor)
    }
    
    private var statusColor: Color {
        switch status {
        case .scheduled: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .rescheduled: return .purple
        case .cancelled: return .red
        }
    }
}

#Preview {
    EmployeeDashboard()
        .environmentObject(AuthenticationManager())
}

