# SchoolPay Ethiopia — Parent & Teacher Mobile App

A Flutter mobile app that lets parents track and pay school fees, and lets teachers manage attendance and grades — the mobile companion to the [SchoolPay Ethiopia backend](https://github.com/) (Django/React).

Built for Android, iOS, Windows, and Web from a single Flutter codebase.

## What this app does

**For parents:**
- View a child's outstanding fees, payment history, and deadlines
- Pay via bank transfer or Telebirr and upload a receipt photo for AI-assisted verification
- View and download digital receipts
- Receive account info via OTP login (no password to remember)

**For teachers:**
- Log in securely via OTP
- Take attendance
- Enter and review exam marks (including homeroom review)

## Architecture

This app is a pure client — all data lives on and is verified by the SchoolPay Ethiopia Django backend, hosted at:
```
https://felege-selam-payment-system.onrender.com/api
```

### Project structure

```
lib/
├── main.dart                  # App entry point
├── models/                    # Payment, Student data models
├── services/
│   ├── api_service.dart       # Backend API client
│   ├── language_service.dart  # Amharic/English toggle
│   └── native_http_client.dart
├── screens/
│   ├── login_screen.dart
│   ├── otp_screen.dart
│   ├── dashboard_screen.dart
│   ├── enter_student_id_screen.dart
│   ├── upload_slip_modal.dart
│   ├── bank_transfer_modal.dart
│   ├── receipt_screen.dart
│   └── teacher/                # Teacher-only screens
│       ├── teacher_login_screen.dart
│       ├── teacher_otp_screen.dart
│       ├── teacher_home_screen.dart
│       ├── attendance_screen.dart
│       ├── mark_entry_screen.dart
│       └── homeroom_review_screen.dart
└── widgets/                    # Reusable UI components
```

## Tech stack

- **Framework:** Flutter (Dart), SDK ^3.0.0
- **State management:** Provider
- **Key packages:** `http`, `shared_preferences`, `image_picker`, `email_validator`, `intl`, `url_launcher`, `shimmer`
- **Backend:** Django REST API (SchoolPay Ethiopia)

## Getting started

```bash
flutter pub get
flutter run
```

To target a specific platform:
```bash
flutter run -d chrome     # Web
flutter run -d windows    # Windows desktop
flutter run -d <device>   # Android/iOS
```

## Localization

Supports English and Amharic via `lib/l10n/app_strings.dart` and a toggle widget (`language_toggle.dart`) — reflecting the app's use in Ethiopian schools.

## Status

Functional and connected to a live backend deployment. Actively developed alongside the SchoolPay Ethiopia web platform.

## Author

Robel Alemayehu Bekele  — Founder & Lead Developer
