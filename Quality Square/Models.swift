//
//  Models.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import Foundation
import FirebaseFirestore

// MARK: - Employee Model
struct Employee: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var pin: String?
    var email: String?
    var role: String?
    var status: String
    var createdAt: Date

    // Computed property for backward compatibility
    var isActive: Bool {
        return status.lowercased() == "active"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pin
        case email
        case role
        case status
        case createdAt
    }

    // Custom initializer to handle missing status field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self._id = try container.decodeIfPresent(DocumentID<String>.self, forKey: .id) ?? DocumentID(wrappedValue: nil)
        self.name = try container.decode(String.self, forKey: .name)
        self.pin = try container.decodeIfPresent(String.self, forKey: .pin)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.role = try container.decodeIfPresent(String.self, forKey: .role)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

// MARK: - Clock Record Model
struct ClockRecord: Identifiable, Codable {
    @DocumentID var id: String?
    var employeeId: String
    var employeeName: String
    var clockInTime: Date
    var clockOutTime: Date?
    var date: String // Format: "YYYY-MM-DD" for easy querying

    var isClocked: Bool {
        clockOutTime == nil
    }

    var duration: TimeInterval? {
        guard let clockOut = clockOutTime else { return nil }
        return clockOut.timeIntervalSince(clockInTime)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case employeeId
        case employeeName
        case clockInTime
        case clockOutTime
        case date
    }

    // Custom initializer for creating ClockRecord manually
    init(id: String? = nil, employeeId: String, employeeName: String, clockInTime: Date, clockOutTime: Date?, date: String) {
        self._id = DocumentID(wrappedValue: id)
        self.employeeId = employeeId
        self.employeeName = employeeName
        self.clockInTime = clockInTime
        self.clockOutTime = clockOutTime
        self.date = date
    }
}

// MARK: - Job Status Enum
enum JobStatus: String, Codable, CaseIterable {
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case completed = "Completed"
    case rescheduled = "Rescheduled"
    case cancelled = "Cancelled"

    // Workflow-specific statuses
    case pickingUp = "picking_up"
    case pickUp = "pick_up"
    case enRoute = "en_route"
    case complete = "complete"
    
    var color: String {
        switch self {
        case .scheduled: return "blue"
        case .inProgress: return "orange"
        case .completed, .complete: return "green"
        case .rescheduled: return "purple"
        case .cancelled: return "red"
        case .pickingUp: return "teal"
        case .pickUp: return "blue"
        case .enRoute: return "orange"
        }
    }

    var displayName: String {
        switch self {
        case .pickingUp: return "Picking Up"
        case .pickUp: return "Picked Up"
        case .enRoute: return "En Route"
        case .complete, .completed: return "Complete"
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .rescheduled: return "Rescheduled"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Job Type Enum
enum JobType: String, Codable, CaseIterable {
    case bestBuyTV = "Best Buy TV Install"
    case costco = "Costco Install"
    case thirdParty = "3rd Party"
    case appliance = "Appliance Install"
    case other = "Other"
}

// MARK: - Job Model
struct Job: Identifiable, Codable {
    @DocumentID var id: String?
    var clientName: String
    var clientAddress: String
    var clientPhone: String?
    var jobType: JobType
    var jobDescription: String
    var scheduledDate: Date
    var scheduledTime: String // e.g., "9:00 AM"
    var assignedEmployeeId: String
    var assignedEmployeeName: String
    var assignedTeamId: String?
    var assignedTeamName: String?
    var status: JobStatus
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var rescheduleRequest: RescheduleRequest?
    
    enum CodingKeys: String, CodingKey {
        case id
        case clientName
        case clientAddress
        case clientPhone
        case jobType
        case jobDescription
        case scheduledDate
        case scheduledTime
        case assignedEmployeeId
        case assignedEmployeeName
        case assignedTeamId
        case assignedTeamName
        case status
        case notes
        case createdAt
        case updatedAt
        case rescheduleRequest
    }
}

// MARK: - Reschedule Request
struct RescheduleRequest: Codable {
    var requestedBy: String
    var requestedDate: Date
    var reason: String
    var newProposedDate: Date?
    var isApproved: Bool?

    enum CodingKeys: String, CodingKey {
        case requestedBy
        case requestedDate
        case reason
        case newProposedDate
        case isApproved
    }
}

// MARK: - Team Member Model
struct TeamMember: Codable {
    var employeeId: String
    var employeeName: String
    var employeeRole: String?

    enum CodingKeys: String, CodingKey {
        case employeeId
        case employeeName
        case employeeRole
    }
}

// MARK: - Team Model
struct Team: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var leaderId: String
    var leaderName: String
    var members: [TeamMember]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case leaderId
        case leaderName
        case members
        case createdAt
        case updatedAt
    }
}

// MARK: - Time Entry Model
struct TimeEntry: Identifiable, Codable {
    @DocumentID var id: String?
    var employeeId: String
    var clockIn: Date
    var clockOut: Date?
    var duration: Double?
    var payPeriodId: String

    var isActive: Bool {
        clockOut == nil
    }

    var hoursWorked: Double? {
        duration
    }

    enum CodingKeys: String, CodingKey {
        case id
        case employeeId
        case clockIn
        case clockOut
        case duration
        case payPeriodId
    }
}

// MARK: - Employee Status (for Admin Dashboard)
struct EmployeeStatus: Identifiable {
    let id: String
    let employee: Employee
    let clockRecord: ClockRecord?

    var status: String {
        guard let record = clockRecord else {
            return "Not Clocked In"
        }
        return record.isClocked ? "Clocked In" : "Clocked Out"
    }

    var statusColor: String {
        guard let record = clockRecord else {
            return "gray"
        }
        return record.isClocked ? "green" : "orange"
    }

    var clockInTime: Date? {
        clockRecord?.clockInTime
    }

    var clockOutTime: Date? {
        clockRecord?.clockOutTime
    }

    var hoursWorked: Double? {
        guard let record = clockRecord, let duration = record.duration else {
            return nil
        }
        return duration / 3600.0 // Convert seconds to hours
    }
}
