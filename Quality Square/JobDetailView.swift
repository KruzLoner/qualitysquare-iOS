//
//  JobDetailView.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import SwiftUI

struct JobDetailView: View {
    let job: Job
    @StateObject private var firestoreManager = FirestoreManager()
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var showingStatusUpdate = false
    @State private var showingRescheduleRequest = false
    @State private var selectedStatus: JobStatus
    @State private var isUpdating = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    
    init(job: Job) {
        self.job = job
        _selectedStatus = State(initialValue: job.status)
    }
    
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Client Info Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue.opacity(0.7))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(job.clientName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                if let phone = job.clientPhone {
                                    Text(phone)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text(job.clientAddress)
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue.opacity(0.7))
                            }
                            
                            Label {
                                Text("\(formatDate(job.scheduledDate)) at \(job.scheduledTime)")
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue.opacity(0.7))
                            }
                            
                            Label {
                                Text(job.jobType.rawValue)
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.blue.opacity(0.7))
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
                    
                    // Job Description Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Job Description")
                            .font(.headline)
                        
                        Text(job.jobDescription)
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
                    
                    // Notes Card (if any)
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
                    
                    // Current Status Card
                    VStack(spacing: 12) {
                        HStack {
                            Text("Current Status")
                                .font(.headline)
                            Spacer()
                            JobStatusBadge(status: job.status)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)
                    
                    // Reschedule Request Info (if any)
                    if let reschedule = job.rescheduleRequest {
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
                                    Text(approved ? "✓ Approved" : "✗ Declined")
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
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: { showingStatusUpdate = true }) {
                            Label("Update Status", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.9))
                                )
                                .foregroundColor(.white)
                        }
                        .disabled(isUpdating)
                        
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
                        .disabled(isUpdating || job.status == .completed)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingStatusUpdate) {
            StatusUpdateSheet(
                job: job,
                selectedStatus: $selectedStatus,
                isUpdating: $isUpdating,
                onUpdate: updateStatus
            )
        }
        .sheet(isPresented: $showingRescheduleRequest) {
            RescheduleRequestSheet(
                job: job,
                isUpdating: $isUpdating,
                onSubmit: submitRescheduleRequest
            )
        }
    }
    
    private func updateStatus() {
        guard let jobId = job.id else { return }
        
        isUpdating = true
        errorMessage = nil
        successMessage = nil
        
        firestoreManager.updateJobStatus(jobId: jobId, status: selectedStatus) { result in
            DispatchQueue.main.async {
                isUpdating = false
                showingStatusUpdate = false
                
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

// MARK: - Status Update Sheet
struct StatusUpdateSheet: View {
    let job: Job
    @Binding var selectedStatus: JobStatus
    @Binding var isUpdating: Bool
    let onUpdate: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Update job status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                    
                    ForEach(JobStatus.allCases, id: \.self) { status in
                        StatusOptionButton(
                            status: status,
                            isSelected: selectedStatus == status,
                            action: { selectedStatus = status }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Button(action: onUpdate) {
                        Text("Update Status")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.9))
                            )
                            .foregroundColor(.white)
                    }
                    .disabled(isUpdating)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Update Status")
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

// MARK: - Status Option Button
struct StatusOptionButton: View {
    let status: JobStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                JobStatusBadge(status: status)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(backgroundView)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.blue.opacity(0.1) : Color(uiColor: .systemGray6).opacity(0.3))
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

