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
        
        // Check if already clocked in today
        db.collection("clockRecords")
            .whereField("employeeId", isEqualTo: employeeId)
            .whereField("date", isEqualTo: dateString)
            .whereField("clockOutTime", isEqualTo: NSNull())
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    completion(.failure(NSError(domain: "FirestoreManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Already clocked in"])))
                    return
                }
                
                // Create new clock record
                let clockRecord = ClockRecord(
                    employeeId: employeeId,
                    employeeName: employeeName,
                    clockInTime: Date(),
                    clockOutTime: nil,
                    date: dateString
                )
                
                do {
                    let ref = try self?.db.collection("clockRecords").addDocument(from: clockRecord)
                    var recordWithId = clockRecord
                    recordWithId.id = ref?.documentID
                    completion(.success(recordWithId))
                } catch {
                    completion(.failure(error))
                }
            }
    }
    
    func clockOut(employeeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        // Find today's active clock record
        db.collection("clockRecords")
            .whereField("employeeId", isEqualTo: employeeId)
            .whereField("date", isEqualTo: dateString)
            .whereField("clockOutTime", isEqualTo: NSNull())
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion(.failure(NSError(domain: "FirestoreManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No active clock in found"])))
                    return
                }
                
                let documentId = documents[0].documentID
                self?.db.collection("clockRecords").document(documentId).updateData([
                    "clockOutTime": Timestamp(date: Date())
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
        
        db.collection("clockRecords")
            .whereField("employeeId", isEqualTo: employeeId)
            .whereField("date", isEqualTo: dateString)
            .order(by: "clockInTime", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion(.success(nil))
                    return
                }
                
                do {
                    let clockRecord = try documents[0].data(as: ClockRecord.self)
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
        
        db.collection("jobs")
            .whereField("assignedEmployeeId", isEqualTo: employeeId)
            .whereField("scheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("scheduledDate", isLessThan: Timestamp(date: endOfDay))
            .order(by: "scheduledDate")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let jobs = documents.compactMap { doc -> Job? in
                    try? doc.data(as: Job.self)
                }
                
                completion(.success(jobs))
            }
    }
    
    func getAllJobsForToday(completion: @escaping (Result<[Job], Error>) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        db.collection("jobs")
            .whereField("scheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("scheduledDate", isLessThan: Timestamp(date: endOfDay))
            .order(by: "scheduledDate")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let jobs = documents.compactMap { doc -> Job? in
                    try? doc.data(as: Job.self)
                }
                
                completion(.success(jobs))
            }
    }
    
    func updateJobStatus(jobId: String, status: JobStatus, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("jobs").document(jobId).updateData([
            "status": status.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]) { error in
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
            "rescheduleRequest.requestedBy": request.requestedBy,
            "rescheduleRequest.requestedDate": Timestamp(date: request.requestedDate),
            "rescheduleRequest.reason": request.reason,
            "status": JobStatus.rescheduled.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let newDate = newDate {
            updateData["rescheduleRequest.newProposedDate"] = Timestamp(date: newDate)
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
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        print("🔍 [FirestoreManager] Fetching currently clocked-in employees for today: \(dateString)")

        // Query timeEntries where clockOut is null (currently clocked in) and clockIn is today
        db.collection("timeEntries")
            .whereField("clockIn", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("clockIn", isLessThan: Timestamp(date: endOfDay))
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

                print("📄 [FirestoreManager] Retrieved \(documents.count) time entry document(s)")

                // Fetch employee data to get names
                self?.db.collection("employees").getDocuments { employeeSnapshot, employeeError in
                    let employeeMap = employeeSnapshot?.documents.reduce(into: [String: String]()) { result, doc in
                        result[doc.documentID] = doc.data()["name"] as? String
                    } ?? [:]

                    print("📋 [FirestoreManager] Employee map has \(employeeMap.count) entries")

                    // Filter for only currently clocked in (clockOut is null) and convert to ClockRecord
                    let records = documents.compactMap { doc -> ClockRecord? in
                        do {
                            let timeEntry = try doc.data(as: TimeEntry.self)

                            // Only include if clockOut is null (still clocked in)
                            guard timeEntry.clockOut == nil else {
                                return nil
                            }

                            guard let employeeName = employeeMap[timeEntry.employeeId] else {
                                print("⚠️ [FirestoreManager] Could not find employee name for ID: \(timeEntry.employeeId)")
                                return nil
                            }

                            print("✅ Currently clocked in: \(employeeName) - since \(timeEntry.clockIn)")

                            // Convert TimeEntry to ClockRecord
                            return ClockRecord(
                                id: timeEntry.id,
                                employeeId: timeEntry.employeeId,
                                employeeName: employeeName,
                                clockInTime: timeEntry.clockIn,
                                clockOutTime: timeEntry.clockOut,
                                date: dateString
                            )
                        } catch {
                            print("❌ [FirestoreManager] Error decoding time entry: \(error)")
                            return nil
                        }
                    }

                    print("✅ [FirestoreManager] Successfully parsed \(records.count) currently clocked-in employee(s)")
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
}

