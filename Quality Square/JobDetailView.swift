//
//  JobDetailView.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import SwiftUI
import UIKit

struct JobDetailView: View {
    let job: Job
    @StateObject private var firestoreManager = FirestoreManager()
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var showingRescheduleRequest = false
    @State private var selectedStatus: JobStatus?
    @State private var isUpdating = false
    @State private var successMessage: String?
    @State private var errorMessage: String?

    init(job: Job) {
        self.job = job
        _selectedStatus = State(initialValue: job.status)
    }

    private var isAdmin: Bool {
        authManager.userRole == .admin
    }

    private var identifierText: String? {
        if let doli = job.doliNumber, !doli.isEmpty {
            return "Dolibarr: \(doli)"
        }
        if let jobNumber = job.jobNumber, !jobNumber.isEmpty {
            return "Job: #\(jobNumber)"
        }
        return nil
    }

    private var itemsList: [String] {
        let raw = job.items ?? ""
        return raw
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(job.clientName ?? "Customer")
                                .font(.title2)
                                .fontWeight(.bold)
                            Divider()
                            if let id = identifierText {
                                InfoRow(label: "Dolibarr", value: id.replacingOccurrences(of: "Dolibarr: ", with: ""), allowWrap: true, labelWidth: 170)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Key Info
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Schedule")
                                .font(.headline)
                            Divider()
                            if let installDate = job.scheduledDate {
                                InfoRow(label: "Date", value: formatDate(installDate))
                            } else {
                                InfoRow(label: "Date", value: "N/A")
                            }
                            InfoRow(label: "Time Frame", value: job.timeFrame ?? job.scheduledTime ?? "N/A")
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Store & Item")
                                .font(.headline)
                            Divider()
                            InfoRow(label: "Store", value: job.storeCompany ?? "N/A")
                            InfoRow(label: "Install Type", value: job.displayInstallType)
                            if itemsList.isEmpty {
                                InfoRow(label: "Items", value: "N/A", allowWrap: true, labelWidth: 80)
                            } else {
                                ItemsRow(label: "Items", items: itemsList, labelWidth: 80)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .padding(.horizontal, 20)

                    // Locations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Locations")
                            .font(.headline)
                        Divider()
                        InfoRow(label: "Pick Up", value: job.pickUpAddress ?? "N/A")
                        InfoRow(label: "Customer", value: job.clientAddress ?? "N/A")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)

                    // Contact
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contact")
                            .font(.headline)
                        Divider()

                        InfoRow(label: "Phone", value: job.clientPhone ?? "N/A")
                        if let phone = job.clientPhone, !phone.isEmpty {
                            HStack(spacing: 10) {
                                Button {
                                    if let url = URL(string: "tel://\(phone.filter { !$0.isWhitespace })") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Call", systemImage: "phone.fill")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(.thinMaterial)
                                        )
                                }

                                Button {
                                    if let url = URL(string: "sms://\(phone.filter { !$0.isWhitespace })") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Text", systemImage: "message.fill")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(.thinMaterial)
                                        )
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)

                    // Description
                    if let description = job.jobDescription, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Job Description")
                                .font(.headline)

                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                        .padding(.horizontal, 20)
                    }

                    // Notes
                    if let notes = job.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Notes", systemImage: "note.text")
                                .font(.headline)
                            
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Status Progress
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Status")
                                .font(.headline)
                            Spacer()
                            if let status = selectedStatus {
                                JobStatusBadge(status: status)
                            }
                        }
                        
                        if let status = selectedStatus {
                            StatusProgressView(
                                steps: workflowStatuses,
                                currentStatus: status
                            )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)
                    
