//
//  FirestoreManager.swift
//  Quality Square
//
//  Created by Saba on 12/8/25.
//

import Foundation
import FirebaseFirestore
import Combine

class FirestoreManager: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Clock In/Out
    
    func clockIn(employeeId: String, employeeName: String, completion: @escaping (Result<ClockRecord, Error>) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        // Prevent duplicate active entries
        db.collection("timeEntries")
            .whereField("employeeId", isEqualTo: employeeId)
            .whereField("clockOut", isEqualTo: NSNull())
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let documents = snapshot?.documents, !documents.isEmpty {
                    completion(.failure(NSError(domain: "FirestoreManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Already clocked in"])))
                    return
                }

                let now = Date()
                let entryData: [String: Any] = [
                    "employeeId": employeeId,
                    "clockIn": Timestamp(date: now),
                    "clockOut": NSNull(),
                    "duration": NSNull(),
                    "payPeriodId": "unassigned"
                ]

                self?.db.collection("timeEntries").addDocument(data: entryData) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    let record = ClockRecord(
                        employeeId: employeeId,
                        employeeName: employeeName,
                        clockInTime: now,
                        clockOutTime: nil,
                        date: dateString
                    )
                    completion(.success(record))
                }
            }
    }
    
    func clockOut(employeeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Find active time entry
        db.collection("timeEntries")
            .whereField("employeeId", isEqualTo: employeeId)
            .whereField("clockOut", isEqualTo: NSNull())
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion(.failure(NSError(domain: "FirestoreManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No active clock in found"])))
                    return
                }
                
                let now = Date()
                let clockInDate = (document.data()["clockIn"] as? Timestamp)?.dateValue() ?? now
                let durationHours = now.timeIntervalSince(clockInDate) / 3600
                
                self?.db.collection("timeEntries").document(document.documentID).updateData([
                    "clockOut": Timestamp(date: now),
                    "duration": durationHours
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
    
    func getTodayClockStatus(employeeId: String, completion: @escaping (Result<ClockRecord?, Error>) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        db.collection("timeEntries")
            .whereField("employeeId", isEqualTo: employeeId)
            .whereField("clockOut", isEqualTo: NSNull())
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion(.success(nil))
                    return
                }
                
                do {
                    let timeEntry = try document.data(as: TimeEntry.self)
                    let clockRecord = ClockRecord(
                        id: timeEntry.id,
                        employeeId: timeEntry.employeeId,
                        employeeName: "",
                        clockInTime: timeEntry.clockIn,
                        clockOutTime: timeEntry.clockOut,
                        date: dateString
                    )
                    completion(.success(clockRecord))
                } catch {
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - Jobs
    
    func getEmployeeJobsForToday(employeeId: String, completion: @escaping (Result<[Job], Error>) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        fetchTeamIds(for: employeeId) { teamIds in
            // Fetch a reasonable batch and filter on the client to avoid index issues and include team jobs
            self.db.collection("jobs")
                .limit(to: 300)
                .getDocuments { snapshot, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        completion(.success([]))
                        return
                    }

                    let decodedJobs = documents.compactMap { doc -> Job? in
                        self.decodeJob(for: employeeId, teamIds: teamIds, document: doc)
                    }

                    let filteredJobs = decodedJobs.filter { job in
                        guard let scheduledDate = job.scheduledDate else { return false }
                        return scheduledDate >= startOfDay && scheduledDate < endOfDay
                    }

                    let jobs = filteredJobs.sorted { job1, job2 in
                        guard let date1 = job1.scheduledDate, let date2 = job2.scheduledDate else {
                            return false
                        }
                        return date1 < date2
                    }

                    completion(.success(jobs))
                }
        }
    }

    func getJobHistoryForEmployee(employeeId: String, completion: @escaping (Result<[Job], Error>) -> Void) {
        fetchTeamIds(for: employeeId) { teamIds in
            self.db.collection("jobs")
                .limit(to: 500)
                .getDocuments { snapshot, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        completion(.success([]))
                        return
                    }

                    let decodedJobs = documents.compactMap { doc -> Job? in
                        self.decodeJob(for: employeeId, teamIds: teamIds, document: doc)
                    }

                    let jobs = decodedJobs.sorted { job1, job2 in
                        guard let date1 = job1.scheduledDate, let date2 = job2.scheduledDate else {
                            return false
                        }
                        return date1 > date2
                    }

                    completion(.success(jobs))
                }
        }
    }
    
    func getAllJobsForToday(completion: @escaping (Result<[Job], Error>) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        db.collection("jobs")
            .limit(to: 500)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let decodedJobs = documents.compactMap { doc -> Job? in
                    self.decodeJobForAdmin(document: doc)
                }

                let filteredJobs = decodedJobs.filter { job in
                    guard let scheduledDate = job.scheduledDate else { return false }
                    return scheduledDate >= startOfDay && scheduledDate < endOfDay
                }

                let jobs = filteredJobs.sorted { job1, job2 in
                    guard let date1 = job1.scheduledDate, let date2 = job2.scheduledDate else {
                        return false
                    }
                    return date1 < date2
                }

                completion(.success(jobs))
            }
    }
    
    func getPendingRescheduleRequests(completion: @escaping (Result<[Job], Error>) -> Void) {
        db.collection("jobs")
            .limit(to: 300)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let decodedJobs = documents.compactMap { doc -> Job? in
                    self.decodeJobForAdmin(document: doc)
                }

                let pending = decodedJobs.filter {
                    if let req = $0.rescheduleRequest {
                        return req.isApproved == nil
                    }
                    return false
                }

                let sorted = pending.sorted {
                    let d1 = $0.rescheduleRequest?.newProposedDate ?? $0.rescheduleRequest?.requestedDate ?? Date.distantFuture
                    let d2 = $1.rescheduleRequest?.newProposedDate ?? $1.rescheduleRequest?.requestedDate ?? Date.distantFuture
                    return d1 < d2
                }

                completion(.success(sorted))
            }
    }
    
    func updateJobStatus(jobId: String, status: JobStatus, completion: @escaping (Result<Void, Error>) -> Void) {
        let now = Timestamp(date: Date())
        db.collection("jobs").document(jobId).updateData([
            "status": status.rawValue,
            "requests.status": status.rawValue,
            "updatedAt": now
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func approveReschedule(jobId: String, newDate: Date?, completion: @escaping (Result<Void, Error>) -> Void) {
        var updateData: [String: Any] = [
            "status": JobStatus.rescheduled.rawValue,
            "requests.status": JobStatus.rescheduled.rawValue,
            "requests.reschedule.isApproved": true,
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let date = newDate {
            updateData["installDate"] = Timestamp(date: date)
            updateData["requests.reschedule.newProposedDate"] = Timestamp(date: date)
        }
        
        db.collection("jobs").document(jobId).updateData(updateData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func requestJobReschedule(jobId: String, requestedBy: String, reason: String, newDate: Date?, completion: @escaping (Result<Void, Error>) -> Void) {
        let request = RescheduleRequest(
            requestedBy: requestedBy,
            requestedDate: Date(),
            reason: reason,
            newProposedDate: newDate,
            isApproved: nil
        )
        
        var updateData: [String: Any] = [
            "requests.reschedule.requestedBy": request.requestedBy,
            "requests.reschedule.requestedDate": Timestamp(date: request.requestedDate),
            "requests.reschedule.reason": request.reason,
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let newDate = newDate {
            updateData["requests.reschedule.newProposedDate"] = Timestamp(date: newDate)
        }
        
        db.collection("jobs").document(jobId).updateData(updateData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Admin Functions
    
    func getTodayClockedInEmployees(completion: @escaping (Result<[ClockRecord], Error>) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        print("🔍 [FirestoreManager] Fetching all currently clocked-in employees (no date filter)")

        // Query timeEntries where clockOut is null (all active clock-ins)
        db.collection("timeEntries")
            .whereField("clockOut", isEqualTo: NSNull())
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [FirestoreManager] Error fetching time entries: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirestoreManager] No documents returned from timeEntries query")
                    completion(.success([]))
                    return
                }

                print("📄 [FirestoreManager] Retrieved \(documents.count) time entry document(s) for today")

                // Fetch employee data to get names
                self?.db.collection("employees").getDocuments { employeeSnapshot, employeeError in
                    let employeeMap = employeeSnapshot?.documents.reduce(into: [String: String]()) { result, doc in
                        result[doc.documentID] = doc.data()["name"] as? String
                    } ?? [:]

                    print("📋 [FirestoreManager] Employee map has \(employeeMap.count) employee(s)")

                    // Convert TimeEntry to ClockRecord
                    var records = documents.compactMap { doc -> ClockRecord? in
                        do {
                            let timeEntry = try doc.data(as: TimeEntry.self)

                            guard let employeeName = employeeMap[timeEntry.employeeId] else {
                                print("⚠️ [FirestoreManager] Could not find employee name for ID: \(timeEntry.employeeId)")
                                return nil
                            }

                            print("✅ Currently clocked in: \(employeeName) - since \(timeEntry.clockIn)")

                            return ClockRecord(
                                id: timeEntry.id,
                                employeeId: timeEntry.employeeId,
                                employeeName: employeeName,
                                clockInTime: timeEntry.clockIn,
                                clockOutTime: nil,
                                date: dateString
                            )
                        } catch {
                            print("❌ [FirestoreManager] Error decoding time entry: \(error)")
                            return nil
                        }
                    }

                    // Sort by clock in time (most recent first)
                    records.sort { $0.clockInTime > $1.clockInTime }

                    print("✅ [FirestoreManager] Returning \(records.count) currently clocked-in employee(s)")
                    completion(.success(records))
                }
            }
    }
    
    func getAllEmployees(completion: @escaping (Result<[Employee], Error>) -> Void) {
        print("🔍 [FirestoreManager] Fetching all active employees...")

        db.collection("employees")
            .whereField("status", isEqualTo: "active")
            .order(by: "name")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreManager] Error fetching employees: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirestoreManager] No documents returned from employees query")
                    completion(.success([]))
                    return
                }

                print("📄 [FirestoreManager] Retrieved \(documents.count) employee document(s)")

                var employees: [Employee] = []
                var decodingErrors: [(documentId: String, error: Error)] = []

                for (index, doc) in documents.enumerated() {
                    do {
                        let employee = try doc.data(as: Employee.self)
                        employees.append(employee)
                        print("✅ [FirestoreManager] Successfully decoded employee \(index + 1): \(employee.name) (status: \(employee.status))")
                    } catch {
                        decodingErrors.append((documentId: doc.documentID, error: error))
                        print("⚠️ [FirestoreManager] Failed to decode employee document \(doc.documentID): \(error.localizedDescription)")
                        print("   Document data: \(doc.data())")
                    }
                }

                if !decodingErrors.isEmpty {
                    print("⚠️ [FirestoreManager] \(decodingErrors.count) document(s) failed to decode")
                }

                print("✅ [FirestoreManager] Successfully fetched \(employees.count) active employee(s)")
                completion(.success(employees))
            }
    }

    // MARK: - Teams

    func getAllTeams(completion: @escaping (Result<[Team], Error>) -> Void) {
        print("🔍 [FirestoreManager] Fetching all teams...")

        db.collection("teams")
            .order(by: "name")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreManager] Error fetching teams: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirestoreManager] No documents returned from teams query")
                    completion(.success([]))
                    return
                }

                print("📄 [FirestoreManager] Retrieved \(documents.count) team document(s)")

                let teams = documents.compactMap { doc -> Team? in
                    try? doc.data(as: Team.self)
                }

                print("✅ [FirestoreManager] Successfully fetched \(teams.count) team(s)")
                completion(.success(teams))
            }
    }

    // MARK: - Time Entries

    func getAllTimeEntries(completion: @escaping (Result<[TimeEntry], Error>) -> Void) {
        print("🔍 [FirestoreManager] Fetching all time entries...")

        db.collection("timeEntries")
            .order(by: "clockIn", descending: true)
            .limit(to: 100) // Limit to recent 100 entries
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreManager] Error fetching time entries: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirestoreManager] No documents returned from time entries query")
                    completion(.success([]))
                    return
                }

                print("📄 [FirestoreManager] Retrieved \(documents.count) time entry document(s)")

                let timeEntries = documents.compactMap { doc -> TimeEntry? in
                    try? doc.data(as: TimeEntry.self)
                }

                print("✅ [FirestoreManager] Successfully fetched \(timeEntries.count) time entry(ies)")
                completion(.success(timeEntries))
            }
    }

    func getTimeEntriesByEmployee(employeeId: String, completion: @escaping (Result<[TimeEntry], Error>) -> Void) {
        print("🔍 [FirestoreManager] Fetching time entries for employee: \(employeeId)")

        db.collection("timeEntries")
            .whereField("employeeId", isEqualTo: employeeId)
            .order(by: "clockIn", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreManager] Error fetching time entries: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirestoreManager] No documents returned")
                    completion(.success([]))
                    return
                }

                let timeEntries = documents.compactMap { doc -> TimeEntry? in
                    try? doc.data(as: TimeEntry.self)
                }

                print("✅ [FirestoreManager] Successfully fetched \(timeEntries.count) time entry(ies)")
                completion(.success(timeEntries))
            }
    }

    // MARK: - Helpers
    private func fetchTeamIds(for employeeId: String, completion: @escaping (Set<String>) -> Void) {
        db.collection("teams")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let teamIds: Set<String> = documents.reduce(into: Set<String>()) { result, doc in
                    let members = doc.data()["members"] as? [[String: Any]] ?? []
                    let isMember = members.contains { member in
                        (member["employeeId"] as? String) == employeeId
                    }
                    if isMember {
                        result.insert(doc.documentID)
                    }
                }

                completion(teamIds)
            }
    }

    func fetchTeamsForEmployee(employeeId: String, completion: @escaping ([(id: String, name: String, members: [String])]) -> Void) {
        db.collection("teams")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let teams = documents.compactMap { doc -> (String, String, [String])? in
                    let members = doc.data()["members"] as? [[String: Any]] ?? []
                    let isMember = members.contains { member in
                        (member["employeeId"] as? String) == employeeId
                    }
                    if isMember {
                        let name = doc.data()["name"] as? String ?? "Team"
                        let memberNames: [String] = members.compactMap { $0["employeeName"] as? String }
                        return (doc.documentID, name, memberNames)
                    }
                    return nil
                }
                completion(teams)
            }
    }

    // Decode flexible job schema (supports team assignments)
    private func decodeJob(for employeeId: String, teamIds: Set<String>, document: QueryDocumentSnapshot) -> Job? {
        let data = document.data()
        let requestData = data["requests"] as? [String: Any]

        let assignments = data["assignments"] as? [[String: Any]] ?? []
        var matchesEmployee = false
        var assignedEmployeeId: String?
        var assignedEmployeeName: String?
        var assignedTeamId: String?
        var assignedTeamName: String?
        var scheduledDate: Date?
        var teamMembers: [String]?

        for assignment in assignments {
            let type = assignment["type"] as? String ?? ""
            if type == "team-member", let eid = assignment["employeeId"] as? String, eid == employeeId {
                matchesEmployee = true
                assignedEmployeeId = eid
                assignedEmployeeName = assignment["employeeName"] as? String
                if let ts = assignment["date"] as? Timestamp {
                    scheduledDate = ts.dateValue()
                } else if let dateString = assignment["date"] as? String {
                    scheduledDate = parseDate(from: dateString)
                }
            } else if type == "team", let tid = assignment["teamId"] as? String, teamIds.contains(tid) {
                matchesEmployee = true
                assignedTeamId = tid
                assignedTeamName = assignment["teamName"] as? String
                if let members = assignment["teamMembers"] as? [String] {
                    teamMembers = members
                }
                if let ts = assignment["date"] as? Timestamp {
                    scheduledDate = ts.dateValue()
                } else if let dateString = assignment["date"] as? String {
                    scheduledDate = parseDate(from: dateString)
                }
            }
        }

        guard matchesEmployee else { return nil }

        var job = (try? document.data(as: Job.self)) ?? Job()
        job.id = document.documentID

        let cleanString: (String?) -> String? = { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        // Fallbacks for schedule
        if scheduledDate == nil {
            scheduledDate = extractScheduledDate(from: data)
        }
        job.scheduledDate = scheduledDate ?? job.scheduledDate
        if job.scheduledTime == nil, let scheduled = job.scheduledDate {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            job.scheduledTime = timeFormatter.string(from: scheduled)
        }

        // Populate fields the employee view relies on
        if job.timeFrame == nil || job.timeFrame?.isEmpty == true {
            job.timeFrame = cleanString(requestData?["timeFrame"] as? String) ?? cleanString(data["timeFrame"] as? String)
        }

        if job.storeCompany == nil || job.storeCompany?.isEmpty == true {
            job.storeCompany = cleanString(requestData?["storeCompany"] as? String) ?? cleanString(data["storeCompany"] as? String)
        }

        if job.pickUpAddress == nil || job.pickUpAddress?.isEmpty == true {
            job.pickUpAddress = cleanString(data["pickUpAddress"] as? String ?? data["pickupAddress"] as? String)
        }

        if job.installType == nil || job.installType?.isEmpty == true {
            job.installType = cleanString(data["installType"] as? String)
        }

        if job.doliNumber == nil || job.doliNumber?.isEmpty == true {
            job.doliNumber = cleanString(data["dolibarrId"] as? String ?? data["doliNumber"] as? String)
        }

        if job.items == nil || job.items?.isEmpty == true {
            if let list = data["items"] as? [String] {
                job.items = list.joined(separator: ", ")
            } else {
                job.items = cleanString(data["items"] as? String ?? data["item"] as? String)
            }
        }

        if job.assignedTeamMembers == nil || job.assignedTeamMembers?.isEmpty == true {
            job.assignedTeamMembers = teamMembers ?? data["teamMembers"] as? [String]
        }

        if job.clientName == nil {
            job.clientName = cleanString(data["customerName"] as? String) ?? cleanString(job.jobNumber)
        }

        if job.clientAddress == nil || job.clientAddress?.isEmpty == true {
            job.clientAddress = cleanString(data["clientAddress"] as? String)
                ?? cleanString(data["address"] as? String)
                ?? cleanString(data["location"] as? String)
        }

        if job.clientPhone == nil {
            job.clientPhone = cleanString(data["phoneNumber"] as? String)
        }

        let jobStatusRaw = cleanString(requestData?["status"] as? String) ?? cleanString(data["status"] as? String) ?? job.status?.rawValue ?? ""
        job.status = mapStatus(from: jobStatusRaw)

        job.assignedEmployeeId = assignedEmployeeId ?? job.assignedEmployeeId ?? (assignedTeamId ?? "unassigned")
        job.assignedEmployeeName = assignedEmployeeName ?? job.assignedEmployeeName ?? assignedTeamName ?? "Team Job"
        job.assignedTeamId = assignedTeamId ?? job.assignedTeamId
        job.assignedTeamName = assignedTeamName ?? job.assignedTeamName
        job.assignedTeamMembers = job.assignedTeamMembers ?? teamMembers

        return job
    }

    // Decode for admin (no membership filtering)
    private func decodeJobForAdmin(document: QueryDocumentSnapshot) -> Job? {
        let data = document.data()
        let requestData = data["requests"] as? [String: Any]

        let assignments = data["assignments"] as? [[String: Any]] ?? []
        var assignedEmployeeId: String?
        var assignedEmployeeName: String?
        var assignedTeamId: String?
        var assignedTeamName: String?
        var scheduledDate: Date?
        var teamMembers: [String]?

        if let firstAssignment = assignments.first {
            assignedEmployeeId = firstAssignment["employeeId"] as? String
            assignedEmployeeName = firstAssignment["employeeName"] as? String
            assignedTeamId = firstAssignment["teamId"] as? String
            assignedTeamName = firstAssignment["teamName"] as? String
            if let members = firstAssignment["teamMembers"] as? [String] {
                teamMembers = members
            }
            if let ts = firstAssignment["date"] as? Timestamp {
                scheduledDate = ts.dateValue()
            } else if let dateString = firstAssignment["date"] as? String {
                scheduledDate = parseDate(from: dateString)
            }
        }

        var job = (try? document.data(as: Job.self)) ?? Job()
        job.id = document.documentID

        let cleanString: (String?) -> String? = { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        // Fallbacks for schedule
        if scheduledDate == nil {
            scheduledDate = extractScheduledDate(from: data)
        }
        job.scheduledDate = scheduledDate ?? job.scheduledDate
        if job.scheduledTime == nil, let scheduled = job.scheduledDate {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            job.scheduledTime = timeFormatter.string(from: scheduled)
        }

        if job.timeFrame == nil || job.timeFrame?.isEmpty == true {
            job.timeFrame = cleanString(requestData?["timeFrame"] as? String) ?? cleanString(data["timeFrame"] as? String)
        }

        if job.storeCompany == nil || job.storeCompany?.isEmpty == true {
            job.storeCompany = cleanString(requestData?["storeCompany"] as? String) ?? cleanString(data["storeCompany"] as? String)
        }

        if job.pickUpAddress == nil || job.pickUpAddress?.isEmpty == true {
            job.pickUpAddress = cleanString(data["pickUpAddress"] as? String ?? data["pickupAddress"] as? String)
        }

        if job.installType == nil || job.installType?.isEmpty == true {
            job.installType = cleanString(data["installType"] as? String)
        }

        if job.doliNumber == nil || job.doliNumber?.isEmpty == true {
            job.doliNumber = cleanString(data["dolibarrId"] as? String ?? data["doliNumber"] as? String)
        }

        if job.items == nil || job.items?.isEmpty == true {
            if let list = data["items"] as? [String] {
                job.items = list.joined(separator: ", ")
            } else {
                job.items = cleanString(data["items"] as? String ?? data["item"] as? String)
            }
        }

        if job.assignedTeamMembers == nil || job.assignedTeamMembers?.isEmpty == true {
            job.assignedTeamMembers = teamMembers ?? data["teamMembers"] as? [String]
        }

        if job.clientName == nil {
            job.clientName = cleanString(data["customerName"] as? String) ?? cleanString(job.jobNumber)
        }

        if job.clientAddress == nil || job.clientAddress?.isEmpty == true {
            job.clientAddress = cleanString(data["clientAddress"] as? String)
                ?? cleanString(data["address"] as? String)
                ?? cleanString(data["location"] as? String)
        }

        if job.clientPhone == nil {
            job.clientPhone = cleanString(data["phoneNumber"] as? String)
        }

        let jobStatusRaw = cleanString(requestData?["status"] as? String) ?? cleanString(data["status"] as? String) ?? job.status?.rawValue ?? ""
        job.status = mapStatus(from: jobStatusRaw)

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()

        var reschedule: RescheduleRequest?
        if let rescheduleData = data["rescheduleRequest"] as? [String: Any] {
            let reason = rescheduleData["reason"] as? String ?? ""
            let requestedBy = rescheduleData["requestedBy"] as? String ?? ""
            let requestedDate = (rescheduleData["requestedDate"] as? Timestamp)?.dateValue() ?? Date()
            let newDate = (rescheduleData["newProposedDate"] as? Timestamp)?.dateValue()
            let approved = rescheduleData["isApproved"] as? Bool
            reschedule = RescheduleRequest(requestedBy: requestedBy, requestedDate: requestedDate, reason: reason, newProposedDate: newDate, isApproved: approved)
        } else if let rescheduleData = requestData?["reschedule"] as? [String: Any] {
            let reason = rescheduleData["reason"] as? String ?? ""
            let requestedBy = rescheduleData["requestedBy"] as? String ?? ""
            let requestedDate = (rescheduleData["requestedDate"] as? Timestamp)?.dateValue() ?? Date()
            let newDate = (rescheduleData["newProposedDate"] as? Timestamp)?.dateValue()
            let approved = rescheduleData["isApproved"] as? Bool
            reschedule = RescheduleRequest(requestedBy: requestedBy, requestedDate: requestedDate, reason: reason, newProposedDate: newDate, isApproved: approved)
        }

        job.createdAt = createdAt ?? job.createdAt
        job.updatedAt = updatedAt ?? job.updatedAt
        job.rescheduleRequest = reschedule ?? job.rescheduleRequest
        job.assignedEmployeeId = assignedEmployeeId ?? job.assignedEmployeeId ?? (assignedTeamId ?? "unassigned")
        job.assignedEmployeeName = assignedEmployeeName ?? job.assignedEmployeeName ?? assignedTeamName ?? "Team Job"
        job.assignedTeamId = assignedTeamId ?? job.assignedTeamId
        job.assignedTeamName = assignedTeamName ?? job.assignedTeamName
        job.assignedTeamMembers = job.assignedTeamMembers ?? teamMembers

        return job
    }

    // MARK: - Job decoding helpers
    private func parseDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private func extractScheduledDate(from data: [String: Any]) -> Date? {
        if let ts = data["installDate"] as? Timestamp {
            return ts.dateValue()
        }
        if let dateString = data["installDate"] as? String, let parsed = parseDate(from: dateString) {
            return parsed
        }
        if let ts = data["date"] as? Timestamp {
            return ts.dateValue()
        }
        if let dateString = data["date"] as? String, let parsed = parseDate(from: dateString) {
            return parsed
        }
        return nil
    }

    private func mapStatus(from raw: String) -> JobStatus {
        let normalized = raw.lowercased().replacingOccurrences(of: " ", with: "_")
        switch normalized {
        case "completed": return .completed
        case "complete": return .complete
        case "picking_up": return .pickingUp
        case "pick_up": return .pickUp
        case "en_route": return .enRoute
        case "cancelled": return .cancelled
        case "rescheduled": return .rescheduled
        case "in_progress", "delivering", "started": return .inProgress
        default: return .scheduled
        }
    }

    // MARK: - Vehicles / License Plates
    func getLicensePlates(completion: @escaping (Result<[LicensePlate], Error>) -> Void) {
        db.collection("LicensePlate")
            .order(by: "plateNum")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let plates = documents.compactMap { doc -> LicensePlate? in
                    try? doc.data(as: LicensePlate.self)
                }
                completion(.success(plates))
            }
    }

    func createLicensePlate(plateNum: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let data: [String: Any] = [
            "plateNum": plateNum,
            "available": true,
            "createdAt": Timestamp(date: Date())
        ]
        db.collection("LicensePlate").addDocument(data: data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func assignLicensePlate(plateId: String, driverId: String, driverName: String, teamId: String?, teamName: String?, teamMembers: [String]? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        var data: [String: Any] = [
            "currentDriverId": driverId,
            "currentDriverName": driverName,
            "assignedAt": Timestamp(date: Date()),
            "available": false
        ]
        if let teamId = teamId {
            data["currentTeamId"] = teamId
            data["currentTeamName"] = teamName
            data["currentTeamMembers"] = teamMembers
        }

        db.collection("LicensePlate").document(plateId).updateData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func assignLicensePlate(plate: LicensePlate, driverId: String, driverName: String, teamId: String?, teamName: String?, teamMembers: [String]? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        if let plateId = plate.id {
            assignLicensePlate(plateId: plateId, driverId: driverId, driverName: driverName, teamId: teamId, teamName: teamName, teamMembers: teamMembers, completion: completion)
            return
        }

        // Fallback: find by plate number
        db.collection("LicensePlate")
            .whereField("plateNum", isEqualTo: plate.plateNum)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let doc = snapshot?.documents.first else {
                    completion(.failure(NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Vehicle not found"])))
                    return
                }
                let plateId = doc.documentID
                self.assignLicensePlate(plateId: plateId, driverId: driverId, driverName: driverName, teamId: teamId, teamName: teamName, completion: completion)
            }
    }

    func clearLicensePlateAssignment(plateId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("LicensePlate").document(plateId).updateData([
            "currentDriverId": FieldValue.delete(),
            "currentDriverName": FieldValue.delete(),
            "currentTeamId": FieldValue.delete(),
            "currentTeamName": FieldValue.delete(),
            "assignedAt": FieldValue.delete(),
            "available": true
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
