//
//  EmployeeDashboard.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import SwiftUI
import Combine

struct EmployeeDashboard: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var firestoreManager = FirestoreManager()
    
    @State private var clockRecord: ClockRecord?
    @State private var todayJobs: [Job] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingLogoutConfirm = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerCancellable: AnyCancellable?
    @State private var showingVehiclePicker = false
    @State private var selectedPlate: LicensePlate?
    @State private var licensePlates: [LicensePlate] = []
    @State private var employeeTeamId: String?
    @State private var employeeTeamName: String?
    @State private var employeeTeamMembers: [String] = []
    @State private var vehicleError: String?
    
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
                                
                                if isClockedIn {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(elapsedDisplay)
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

                        // Vehicle chip
                        if let plate = selectedPlate {
                            HStack {
                                Label(plate.plateNum, systemImage: "car.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                HStack(spacing: 10) {
                                    Button("Change") { showingVehiclePicker = true }
                                        .font(.caption.bold())
                                    Button("Release") { releaseVehicle() }
                                        .font(.caption.bold())
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        } else {
                            Button {
                                showingVehiclePicker = true
                            } label: {
                                Label("Select Vehicle", systemImage: "car.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                            }
                            .padding(.horizontal, 20)
                            
                            // No extra warnings here; selection is mandatory before clock-in
                        }
                        
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
        .onDisappear {
            stopElapsedTimer()
        }
        .sheet(isPresented: $showingVehiclePicker) {
            VehiclePickerSheet(
                plates: licensePlates,
                teamId: employeeTeamId,
                currentUserId: authManager.currentUser?.id,
                onSelect: { plate in
                    selectedPlate = plate
                }
            )
        }
        .alert("Logout", isPresented: $showingLogoutConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                authManager.logout()
                stopElapsedTimer()
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
                        stopElapsedTimer()
                        Task { await loadData() }
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            // Require vehicle selection before clock in
            guard let plate = selectedPlate else {
                isLoading = false
                showingVehiclePicker = true
                errorMessage = "Select a vehicle before clocking in."
                return
            }

            // Clock In
            firestoreManager.clockIn(employeeId: employeeId, employeeName: employeeName) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let record):
                        // assign vehicle if we have a valid plate id
                        firestoreManager.assignLicensePlate(
                            plate: plate,
                            driverId: employeeId,
                            driverName: employeeName,
                            teamId: employeeTeamId,
                            teamName: employeeTeamName,
                            teamMembers: employeeTeamMembers
                        ) { assignResult in
                            if case .failure(let error) = assignResult {
                                errorMessage = "Vehicle assignment failed: \(error.localizedDescription)"
                            }
                        }

                        isLoading = false
                        clockRecord = record
                        startElapsedTimer(from: record.clockInTime)
                        Task { await loadData() }
                    case .failure(let error):
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func loadData() async {
        guard let employeeId = authManager.currentUser?.id else { return }
        
        firestoreManager.fetchTeamsForEmployee(employeeId: employeeId) { teams in
            DispatchQueue.main.async {
                employeeTeamId = teams.first?.id
                employeeTeamName = teams.first?.name
                employeeTeamMembers = teams.first?.members ?? []
                preselectPlate(from: licensePlates)
            }
        }
        
        // Load clock status
        firestoreManager.getTodayClockStatus(employeeId: employeeId) { result in
            DispatchQueue.main.async {
                if case .success(let record) = result {
                    clockRecord = record
                    if let clockIn = record?.clockInTime, record?.isClocked == true {
                        startElapsedTimer(from: clockIn)
                    } else {
                        stopElapsedTimer()
                    }
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
        
        firestoreManager.getLicensePlates { result in
            DispatchQueue.main.async {
                if case .success(let plates) = result {
                    let unique = Dictionary(grouping: plates, by: { $0.id ?? $0.plateNum })
                        .compactMap { $0.value.first }
                        .sorted { $0.plateNum < $1.plateNum }
                    licensePlates = unique
                    preselectPlate(from: unique)
                } else if case .failure(let error) = result {
                    vehicleError = "Failed to load vehicles: \(error.localizedDescription)"
                }
            }
        }
    }

    private var elapsedDisplay: String {
        formatDuration(elapsedTime)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%02dm %02ds", minutes, seconds)
        }
    }
    
    private func startElapsedTimer(from startDate: Date) {
        timerCancellable?.cancel()
        elapsedTime = Date().timeIntervalSince(startDate)
        
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { now in
                elapsedTime = now.timeIntervalSince(startDate)
            }
    }
    
    private func stopElapsedTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        elapsedTime = 0
    }

    private func releaseVehicle() {
        guard let plateId = selectedPlate?.id else { return }
        firestoreManager.clearLicensePlateAssignment(plateId: plateId) { _ in }
        selectedPlate = nil
        Task { await loadData() }
    }

    private func preselectPlate(from plates: [LicensePlate]) {
        guard let userId = authManager.currentUser?.id else { return }
        if let match = plates.first(where: { plate in
            plate.currentDriverId == userId || (employeeTeamId != nil && plate.currentTeamId == employeeTeamId)
        }) {
            selectedPlate = match
        }
    }
}

// MARK: - Vehicle Picker
private struct VehiclePickerSheet: View {
    let plates: [LicensePlate]
    let teamId: String?
    let currentUserId: String?
    let onSelect: (LicensePlate) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if plates.isEmpty {
                    Text("No vehicles available. Ask an admin to add plates.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(plates, id: \.plateNum) { plate in
                        let isHeldBySelf = plate.currentDriverId == currentUserId || (teamId != nil && plate.currentTeamId == teamId)
                        let isAvailable = plate.available || isHeldBySelf
                        let isTakenByOtherTeam = !isAvailable && !isHeldBySelf
                        Button {
                            guard !isTakenByOtherTeam else { return }
                            onSelect(plate)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plate.plateNum)
                                        .font(.headline)
                                    if isHeldBySelf {
                                        Text("Assigned to you/team")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Capsule()
                                    .fill((plate.available || isHeldBySelf) ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                    .frame(width: 90, height: 28)
                                    .overlay(
                                        Text((plate.available || isHeldBySelf) ? "Available" : "Unavailable")
                                            .font(.caption)
                                            .foregroundColor((plate.available || isHeldBySelf) ? .green : .red)
                                    )
                            }
                        }
                        .disabled(isTakenByOtherTeam)
                    }
                }
            }
            .navigationTitle("Select Vehicle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
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
        Text(status.displayName)
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
        case .inProgress, .pickingUp, .pickUp, .enRoute: return .orange
        case .completed, .complete: return .green
        case .rescheduled: return .purple
        case .cancelled: return .red
        }
    }
}

#Preview {
    EmployeeDashboard()
        .environmentObject(AuthenticationManager())
}