                    // Reschedule Request Info (if any)
                    if let reschedule = job.rescheduleRequest, reschedule.isApproved != true {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Reschedule Request", systemImage: "clock.arrow.2.circlepath")
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reason: \(reschedule.reason)")
                                    .font(.subheadline)
                                
                                if let newDate = reschedule.newProposedDate {
                                    Text("Proposed Date: \(formatDate(newDate))")
                                        .font(.subheadline)
                                }
                                
                                if let approved = reschedule.isApproved {
                                    Text(approved ? "Approved" : "Declined")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(approved ? .green : .red)
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.purple.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Messages
                    if let success = successMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(success)
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.green.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                    }
                    
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
                    
                    // Action Buttons (employees only)
                    if !isAdmin {
                        VStack(spacing: 12) {
                            Button(action: advanceStatus) {
                                Label(nextStatusButtonTitle, systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(canAdvance ? Color.blue.opacity(0.9) : Color.gray.opacity(0.4))
                                    )
                                    .foregroundColor(.white)
                            }
                            .disabled(!canAdvance || isUpdating)
                            
                            Button(action: { showingRescheduleRequest = true }) {
                                Label("Request Reschedule", systemImage: "calendar.badge.clock")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                    )
                                    .foregroundColor(.primary)
                            }
                            .disabled(isUpdating || rescheduleApproved || job.status == .completed || job.status == nil)

                            if rescheduleApproved {
                                Text("Reschedule approved — job locked")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRescheduleRequest) {
            RescheduleRequestSheet(
                job: job,
                isUpdating: $isUpdating,
                onSubmit: submitRescheduleRequest
            )
        }
    }
    
    private var workflowStatuses: [JobStatus] {
        [.pickingUp, .pickUp, .enRoute, .complete]
    }
    
    private var nextStatus: JobStatus? {
        guard let status = selectedStatus else { return nil }
        if status == .complete || status == .completed {
            return nil
        }
        guard let idx = workflowStatuses.firstIndex(of: status) else {
            return workflowStatuses.first
        }
        let nextIndex = workflowStatuses.index(after: idx)
        return nextIndex < workflowStatuses.count ? workflowStatuses[nextIndex] : nil
    }
    
    private var nextStatusButtonTitle: String {
        guard let next = nextStatus else { return "Completed" }
        switch next {
        case .pickingUp: return "Start Pickup"
        case .pickUp: return "Mark Picked Up"
        case .enRoute: return "Mark En Route"
        case .complete: return "Mark Complete"
        default: return "Advance Status"
        }
    }
    
    private var canAdvance: Bool {
        nextStatus != nil && !rescheduleApproved
    }

    private var rescheduleApproved: Bool {
        job.rescheduleRequest?.isApproved == true || job.status == .rescheduled
    }
    
    private func advanceStatus() {
        guard let jobId = job.id, let next = nextStatus else { return }
        isUpdating = true
        errorMessage = nil
        successMessage = nil
        
        firestoreManager.updateJobStatus(jobId: jobId, status: next) { result in
            DispatchQueue.main.async {
                isUpdating = false
                switch result {
                case .success:
                    selectedStatus = next
                    successMessage = "Status updated to \(next.displayName)"
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func updateStatus() {
        guard let jobId = job.id, let status = selectedStatus else { return }

        isUpdating = true
        errorMessage = nil
        successMessage = nil

        firestoreManager.updateJobStatus(jobId: jobId, status: status) { result in
            DispatchQueue.main.async {
                isUpdating = false

                switch result {
                case .success:
                    successMessage = "Status updated successfully"
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func submitRescheduleRequest(reason: String, newDate: Date?) {
        guard let jobId = job.id,
              let employeeName = authManager.currentUser?.name else { return }
        
        isUpdating = true
        errorMessage = nil
        successMessage = nil
        
        firestoreManager.requestJobReschedule(
            jobId: jobId,
            requestedBy: employeeName,
            reason: reason,
            newDate: newDate
        ) { result in
            DispatchQueue.main.async {
                isUpdating = false
                showingRescheduleRequest = false
                
                switch result {
                case .success:
                    successMessage = "Reschedule request submitted"
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Info Row Component
private struct InfoRow: View {
    let label: String
    let value: String
    var allowWrap: Bool = false
    var labelWidth: CGFloat = 110

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(allowWrap ? nil : 1)
                .allowsTightening(!allowWrap)
                .minimumScaleFactor(allowWrap ? 1.0 : 0.95)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
    }
}

private struct ItemsRow: View {
    let label: String
    let items: [String]
    var labelWidth: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items.indices, id: \.self) { idx in
                    Text("• \(items[idx])")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
    }
}

// MARK: - Pill
private struct PillView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thinMaterial)
        )
    }
}

// MARK: - Status Progress
private struct StatusProgressView: View {
    let steps: [JobStatus]
    let currentStatus: JobStatus

    private var currentIndex: Int {
        if currentStatus == .complete || currentStatus == .completed {
            return steps.count - 1
        }
        return steps.firstIndex(of: currentStatus) ?? 0
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(spacing: 0) {
                        StepCircle(
                            title: steps[index].displayName,
                            isActive: index <= currentIndex
                        )

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(index < currentIndex ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}

private struct StepCircle: View {
    let title: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 16, height: 16)

            Text(title)
                .font(.caption2)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .frame(minWidth: 70)
    }
}

// MARK: - Reschedule Request Sheet
struct RescheduleRequestSheet: View {
    let job: Job
    @Binding var isUpdating: Bool
    let onSubmit: (String, Date?) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var reason = ""
    @State private var newDate: Date = Date()
    @State private var includeNewDate = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Submit a reschedule request to the admin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                        
                        // Reason Field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reason")
                                .font(.headline)
                            
                            TextEditor(text: $reason)
                                .frame(height: 120)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.thinMaterial)
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Proposed New Date
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $includeNewDate) {
                                Text("Suggest new date")
                                    .font(.headline)
                            }
                            
                            if includeNewDate {
                                DatePicker(
                                    "New Date",
                                    selection: $newDate,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.thinMaterial)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                        
                        Button(action: {
                            onSubmit(reason, includeNewDate ? newDate : nil)
                        }) {
                            Text("Submit Request")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(reason.isEmpty ? Color.gray : Color.purple.opacity(0.9))
                                )
                                .foregroundColor(.white)
                        }
                        .disabled(isUpdating || reason.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Request Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let sampleJob = Job(
        clientName: "John Doe",
        clientAddress: "123 Main St, City, State",
        clientPhone: "(555) 123-4567",
        jobType: .bestBuyTV,
        jobDescription: "Install 65\" Samsung TV and soundbar system",
        scheduledDate: Date(),
        scheduledTime: "2:00 PM",
        assignedEmployeeId: "emp123",
        assignedEmployeeName: "Mike Johnson",
        status: .scheduled,
        notes: "Customer prefers wall mount",
        createdAt: Date(),
        updatedAt: Date()
    )
    
    JobDetailView(job: sampleJob)
        .environmentObject(AuthenticationManager())
}
