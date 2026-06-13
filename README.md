# Mini Library Management (MLM)

A cross-platform Flutter application for a university library management system, built with a modern tech stack and real-time features.

## Features

- **Role-Based Authentication**: Secure sign-in for Students and Librarians (Admins).
- **Book Catalog & Search**: Browse the library's collection with real-time availability status.
- **Borrowing Workflow**: Students can request to borrow books, and Librarians can approve/reject requests and manage returns.
- **Real-time Chat**: Direct messaging between students and librarians for support and inquiries.
- **In-App Notifications**: Real-time alerts for borrow request status changes.
- **User Profiles**: Manage profile information and view borrowing history.

## Technology Stack

- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **Backend/Database**: Firebase Firestore
- **Authentication**: Firebase Auth
- **Storage**: Firebase Storage (for book covers, avatars)

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Dart SDK
- A Firebase project

### Setup

1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd PRM393_MLM_Project
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Setup Firebase:
   - Configure your Firebase project using the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/).
   - Run `flutterfire configure` to generate `firebase_options.dart` and the respective platform configuration files (e.g., `google-services.json` for Android, `GoogleService-Info.plist` for iOS).

4. Configure Firestore Security Rules:
   Deploy the rules found in `firestore.rules`.

5. Run the app:
   ```bash
   flutter run
   ```

## Development & Security Audit

This project has undergone a thorough production-grade audit and hardening process, which included:
- Refactoring the Chat and Profile components to enforce DRY principles (extracting shared utilities).
- Resolving N+1 Firestore query issues via stateful caching in list screens.
- Optimizing batched writes for notifications.
- Securing Firestore and Storage rules against unauthorized access.
- Implementing `.gitignore` hygiene for sensitive configuration files.

## License

This project is created for educational purposes (University Course Project).
