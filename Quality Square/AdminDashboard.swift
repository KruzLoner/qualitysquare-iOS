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
    @State private var licensePlates: [LicensePlate] = []
    @State private var newPlateNum: String = ""
    @State private var vehicleFormError: String?
    @State private var vehicleSubmitting = false
    @State private var isLoading = false
    @State private var showingLogoutConfirm = false
    @State private var selectedTab = 0
    @State private var selectedJobFilter: JobStatus? = nil
    @State private var errorMessage: String?
    @State private var pendingReschedules: [Job] = []
    @State private var approvingJobIds: Set<String> = []

    private var inProgressCount: Int {
        todayJobs.filter { job in
            [.inProgress, .pickingUp, .pickUp, .enRoute].contains(job.status)
        }.count
    }

    private func approveReschedule(job: Job, newDate: Date?) {
        guard let jobId = job.id else { return }
        approvingJobIds.insert(jobId)
        firestoreManager.approveReschedule(jobId: jobId, newDate: newDate) { result in
            DispatchQueue.main.async {
                approvingJobIds.remove(jobId)
                switch result {
                case .success:
                    pendingReschedules.removeAll { $0.id == jobId }
                    // Refresh jobs to reflect new status/date
                    firestoreManager.getAllJobsForToday { jobsResult in
                        if case let .success(jobs) = jobsResult {
                            todayJobs = jobs
                        }
                    }
                case .failure(let error):
                    errorMessage = "Failed to approve: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private var activeJobs: [Job] {
        todayJobs.filter { [.inProgress, .pickingUp, .pickUp, .enRoute].contains($0.status) }
    }

    private var completedJobs: [Job] {
        todayJobs.filter { $0.status == .completed || $0.status == .complete }
    }

    private var rescheduledJobs: [Job] {
        todayJobs.filter { $0.status == .rescheduled }
    }

    private var cancelledJobs: [Job] {
        todayJobs.filter { $0.status == .cancelled }
    }

    private var filteredTodayJobs: [Job] {
        guard let filter = selectedJobFilter else { return todayJobs }
        switch filter {
        case .inProgress:
            return activeJobs
        case .rescheduled:
            return rescheduledJobs
        case .cancelled:
            return cancelledJobs
        case .completed, .complete:
            return completedJobs
        default:
            return todayJobs
        }
    }

    private var groupedJobs: [JobStatus: [Job]] {
        Dictionary(grouping: filteredTodayJobs.filter { $0.status != nil }, by: { $0.status! })
    }

    private var jobFilters: [JobStatus] {
        [.rescheduled, .cancelled, .completed]
    }


    private func statusSort(_ lhs: JobStatus, _ rhs: JobStatus) -> Bool {
        let order: [JobStatus] = [.pickingUp, .pickUp, .enRoute, .complete, .completed, .inProgress, .rescheduled, .cancelled]
        let l = order.firstIndex(of: lhs) ?? order.count
        let r = order.firstIndex(of: rhs) ?? order.count
        return l < r
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Compact glass header with logout
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Admin Dashboard")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Manage team & jobs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: { showingLogoutConfirm = true }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

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
                                // Combined Stats Card
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                            .foregroundColor(.green.opacity(0.7))
                                        Spacer()
                                    }

                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text("\(clockRecords.count)")
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.green)

                                        Text("/")
                                            .font(.title)
                                            .foregroundColor(.secondary)

                                        Text("\(allEmployees.count)")
                                            .font(.title)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }

                                    Text("Clocked In / Total Employees")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.ultraThinMaterial)
                                )
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
                        .tabItem {
                            Label("Attendance", systemImage: "clock.fill")
                        }
                        
                        // Jobs Tab
                        ScrollView {
                            VStack(spacing: 20) {
                                // Jobs by Status
                                VStack(alignment: .leading, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 12) {

                                        VStack(spacing: 12) {
                                            HStack(spacing: 12) {
                                                FilterChip(title: "All", count: todayJobs.count, isSelected: selectedJobFilter == nil) {
                                                    selectedJobFilter = nil
                                                }
                                                FilterChip(title: "Rescheduled", count: rescheduledJobs.count, isSelected: selectedJobFilter == .rescheduled) {
                                                    selectedJobFilter = .rescheduled
                                                }
                                            }

                                            HStack(spacing: 12) {
                                                FilterChip(title: "Cancelled", count: cancelledJobs.count, isSelected: selectedJobFilter == .cancelled) {
                                                    selectedJobFilter = .cancelled
                                                }
                                                FilterChip(title: "Completed", count: completedJobs.count, isSelected: selectedJobFilter == .completed || selectedJobFilter == .complete) {
                                                    selectedJobFilter = .completed
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }

                                        if filteredTodayJobs.isEmpty {
                                            EmptyStateView(
                                                icon: "calendar.badge.clock",
                                                message: "No jobs for today"
                                            )
                                        } else {
                                        ForEach(groupedJobs.keys.sorted(by: statusSort), id: \.self) { status in
                                            if let jobs = groupedJobs[status], !jobs.isEmpty {
                                                VStack(alignment: .leading, spacing: 12) {
                                                    HStack {
                                                        JobStatusBadge(status: status)
                                                        Text("(\(jobs.count))")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 20)

                                                    ForEach(jobs) { job in
                                                        NavigationLink {
                                                            JobDetailView(job: job)
                                                                .environmentObject(authManager)
                                                        } label: {
                                                            AdminJobRow(job: job)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Reschedule Requests
                                if !pendingReschedules.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "calendar.badge.exclamationmark")
                                                .foregroundColor(.purple)
                                            Text("Reschedule Requests")
                                                .font(.headline)
                                            Spacer()
                                            Text("\(pendingReschedules.count)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 20)

                                        ForEach(pendingReschedules) { job in
                                            RescheduleCard(
                                                job: job,
                                                isApproving: approvingJobIds.contains(job.id ?? ""),
                                                onApprove: { date in
                                                    approveReschedule(job: job, newDate: date)
                                                }
                                            )
                                        }
                                    }
                                }

                                Spacer()
                                    .frame(height: 40)
                            }
                        }
                        .tag(1)
                        .tabItem {
                            Label("Jobs", systemImage: "briefcase.fill")
                        }

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
                        .tabItem {
                            Label("Teams", systemImage: "person.3.sequence.fill")
                        }

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
                                        ForEach(Array(allEmployees.enumerated()), id: \.offset) { index, employee in
                                            EmployeeListRow(employee: employee)
                                        }
                                    }
                                }

                                Spacer()
                                    .frame(height: 40)
                            }
                        }
                        .tag(3)
                        .tabItem {
                            Label("Employees", systemImage: "person.text.rectangle.fill")
                        }

                        // Vehicles Tab
                        ScrollView {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Vehicles")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(licensePlates.count) total")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)

                                VStack(spacing: 12) {
                                    TextField("License plate number", text: $newPlateNum)
                                        .autocapitalization(.allCharacters)
                                        .textInputAutocapitalization(.characters)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.thinMaterial)
                                        )
                                        .padding(.horizontal, 20)

                                    if let vehicleFormError = vehicleFormError {
                                        Text(vehicleFormError)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 20)
                                    }

                                    Button(action: addVehicle) {
                                        HStack {
                                            if vehicleSubmitting {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            }
                                            Text("Add Vehicle")
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.blue.opacity(newPlateNum.isEmpty ? 0.3 : 0.9))
                                        )
                                        .foregroundColor(.white)
                                    }
                                    .disabled(newPlateNum.isEmpty || vehicleSubmitting)
                                    .padding(.horizontal, 20)
                                }
                                .padding(.vertical, 8)

                                if licensePlates.isEmpty {
                                    EmptyStateView(
                                        icon: "car",
                                        message: "No vehicles found"
                                    )
                                } else {
                                    ForEach(licensePlates, id: \.plateNum) { plate in
                                        VehicleCard(
                                            plate: plate,
                                            team: getTeam(for: plate)
                                        )
                                    }
                                }

                                Spacer()
                                    .frame(height: 40)
                            }
                        }
                        .tag(4)
                        .tabItem {
                            Label("Vehicles", systemImage: "car.fill")
                        }
                    }
                    .accentColor(.primary)
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
        approvingJobIds.removeAll()

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

        firestoreManager.getPendingRescheduleRequests { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let jobs):
                    pendingReschedules = jobs
                case .failure(let error):
                    print("❌ [AdminDashboard] Error loading reschedule requests: \(error.localizedDescription)")
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

        firestoreManager.getPendingRescheduleRequests { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let jobs):
                    pendingReschedules = jobs
                case .failure(let error):
                    print("❌ [AdminDashboard] Error loading reschedule requests: \(error.localizedDescription)")
                }
            }
        }

        // Load all employees
        firestoreManager.getAllEmployees { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let employees):
                    // Debug: Print all employee data
                    print("📋 [AdminDashboard] Raw employees data:")
                    for (index, emp) in employees.enumerated() {
                        print("  [\(index)] ID: \(emp.id ?? "nil"), Name: \(emp.name), PIN: \(emp.pin ?? "nil"), Role: \(emp.role ?? "nil")")
                    }

                    // Deduplicate employees by ID
                    let unique = Dictionary(grouping: employees, by: { $0.id ?? $0.name })
                        .compactMap { $0.value.first }
                        .sorted { $0.name < $1.name }
                    allEmployees = unique
                    print("✅ [AdminDashboard] Loaded \(unique.count) unique employee(s) from \(employees.count) total")

                    // Debug: Print unique employee data
                    print("📋 [AdminDashboard] Unique employees:")
                    for (index, emp) in unique.enumerated() {
                        print("  [\(index)] ID: \(emp.id ?? "nil"), Name: \(emp.name), PIN: \(emp.pin ?? "nil"), Role: \(emp.role ?? "nil")")
                    }

                    if unique.isEmpty {
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

        // Load vehicles
        firestoreManager.getLicensePlates { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let plates):
                    let unique = Dictionary(grouping: plates, by: { $0.id ?? $0.plateNum })
                        .compactMap { $0.value.first }
                        .sorted { $0.plateNum < $1.plateNum }
                    licensePlates = unique
                    print("✅ [AdminDashboard] Loaded \(plates.count) license plate(s)")
                case .failure(let error):
                    print("❌ [AdminDashboard] Error loading license plates: \(error.localizedDescription)")
                    vehicleFormError = "Failed to load vehicles"
                }
            }
        }
    }

    private func addVehicle() {
        let trimmed = newPlateNum.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            vehicleFormError = "Plate number is required"
            return
        }

        vehicleFormError = nil
        vehicleSubmitting = true

        firestoreManager.createLicensePlate(plateNum: trimmed.uppercased()) { result in
            DispatchQueue.main.async {
                vehicleSubmitting = false
                switch result {
                case .success:
                    newPlateNum = ""
                    Task { await loadData() }
                case .failure(let error):
                    vehicleFormError = error.localizedDescription
                }
            }
        }
    }

    private func getTeam(for plate: LicensePlate) -> Team? {
        guard let teamId = plate.currentTeamId else { return nil }
        return teams.first(where: { $0.id == teamId })
    }
}

