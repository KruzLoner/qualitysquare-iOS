# Quality Square - Complete Setup Guide

## 📱 App Overview

Quality Square is an employee time tracking and job management system for appliance installation teams. The app supports:

- **Employee Features**: Clock in/out, view assigned jobs, update job status, request reschedules
- **Admin Features**: Monitor employee attendance, view all jobs, track job statuses

## 🔥 Firebase Setup

### 1. Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Add an iOS app:
   - Bundle ID: Find in Xcode (Project Settings → General)
   - Download `GoogleService-Info.plist`
   - Add to Xcode project root (same folder as Swift files)

### 2. Add Firebase SDK (via Swift Package Manager)

In Xcode:
1. **File → Add Package Dependencies**
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select packages:
   - ✅ FirebaseAuth
   - ✅ FirebaseFirestore
   - ✅ FirebaseCore

### 3. Enable Authentication

1. Firebase Console → **Authentication**
2. Click "Get Started"
3. Enable **Email/Password** sign-in method

### 4. Create Firestore Database

1. Firebase Console → **Firestore Database**
2. Click "Create Database"
3. Choose **Production Mode**
4. Select your region

## 📊 Database Structure

### Collection: `admins`

Stores admin user information (linked to Firebase Authentication)

```
admins/{userId}
  ├─ email: string          // "admin@example.com"
  ├─ name: string           // "John Admin"
  └─ role: string           // "admin" (optional)
```

**Example Document:**
```
Document ID: xyz123abc (use the UID from Firebase Authentication)
Fields:
  - email: "admin@qualitysquare.com"
  - name: "John Smith"
```

**How to Create:**
1. First, create user in Authentication (see step below)
2. Copy the User UID
3. In Firestore, create collection `admins`
4. Add document with the copied UID as document ID
5. Add fields: email, name

---

### Collection: `employees`

Stores employee information and PINs

```
employees/{employeeId}
  ├─ name: string           // "Mike Johnson"
  ├─ pin: string            // "1234" or "123456"
  ├─ email: string?         // Optional
  ├─ isActive: boolean      // true
  └─ createdAt: timestamp   // Auto-generated
```

**Example Documents:**
```
Document ID: (auto-generated)
Fields:
  - name: "Mike Johnson"
  - pin: "1234"
  - email: "mike@qualitysquare.com"
  - isActive: true
  - createdAt: (current timestamp)

Document ID: (auto-generated)
Fields:
  - name: "Sarah Williams"
  - pin: "567890"
  - isActive: true
  - createdAt: (current timestamp)
```

**Important:** PINs must be stored as **strings**, not numbers!

---

### Collection: `clockRecords`

Stores daily clock in/out records

```
clockRecords/{recordId}
  ├─ employeeId: string     // Reference to employee document ID
  ├─ employeeName: string   // "Mike Johnson"
  ├─ clockInTime: timestamp // When they clocked in
  ├─ clockOutTime: timestamp? // When they clocked out (null if still clocked in)
  └─ date: string           // "2025-12-09" (for easy querying)
```

**Example Document:**
```
Document ID: (auto-generated)
Fields:
  - employeeId: "emp123"
  - employeeName: "Mike Johnson"
  - clockInTime: December 9, 2025 at 8:00:00 AM
  - clockOutTime: December 9, 2025 at 5:00:00 PM (or null if still working)
  - date: "2025-12-09"
```

**Note:** These are created automatically by the app when employees clock in/out.

---

### Collection: `jobs`

Stores job/installation assignments

```
jobs/{jobId}
  ├─ clientName: string             // "John Doe"
  ├─ clientAddress: string          // "123 Main St, City, State"
  ├─ clientPhone: string?           // "(555) 123-4567"
  ├─ jobType: string                // "Best Buy TV Install" | "Costco Install" | "3rd Party" | "Appliance Install" | "Other"
  ├─ jobDescription: string         // "Install 65\" Samsung TV"
  ├─ scheduledDate: timestamp       // December 9, 2025
  ├─ scheduledTime: string          // "2:00 PM"
  ├─ assignedEmployeeId: string     // Reference to employee document ID
  ├─ assignedEmployeeName: string   // "Mike Johnson"
  ├─ status: string                 // "Scheduled" | "In Progress" | "Completed" | "Rescheduled" | "Cancelled"
  ├─ notes: string?                 // Optional notes
  ├─ createdAt: timestamp           // When job was created
  ├─ updatedAt: timestamp           // Last updated
  └─ rescheduleRequest: map?        // Optional reschedule request
       ├─ requestedBy: string       // Employee name
       ├─ requestedDate: timestamp  // When requested
       ├─ reason: string            // Why reschedule
       ├─ newProposedDate: timestamp?
       └─ isApproved: boolean?      // null = pending, true/false = approved/declined
```

**Example Document:**
```
Document ID: (auto-generated or manual)
Fields:
  - clientName: "John Doe"
  - clientAddress: "123 Main Street, Los Angeles, CA"
  - clientPhone: "(555) 123-4567"
  - jobType: "Best Buy TV Install"
  - jobDescription: "Install 65\" Samsung TV with wall mount and soundbar"
  - scheduledDate: December 9, 2025 at 2:00:00 PM
  - scheduledTime: "2:00 PM"
  - assignedEmployeeId: "emp123"
  - assignedEmployeeName: "Mike Johnson"
  - status: "Scheduled"
  - notes: "Customer prefers corner wall mount"
  - createdAt: December 8, 2025 at 10:00:00 AM
  - updatedAt: December 8, 2025 at 10:00:00 AM
```

