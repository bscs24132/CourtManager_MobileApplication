## Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform mobile framework |
| **Dart** | Programming language |
| **Firebase Realtime Database** | Real-time data synchronization |
| **Firebase Cloud Messaging** | Push notifications |
| **Firebase Authentication** | User authentication |
| **Material Design** | UI/UX design system |
| **Android Studio** | Development environment |

---

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   └── models.dart                    # Data models (Case, Judge, Lawyer, Manager)
├── screens/
│   ├── login_screen.dart              # Authentication screen
│   ├── lawyer_home_screen.dart        # Lawyer dashboard
│   ├── judges_list_screen.dart        # List of all judges
│   ├── cases_list_screen.dart         # Cases for specific judge (paginated)
│   ├── lawyer_cases_screen.dart       # All cases for logged-in lawyer
│   └── manager_home_screen.dart       # Manager dashboard with drag-drop
└── services/
    └── notification_service.dart      # FCM & local notifications

android/
├── app/
│   ├── google-services.json           # Firebase configuration
│   └── src/main/AndroidManifest.xml   # Android permissions
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.0 or higher)
- Dart SDK (3.0 or higher)
- Android Studio or VS Code
- Firebase account
- Android device or emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/bscs24132/CourtManager_MobileApplication.git
   cd courtroom-manager
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add an Android app to your Firebase project
   - Download `google-services.json` and place it in `android/app/`
   - Enable Realtime Database and Cloud Messaging

4. **Configure Firebase Database**
   - Import the database structure from `firebase_structure.json`
   - Update Firebase Realtime Database rules:
   ```json
   {
     "rules": {
       "lawyers": { ".read": true, ".write": true },
       "managers": { ".read": true, ".write": true },
       "judges": { ".read": true, ".write": true },
       "cases": {
         ".read": true,
         ".write": true,
         ".indexOn": ["judgeId", "lawyerId", "orderIndex"]
       }
     }
   }
   ```

5. **Run the app**
   ```bash
   flutter run
   ```


- Email: bscs24132@itu.edu.pk

Check the documentaions doc for more info