// MARK: - Filter Chip
private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        GeometryReader { geometry in
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(geometry.size.width < 160 ? .caption : .subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 2)

                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.2))
                        )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color.blue.opacity(0.6) : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: isSelected ? Color.blue.opacity(0.2) : Color.black.opacity(0.03), radius: isSelected ? 8 : 4, x: 0, y: 2)
                )
                .foregroundColor(isSelected ? .blue : .primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: 48)
    }
}

// MARK: - Compact Job Stats
private struct CompactJobStats: View {
    let total: Int
    let active: Int
    let completed: Int
    let reschedules: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                statBlock(title: "Total", value: total, icon: "briefcase.fill", color: .blue)
                statBlock(title: "Active", value: active, icon: "clock.fill", color: .orange)
                statBlock(title: "Done", value: completed, icon: "checkmark.circle.fill", color: .green)
                statBlock(title: "Resched", value: reschedules, icon: "calendar.badge.clock", color: .purple)
            }
        }
    }

    private func statBlock(title: String, value: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Vehicle Card
private struct VehicleCard: View {
    let plate: LicensePlate
    let team: Team?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(plate.plateNum, systemImage: "car.fill")
                    .font(.headline)
                Spacer()
                if let assignedAt = plate.assignedAt {
                    Text(timeAgo(from: assignedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Display based on team assignment
            if let team = team {
                // Vehicle assigned to a team - show team leader and members
                VStack(alignment: .leading, spacing: 6) {
                    // Team Leader
                    Text("Team Leader: \(team.leaderName)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    // Team Members
                    if !team.members.isEmpty {
                        Divider()
                            .padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Team Members:")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            ForEach(team.members, id: \.employeeId) { member in
                                HStack(spacing: 6) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue.opacity(0.6))
                                    Text(member.employeeName)
                                        .font(.caption)
                                        .foregroundColor(.primary)

                                    if let role = member.employeeRole {
                                        Text("•")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(role)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else if let driver = plate.currentDriverName {
                // Vehicle assigned to individual employee (not in team)
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.blue.opacity(0.7))
                    Text(driver)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            } else {
                // Vehicle not assigned
                Text(plate.available ? "Available" : "Unavailable")
                    .font(.caption)
                    .foregroundColor(plate.available ? .green : .red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Reschedule Card
private struct RescheduleCard: View {
    let job: Job
    let isApproving: Bool
    let onApprove: (Date?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.clientName ?? "")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let newDate = job.rescheduleRequest?.newProposedDate {
                        Text("Proposed: \(formatDate(newDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let status = job.status {
                    JobStatusBadge(status: status)
                }
            }

            if let reason = job.rescheduleRequest?.reason, !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                if let proposed = job.rescheduleRequest?.newProposedDate {
                    Text("Proposed: \(formatDate(proposed))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    onApprove(job.rescheduleRequest?.newProposedDate)
                } label: {
                    if isApproving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    } else {
                        Label("Approve", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.15))
                )
                .disabled(isApproving)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(job.clientName ?? "Customer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let doli = job.doliNumber, !doli.isEmpty {
                        Text("DOLI: \(doli)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    if let status = job.status {
                        JobStatusBadge(status: status)
                    }
                }
            }

            if let teamName = job.assignedTeamName {
                Label("Team: \(teamName)", systemImage: "person.3.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let assigned = job.assignedEmployeeName, !assigned.isEmpty {
                Label("Assigned: \(assigned)", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let members = job.assignedTeamMembers, !members.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(members.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            if job.status == .rescheduled, let reschedule = job.rescheduleRequest {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reschedule requested")
                            .font(.caption)
                            .foregroundColor(.orange)
                        if !reschedule.reason.isEmpty {
                            Text(reschedule.reason)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
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

                HStack(spacing: 4) {
                    if let id = employee.id {
                        Text("ID: \(id)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    if employee.id != nil, employee.role != nil {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let role = employee.role {
                        Text(role)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let role = employee.role, let pin = employee.pin {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let pin = employee.pin {
                        Text("PIN: \(pin)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let email = employee.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
