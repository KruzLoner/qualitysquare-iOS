//
//  AdminDashboard.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import SwiftUI

struct AdminDashboard: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var firestoreManager = FirestoreManager()
    
    @State private var clockRecords: [ClockRecord] = []
    @State private var todayJobs: [Job] = []
    @State private var allEmployees: [Employee] = []
    @State private var teams: [Team] = []
    @State private var isLoading = false
    @State private var showingLogoutConfirm = false
    @State private var selectedTab = 0
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with Logout
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Admin Dashboard")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Manage your team and jobs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { showingLogoutConfirm = true }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Tab Picker
                    Picker("View", selection: $selectedTab) {
                        Text("Attendance").tag(0)
                        Text("Jobs").tag(1)
                        Text("Teams").tag(2)
                        Text("Employees").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    // Error Banner
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.orange.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }

                    // Content
                    TabView(selection: $selectedTab) {
                        // Today's Attendance Tab
                        ScrollView {
                            VStack(spacing: 20) {
                                // Stats Cards
                                HStack(spacing: 12) {
                                    StatCard(
                                        title: "Currently Clocked In",
                                        value: "\(clockRecords.count)",
                                        icon: "person.2.fill",
                                        color: .green
                                    )

                                    StatCard(
                                        title: "Total Employees",
                                        value: "\(allEmployees.count)",
                                        icon: "person.3.fill",
                                        color: .blue
                                    )
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                                // Currently Clocked In Employees
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Currently Working")
                                        .font(.headline)
                                        .padding(.horizontal, 20)

                                    if clockRecords.isEmpty {
                                        EmptyStateView(
                                            icon: "person.2.slash",
                                            message: "No employees currently clocked in"
                                        )
                                    } else {
                                        ForEach(clockRecords) { record in
                                            ActiveClockRecordRow(record: record)
                                        }
                                    }
                                }

                                Spacer()
                                    .frame(height: 40)
                            }
                        }
                        .tag(0)
                        
                        // Jobs Tab
                        ScrollView {
                            VStack(spacing: 20) {
                                // Job Stats
                                HStack(spacing: 12) {
                                    StatCard(
                                        title: "Total Jobs",
                                        value: "\(todayJobs.count)",
                                        icon: "briefcase.fill",
                                        color: .blue
                                    )

                                    StatCard(
                                        title: "Completed",
                                        value: "\(todayJobs.filter { $0.status == .completed }.count)",
                                        icon: "checkmark.circle.fill",
                                        color: .green
                                    )
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                                // Jobs by Status
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Today's Jobs")
                                        .font(.headline)
                                        .padding(.horizontal, 20)

                                    if todayJobs.isEmpty {
                                        EmptyStateView(
                                            icon: "calendar.badge.clock",
                                            message: "No jobs scheduled for today"
                                        )
                                    } else {
                                        ForEach(JobStatus.allCases, id: \.self) { status in
                                            let filteredJobs = todayJobs.filter { $0.status == status }
                                            if !filteredJobs.isEmpty {
                                                VStack(alignment: .leading, spacing: 12) {
                                                    HStack {
                                                        JobStatusBadge(status: status)
                                                        Text("(\(filteredJobs.count))")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 20)

                                                    ForEach(filteredJobs) { job in
                                                        AdminJobRow(job: job)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Spacer()
                                    .frame(height: 40)
                            }
                        }
                        .tag(1)

                        // Teams Tab
                        ScrollView {
                            VStack(spacing: 20) {
                                // Team Stats
                                HStack(spacing: 12) {
                                    StatCard(
                                        title: "Total Teams",
                                        value: "\(teams.count)",
                                        icon: "person.3.fill",
                                        color: .purple
                                    )

                                    StatCard(
                                        title: "Total Members",
                                        value: "\(teams.reduce(0) { $0 + $1.members.count })",
                                        icon: "person.2.fill",
                                        color: .blue
                                    )
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                                // Teams List
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("All Teams")
                                        .font(.headline)
                                        .padding(.horizontal, 20)

                                    if teams.isEmpty {
                                        EmptyStateView(
                                            icon: "person.3",
                                            message: "No teams found"
                                        )
                                    } else {
                                        ForEach(teams) { team in
                                            TeamRow(team: team)
                                        }
                                    }
                                }

                                Spacer()
                                    .frame(height: 40)
                            }
                        }
                        .tag(2)

                        // Employees Tab
                        ScrollView {
                            VStack(spacing: 20) {
                                // Employee Stats
                                HStack(spacing: 12) {
                                    StatCard(
                                        title: "Total Employees",
                                        value: "\(allEmployees.count)",
                                        icon: "person.3.fill",
                                        color: .blue
                                    )

                                    StatCard(
                                        title: "Active",
                                        value: "\(allEmployees.filter { $0.isActive }.count)",
                                        icon: "checkmark.circle.fill",
                                        color: .green
                                    )
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                                // All Employees List
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("All Employees")
                                        .font(.headline)
                                        .padding(.horizontal, 20)

                                    if allEmployees.isEmpty {
                                        EmptyStateView(
                                            icon: "person.3",
                                            message: "No employees found"
                                        )
                                    } else {
                                        ForEach(allEmployees) { employee in
                                            EmployeeListRow(employee: employee)
                                        }
                                    }
                                }

                                Spacer()
                                    .frame(height: 40)
                            }
                        }
                        .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .refreshable {
                    await loadData()
                }
            }
            .navigationBarHidden(true)
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
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil  // Clear previous errors

        // Load clock records
        firestoreManager.getTodayClockedInEmployees { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    clockRecords = records
                    print("✅ [AdminDashboard] Loaded \(records.count) currently clocked-in employee(s)")
                case .failure(let error):
                    print("❌ [AdminDashboard] Error loading clock records: \(error.localizedDescription)")
                    errorMessage = "Failed to load clock records: \(error.localizedDescription)"
                }
            }
        }

        // Load today's jobs
        firestoreManager.getAllJobsForToday { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let jobs):
                    todayJobs = jobs
                    print("✅ [AdminDashboard] Loaded \(jobs.count) job(s)")
                case .failure(let error):
                    print("❌ [AdminDashboard] Error loading jobs: \(error.localizedDescription)")
                    errorMessage = "Failed to load jobs: \(error.localizedDescription)"
                }
            }
        }

        // Load all employees
        firestoreManager.getAllEmployees { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let employees):
                    allEmployees = employees
                    print("✅ [AdminDashboard] Loaded \(employees.count) employee(s)")

                    if employees.isEmpty {
                        errorMessage = "No active employees found. Check Firebase database."
                    }
                case .failure(let error):
                    print("❌ [AdminDashboard] Error loading employees: \(error.localizedDescription)")
                    errorMessage = "Failed to load employees: \(error.localizedDescription)"
                }
            }
        }

        // Load all teams
        firestoreManager.getAllTeams { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedTeams):
                    teams = fetchedTeams
                    print("✅ [AdminDashboard] Loaded \(fetchedTeams.count) team(s)")
                case .failure(let error):
                    print("❌ [AdminDashboard] Error loading teams: \(error.localizedDescription)")
                    errorMessage = "Failed to load teams: \(error.localizedDescription)"
                }
            }
        }
    }

    private func updateEmployeeStatuses() {
        employeeStatuses = allEmployees.map { employee in
            let clockRecord = clockRecords.first(where: { $0.employeeId == employee.id })
            return EmployeeStatus(
                id: employee.id ?? UUID().uuidString,
                employee: employee,
                clockRecord: clockRecord
            )
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color.opacity(0.7))
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Active Clock Record Row
struct ActiveClockRecordRow: View {
    let record: ClockRecord
    @State private var currentDuration: String = ""

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Employee info
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.employeeName)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Clocked in at \(formatTime(record.clockInTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Duration badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currentDuration)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)

                    Text("working")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .onAppear {
            updateDuration()
        }
        .onReceive(timer) { _ in
            updateDuration()
        }
    }

    private func updateDuration() {
        let duration = Date().timeIntervalSince(record.clockInTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            currentDuration = "\(hours)h \(minutes)m"
        } else {
            currentDuration = "\(minutes)m"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Employee Row
struct EmployeeRow: View {
    let employee: Employee
    let isClockedIn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.blue.opacity(0.7))

            VStack(alignment: .leading, spacing: 4) {
                Text(employee.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let email = employee.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Circle()
                .fill(isClockedIn ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 10, height: 10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Detailed Employee Status Row
struct DetailedEmployeeStatusRow: View {
    let status: EmployeeStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Name and Status Badge
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue.opacity(0.7))

                VStack(alignment: .leading, spacing: 2) {
                    Text(status.employee.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let email = status.employee.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                StatusBadge(text: status.status, color: getStatusColor())
            }

            // Time Information
            if status.clockRecord != nil {
                Divider()
                    .padding(.vertical, 4)

                VStack(spacing: 8) {
                    // Clock In Time
                    if let clockIn = status.clockInTime {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Clocked In:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(clockIn))
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }

                    // Clock Out Time
                    if let clockOut = status.clockOutTime {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Clocked Out:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(clockOut))
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }

                    // Hours Worked
                    if let hours = status.hoursWorked {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Hours Worked:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f hrs", hours))
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(getStatusColor().opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func getStatusColor() -> Color {
        switch status.statusColor {
        case "green": return .green
        case "orange": return .orange
        default: return .gray
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
        )
        .foregroundColor(color)
    }
}

// MARK: - Admin Job Row
struct AdminJobRow: View {
    let job: Job
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.clientName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(job.jobType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(job.scheduledTime)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(job.assignedEmployeeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if job.status == .rescheduled, let reschedule = job.rescheduleRequest {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Reschedule requested")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text(message)
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
    }
}

// MARK: - Team Row
struct TeamRow: View {
    let team: Team

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Team Header
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title3)
                    .foregroundColor(.purple.opacity(0.7))

                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Leader: \(team.leaderName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(team.members.count) members")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.purple.opacity(0.15))
                    )
                    .foregroundColor(.purple)
            }

            // Team Members
            if !team.members.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(team.members, id: \.employeeId) { member in
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.6))

                            Text(member.employeeName)
                                .font(.caption)
                                .fontWeight(.medium)

                            if let role = member.employeeRole {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Text(role)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Employee List Row
struct EmployeeListRow: View {
    let employee: Employee

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.blue.opacity(0.7))

            VStack(alignment: .leading, spacing: 4) {
                Text(employee.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let email = employee.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let pin = employee.pin {
                    Text("PIN: \(pin)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Status Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(employee.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(employee.status.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(employee.isActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
            )
            .foregroundColor(employee.isActive ? .green : .gray)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }
}

#Preview {
    AdminDashboard()
        .environmentObject(AuthenticationManager())
}

