//
//  EmployeeTabView.swift
//  Quality Square
//
//  Created by Saba on 12/9/25.
//

import SwiftUI

struct EmployeeTabView: View {
    var body: some View {
        TabView {
            EmployeeDashboard()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            EmployeeJobsView()
                .tabItem {
                    Label("Jobs", systemImage: "briefcase.fill")
                }

            JobHistoryView()
                .tabItem {
                    Label("Job History", systemImage: "clock.arrow.circlepath")
                }

            HoursWorkedView()
                .tabItem {
                    Label("Hours Worked", systemImage: "hourglass")
                }

            EmployeeSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Jobs (today)
struct EmployeeJobsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var firestoreManager = FirestoreManager()

    @State private var jobs: [Job] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                if !jobs.isEmpty {
                    Section {
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Today")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(jobs.count) job\(jobs.count == 1 ? "" : "s")")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("\(inProgressCount) in progress • \(teamJobCount) team")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "rectangle.stack.person.crop")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if isLoading {
                    ProgressView("Loading jobs...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage {
                    EmployeeErrorStateView(message: errorMessage) {
                        Task { await loadJobs() }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if jobs.isEmpty {
                    EmployeeEmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "No jobs scheduled for today",
                        subtitle: "Pull to refresh to check again."
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(jobs) { job in
                        NavigationLink(destination: JobDetailView(job: job)) {
                            JobRowView(job: job)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Jobs")
            .task {
                await loadJobs()
            }
            .refreshable {
                await loadJobs()
            }
        }
    }

    private func loadJobs() async {
        guard let employeeId = authManager.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil

        firestoreManager.getEmployeeJobsForToday(employeeId: employeeId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let loadedJobs):
                    jobs = loadedJobs
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var inProgressCount: Int {
        jobs.filter { $0.status == .inProgress || $0.status == .pickingUp || $0.status == .pickUp || $0.status == .enRoute }.count
    }

    private var teamJobCount: Int {
        jobs.filter { $0.assignedTeamId != nil }.count
    }
}

// MARK: - Job History
struct JobHistoryView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var firestoreManager = FirestoreManager()

    @State private var jobs: [Job] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                if !jobs.isEmpty {
                    Section {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent Work")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(jobs.count) job\(jobs.count == 1 ? "" : "s") total")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("\(completedCount) completed • \(teamJobCount) team")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if isLoading {
                    ProgressView("Loading history...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage {
                    EmployeeErrorStateView(message: errorMessage) {
                        Task { await loadHistory() }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if jobs.isEmpty {
                    EmployeeEmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "No recent jobs",
                        subtitle: "Completed and scheduled jobs will show here."
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(jobs) { job in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(job.clientName ?? "")
                                .font(.headline)
                            Text(job.displayInstallType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Label(job.scheduledTime ?? "", systemImage: "clock")
                                Label(job.clientAddress ?? "", systemImage: "location.fill")
                                    .lineLimit(1)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            Text(job.status?.displayName ?? "")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.gray.opacity(0.15))
                                )
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Job History")
            .task {
                await loadHistory()
            }
            .refreshable {
                await loadHistory()
            }
        }
    }

    private func loadHistory() async {
        guard let employeeId = authManager.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil

        firestoreManager.getJobHistoryForEmployee(employeeId: employeeId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let loadedJobs):
                    jobs = loadedJobs
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var completedCount: Int {
        jobs.filter { $0.status == .completed || $0.status == .complete }.count
    }

    private var teamJobCount: Int {
        jobs.filter { $0.assignedTeamId != nil }.count
    }
}

// MARK: - Hours Worked
struct HoursWorkedView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var firestoreManager = FirestoreManager()

    @State private var timeEntries: [TimeEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var totalHours: Double {
        timeEntries.compactMap { $0.duration }.reduce(0, +)
    }

    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView("Loading hours...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage {
                    EmployeeErrorStateView(message: errorMessage) {
                        Task { await loadEntries() }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if timeEntries.isEmpty {
                    EmployeeEmptyStateView(
                        icon: "hourglass",
                        title: "No time entries yet",
                        subtitle: "Clock in to start tracking hours."
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Section {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("This period")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f hrs", totalHours))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("\(activeCount) active • \(entryCount) entries")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Section {
                        HStack {
                            Text("Total Hours")
                            Spacer()
                            Text(String(format: "%.2f", totalHours))
                                .font(.headline)
                        }
                    }

                    Section(header: Text("Entries")) {
                        ForEach(timeEntries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(formatDate(entry.clockIn))
                                        .font(.headline)
                                    Spacer()
                                    if let duration = entry.duration {
                                        Text(String(format: "%.2f hrs", duration))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("In progress")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }

                                HStack(spacing: 12) {
                                    Label(formatTime(entry.clockIn), systemImage: "arrow.down.circle.fill")
                                    if let clockOut = entry.clockOut {
                                        Label(formatTime(clockOut), systemImage: "arrow.up.circle.fill")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Hours Worked")
            .task {
                await loadEntries()
            }
            .refreshable {
                await loadEntries()
            }
        }
    }

    private func loadEntries() async {
        guard let employeeId = authManager.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil

        firestoreManager.getTimeEntriesByEmployee(employeeId: employeeId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let entries):
                    timeEntries = entries
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var activeCount: Int {
        timeEntries.filter { $0.isActive }.count
    }

    private var entryCount: Int {
        timeEntries.count
    }
}

// MARK: - Settings
struct EmployeeSettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    HStack {
                        Text("Logged in as")
                        Spacer()
                        Text(authManager.currentUser?.name ?? "Employee")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Simple Reusable States
private struct EmployeeEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.6))
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct EmployeeErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
    }
}

#Preview {
    EmployeeTabView()
        .environmentObject(AuthenticationManager())
}
