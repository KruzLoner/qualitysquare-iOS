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
    case pickingUp = "Picking Up"
    case pickUp = "Pick Up"
    case enRoute = "En Route"
    case complete = "Complete"
    
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

// MARK: - License Plate / Vehicle
struct LicensePlate: Identifiable, Codable {
    @DocumentID var id: String?
    var plateNum: String
    var currentDriverId: String?
    var currentDriverName: String?
    var currentTeamId: String?
    var currentTeamName: String?
    var assignedAt: Date?
    var available: Bool
    var currentTeamMembers: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case plateNum
        case currentDriverId
        case currentDriverName
        case currentTeamId
        case currentTeamName
        case assignedAt
        case available
        case currentTeamMembers
    }

    init(id: String? = nil, plateNum: String, currentDriverId: String? = nil, currentDriverName: String? = nil, currentTeamId: String? = nil, currentTeamName: String? = nil, assignedAt: Date? = nil, available: Bool = true) {
        self._id = DocumentID(wrappedValue: id)
        self.plateNum = plateNum
        self.currentDriverId = currentDriverId
        self.currentDriverName = currentDriverName
        self.currentTeamId = currentTeamId
        self.currentTeamName = currentTeamName
        self.assignedAt = assignedAt
        self.available = available
        self.currentTeamMembers = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self._id = try container.decodeIfPresent(DocumentID<String>.self, forKey: .id) ?? DocumentID(wrappedValue: nil)
        self.plateNum = try container.decode(String.self, forKey: .plateNum)
        self.currentDriverId = try container.decodeIfPresent(String.self, forKey: .currentDriverId)
        self.currentDriverName = try container.decodeIfPresent(String.self, forKey: .currentDriverName)
        self.currentTeamId = try container.decodeIfPresent(String.self, forKey: .currentTeamId)
        self.currentTeamName = try container.decodeIfPresent(String.self, forKey: .currentTeamName)
        self.assignedAt = try container.decodeIfPresent(Date.self, forKey: .assignedAt)
        self.available = try container.decodeIfPresent(Bool.self, forKey: .available) ?? true
        self.currentTeamMembers = try container.decodeIfPresent([String].self, forKey: .currentTeamMembers)
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
    var jobNumber: String?
    var doliNumber: String?
    var storeCompany: String?
    var clientName: String?
    var clientAddress: String?
    var clientPhone: String?
    var pickUpAddress: String?
    var jobType: JobType?
    var installType: String? // Raw string from Firebase
    var jobDescription: String?
    var items: String?
    var scheduledDate: Date?
    var scheduledTime: String? // e.g., "9:00 AM"
    var timeFrame: String? // e.g., "08:00 - 12:00"
    var assignedEmployeeId: String?
    var assignedEmployeeName: String?
    var assignedTeamId: String?
    var assignedTeamName: String?
    var assignedTeamMembers: [String]?
    var status: JobStatus?
    var notes: String?
    var createdAt: Date?
    var updatedAt: Date?
    var rescheduleRequest: RescheduleRequest?

    enum CodingKeys: String, CodingKey {
        case id
        case jobNumber
        case doliNumber = "dolibarrId"
        case storeCompany
        case clientName = "customerName"
        case clientAddress
        case clientPhone = "phoneNumber"
        case pickUpAddress
        case jobType
        case installType
        case items
        case jobDescription = "description"
        case scheduledDate = "installDate"
        case scheduledTime
        case timeFrame
        case assignedEmployeeId
        case assignedEmployeeName
        case assignedTeamId
        case assignedTeamName
        case assignedTeamMembers
        case status
        case notes
        case createdAt
        case updatedAt
        case rescheduleRequest
    }

    // Helper to get the install type as a string
    var displayInstallType: String {
        if let installType = installType {
            return installType
        }
        return jobType?.rawValue ?? "N/A"
    }

    // Regular initializer
    init(
        id: String? = nil,
        jobNumber: String? = nil,
        doliNumber: String? = nil,
        storeCompany: String? = nil,
        clientName: String? = nil,
        clientAddress: String? = nil,
        clientPhone: String? = nil,
        pickUpAddress: String? = nil,
        jobType: JobType? = nil,
        installType: String? = nil,
        items: String? = nil,
        jobDescription: String? = nil,
        scheduledDate: Date? = nil,
        scheduledTime: String? = nil,
        timeFrame: String? = nil,
        assignedEmployeeId: String? = nil,
        assignedEmployeeName: String? = nil,
        assignedTeamId: String? = nil,
        assignedTeamName: String? = nil,
        assignedTeamMembers: [String]? = nil,
        status: JobStatus? = nil,
        notes: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        rescheduleRequest: RescheduleRequest? = nil
    ) {
        self.id = id
        self.jobNumber = jobNumber
        self.doliNumber = doliNumber
        self.storeCompany = storeCompany
        self.clientName = clientName
        self.clientAddress = clientAddress
        self.clientPhone = clientPhone
        self.pickUpAddress = pickUpAddress
        self.jobType = jobType
        self.installType = installType
        self.items = items
        self.jobDescription = jobDescription
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.timeFrame = timeFrame
        self.assignedEmployeeId = assignedEmployeeId
        self.assignedEmployeeName = assignedEmployeeName
        self.assignedTeamId = assignedTeamId
        self.assignedTeamName = assignedTeamName
        self.assignedTeamMembers = assignedTeamMembers
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rescheduleRequest = rescheduleRequest
    }

    // Custom decoder to handle date strings from Firebase
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        jobNumber = try container.decodeIfPresent(String.self, forKey: .jobNumber)
        doliNumber = try container.decodeIfPresent(String.self, forKey: .doliNumber)
        storeCompany = try container.decodeIfPresent(String.self, forKey: .storeCompany)
        clientName = try container.decodeIfPresent(String.self, forKey: .clientName)
        clientAddress = try container.decodeIfPresent(String.self, forKey: .clientAddress)
        clientPhone = try container.decodeIfPresent(String.self, forKey: .clientPhone)
        pickUpAddress = try container.decodeIfPresent(String.self, forKey: .pickUpAddress)
        jobType = try container.decodeIfPresent(JobType.self, forKey: .jobType)
        installType = try container.decodeIfPresent(String.self, forKey: .installType)
        items = try container.decodeIfPresent(String.self, forKey: .items)
        jobDescription = try container.decodeIfPresent(String.self, forKey: .jobDescription)

        // Handle date - try as Date first, then as string
        if let date = try? container.decodeIfPresent(Date.self, forKey: .scheduledDate) {
            scheduledDate = date
        } else if let dateString = try? container.decodeIfPresent(String.self, forKey: .scheduledDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            scheduledDate = formatter.date(from: dateString)
        } else {
            scheduledDate = nil
        }

        scheduledTime = try container.decodeIfPresent(String.self, forKey: .scheduledTime)
        timeFrame = try container.decodeIfPresent(String.self, forKey: .timeFrame)
        assignedEmployeeId = try container.decodeIfPresent(String.self, forKey: .assignedEmployeeId)
        assignedEmployeeName = try container.decodeIfPresent(String.self, forKey: .assignedEmployeeName)
        assignedTeamId = try container.decodeIfPresent(String.self, forKey: .assignedTeamId)
        assignedTeamName = try container.decodeIfPresent(String.self, forKey: .assignedTeamName)
        assignedTeamMembers = try container.decodeIfPresent([String].self, forKey: .assignedTeamMembers)
        status = try container.decodeIfPresent(JobStatus.self, forKey: .status)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        rescheduleRequest = try container.decodeIfPresent(RescheduleRequest.self, forKey: .rescheduleRequest)
    }
}

// MARK: - Reschedule Request
struct RescheduleRequest: Codable {
    var requestedBy: String
    var requestedDate: Date
    var reason: String
    var newProposedDate: Date?
    var isApproved: Bool?
    var approvedDate: Date?

    enum CodingKeys: String, CodingKey {
        case requestedBy
        case requestedDate
        case reason
        case newProposedDate
        case isApproved
        case approvedDate
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