**Job Types Available:**
- "Best Buy TV Install"
- "Costco Install"
- "3rd Party"
- "Appliance Install"
- "Other"

**Status Types:**
- "Scheduled" - Job is scheduled
- "In Progress" - Employee is working on it
- "Completed" - Job finished
- "Rescheduled" - Needs to be rescheduled
- "Cancelled" - Job cancelled

---

## 🔒 Firestore Security Rules

In Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Admin users can read their own document
    match /admins/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
    }
    
    // Anyone can read employees (for PIN login)
    // Admins can read all employees
    match /employees/{employeeId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Clock records - employees can create/update their own, admins can read all
    match /clockRecords/{recordId} {
      allow read: if request.auth != null;
      allow create: if true; // Allow for PIN login
      allow update: if true; // Allow clock out
    }
    
    // Jobs - employees can read their assigned jobs, admins can read all
    match /jobs/{jobId} {
      allow read: if true;
      allow write: if request.auth != null; // Only authenticated users can modify
    }
  }
}
```

**For Development/Testing (More Permissive):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

⚠️ **Security Warning:** The permissive rules are for testing only! Use proper rules in production.

---

## 👤 Creating Users

### Create Admin User:

1. **Firebase Console → Authentication → Add User**
   - Email: `admin@qualitysquare.com`
   - Password: (create secure password)
   - Copy the generated **User UID**

2. **Firestore Database → admins collection**
   - Click "Add Document"
   - Document ID: (paste the User UID from step 1)
   - Add fields:
     ```
     email: "admin@qualitysquare.com"
     name: "Admin Name"
     ```

### Create Employee User:

**Firestore Database → employees collection**
- Click "Add Document"
- Document ID: (auto-generate)
- Add fields:
  ```
  name: "Mike Johnson"
  pin: "1234"
  email: "mike@qualitysquare.com" (optional)
  isActive: true
  createdAt: (current timestamp)
  ```

**Important:** Store PIN as **string** (e.g., "1234"), not number (1234)

---

## 📝 Sample Data for Testing

### Sample Employee:
```
Collection: employees
Document ID: (auto-generated)
Fields:
  name: "Mike Johnson"
  pin: "1234"
  isActive: true
  createdAt: (current timestamp)
```

### Sample Job:
```
Collection: jobs
Document ID: (auto-generated)
Fields:
  clientName: "Best Buy Customer"
  clientAddress: "456 Shopping Plaza, Los Angeles, CA"
  clientPhone: "(555) 999-8888"
  jobType: "Best Buy TV Install"
  jobDescription: "Install 55\" Sony TV with soundbar"
  scheduledDate: (today's date at 2:00 PM)
  scheduledTime: "2:00 PM"
  assignedEmployeeId: (use the employee document ID from above)
  assignedEmployeeName: "Mike Johnson"
  status: "Scheduled"
  notes: "Call customer before arrival"
  createdAt: (current timestamp)
  updatedAt: (current timestamp)
```

---

## ✅ Testing Checklist

### Employee Login:
- [ ] Employee can login with PIN
- [ ] Employee dashboard shows correctly
- [ ] Clock in button works
- [ ] Clock out button works
- [ ] Today's jobs are displayed
- [ ] Can view job details
- [ ] Can update job status
- [ ] Can request reschedule

### Admin Login:
- [ ] Admin can login with email/password
- [ ] Admin dashboard shows correctly
- [ ] Can see clocked in employees
- [ ] Can see all employees
- [ ] Can view today's jobs
- [ ] Jobs are grouped by status
- [ ] Can see reschedule requests

---

## 🚀 Running the App

1. Open project in Xcode
2. Make sure `GoogleService-Info.plist` is in the project
3. Build and run (⌘R)
4. Test employee login with PIN: `1234`
5. Test admin login with email/password you created

---

## 🐛 Troubleshooting

**"No module named Firebase"**
- Ensure Firebase SDK is added via Swift Package Manager
- Clean build folder: ⇧⌘K
- Rebuild project

**"GoogleService-Info.plist not found"**
- Make sure file is in project
- Check it's added to target in File Inspector

**Admin can't login**
- Verify user exists in both Authentication AND Firestore admins collection
- Check email/password are correct
- Ensure UID matches in both places

**Employee PIN doesn't work**
- Ensure PIN is stored as string in Firestore ("1234" not 1234)
- Check employee isActive is true
- Verify PIN matches exactly

**No jobs showing**
- Check scheduledDate is today
- Verify assignedEmployeeId matches employee document ID
- Check Firestore security rules allow reading

---

## 📱 App Features

### Employee App:
✅ PIN-based login (4 or 6 digits)
✅ Clock in/out tracking
✅ View today's assigned jobs
✅ Update job status (Scheduled → In Progress → Completed)
✅ Request job reschedules with reason
✅ View job details (client info, address, time, description)

### Admin App:
✅ Email/password login
✅ Real-time employee attendance tracking
✅ View who's clocked in/out with timestamps
✅ View all employees
✅ Today's jobs overview
✅ Jobs grouped by status
✅ See reschedule requests
✅ Monitor job progress

---

## 🎨 Design Features

- Clean liquid glass theme (glassmorphism)
- Smooth animations
- Pull-to-refresh on all lists
- Haptic feedback on buttons
- Status badges with color coding
- Responsive layouts

---

Need help? Check the FIREBASE_SETUP.md file for basic Firebase connection steps!

