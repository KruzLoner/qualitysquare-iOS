# Firebase Setup Guide for Quality Square

## ✅ Completed Implementation

I've implemented a complete login system with:
- **Admin Login**: Email and password authentication
- **Employee Login**: 4 or 6 digit PIN authentication
- Beautiful UI with tab switching between Admin and Employee
- Authentication state management
- Automatic login detection
- Logout functionality

## 🔧 Steps to Complete Setup

### 1. Add Firebase SDK to Your Project

1. Open your project in Xcode
2. Go to **File → Add Package Dependencies**
3. Enter this URL: `https://github.com/firebase/firebase-ios-sdk`
4. Click "Add Package"
5. Select these Firebase products:
   - ✅ **FirebaseAuth** (Required for admin login)
   - ✅ **FirebaseFirestore** (Required for employee PIN lookup)
   - ✅ **FirebaseCore** (Already imported in code)
6. Click "Add Package"

### 2. Download GoogleService-Info.plist

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create a new one)
3. Click on the iOS icon or "Add app" button
4. Register your app with your Bundle ID:
   - Find your Bundle ID in Xcode: Select your project → Target → General tab
   - It should be something like `com.yourname.Quality-Square`
5. Download the `GoogleService-Info.plist` file
6. **Drag the file into your Xcode project**:
   - Make sure "Copy items if needed" is checked
   - Add it to the "Quality Square" target
   - Place it in the same folder as your other Swift files

### 3. Configure Firebase Database Structure

Your Firebase Firestore database should have this structure:

#### Admins Collection: `admins`
```
admins/
  {userId}/
    - email: "admin@example.com"
    - name: "Admin Name" (optional)
    - role: "admin"
```

#### Employees Collection: `employees`
```
employees/
  {employeeId}/
    - pin: "1234" or "123456" (string)
    - name: "Employee Name"
    - role: "employee"
```

### 4. Set Up Firebase Authentication

1. In Firebase Console, go to **Authentication**
2. Click "Get Started"
3. Enable **Email/Password** sign-in method
4. Add admin users:
   - Click "Add User"
   - Enter email and password
   - Copy the User UID

### 5. Create Firestore Database

1. In Firebase Console, go to **Firestore Database**
2. Click "Create Database"
3. Choose production mode (or test mode for development)
4. Select your region

### 6. Add Admin to Firestore

After creating an admin user in Authentication:
1. Go to **Firestore Database**
2. Create collection: `admins`
3. Add document with the User UID from Authentication:
   ```
   Document ID: {the-uid-from-authentication}
   Fields:
     - email: "admin@example.com"
     - name: "Admin Name"
   ```

### 7. Add Employees to Firestore

1. Go to **Firestore Database**
2. Create collection: `employees`
3. Add documents (auto-generate IDs):
   ```
   Fields:
     - pin: "1234" (as string)
     - name: "John Doe"
   ```

### 8. Configure Firestore Security Rules

In Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read their own admin document
    match /admins/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow anyone to read employees (for PIN login)
    // In production, you might want to add more restrictions
    match /employees/{employeeId} {
      allow read: if true;
    }
  }
}
```

## 🎨 Features Implemented

### Admin Login
- Email and password fields with validation
- Email format checking
- Submit on Enter key
- Loading state during authentication
- Error message display

### Employee Login
- Beautiful PIN pad interface
- Visual feedback for entered digits
- Support for both 4 and 6 digit PINs
- Auto-login when PIN is complete
- Backspace functionality
- Error handling

### Main App
- Welcome screen after login
- Display user role and information
- Logout button
- Ready for your main app features

## 📱 Files Created

1. **AuthenticationManager.swift** - Handles all authentication logic
2. **LoginView.swift** - Complete login UI with Admin/Employee tabs
3. **ContentView.swift** - Updated to show login or main app based on auth state
4. **Quality_SquareApp.swift** - Updated with Firebase configuration

## 🧪 Testing

### Test Admin Login:
1. Create an admin user in Firebase Authentication
2. Add their UID to Firestore `admins` collection
3. Use the email/password to log in

### Test Employee Login:
1. Add employee documents to Firestore with PINs
2. Enter the 4 or 6 digit PIN on the employee tab

## 🚀 Next Steps

After completing the setup:
1. Build and run the app in Xcode (⌘R)
2. Try logging in as an admin
3. Try logging in as an employee
4. You can now build your main app features in the `MainAppView`

## 📝 Notes

- PINs are stored as strings in Firestore (e.g., "1234" not 1234)
- Admin users must exist in both Authentication AND Firestore
- Employee users only need to be in Firestore
- The app will automatically redirect to login when user logs out

## 🐛 Troubleshooting

**"Module not found"**: Make sure you've added Firebase SDK via Swift Package Manager

**"GoogleService-Info.plist not found"**: Ensure the file is in your project and added to target

**Admin can't login**: Check that the user exists in both Authentication and Firestore `admins` collection

**Employee PIN doesn't work**: Verify the PIN is stored as a string in Firestore

**Build errors**: Clean build folder (⇧⌘K) and rebuild

---

Need help? Let me know if you encounter any issues!

