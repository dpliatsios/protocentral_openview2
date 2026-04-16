# Compiling OpenView 2 for Android

OpenView 2 is a Flutter-based application. Follow these steps to build the Android version (APK) from source.

## Prerequisites

1.  **Flutter SDK**: Install the latest stable version of Flutter from [flutter.dev](https://docs.flutter.dev/get-started/install).
2.  **Android SDK**: Install Android Studio and the Android SDK. Ensure you have the Android SDK Command-line Tools and Build-Tools installed.
3.  **Java Development Kit (JDK)**: Flutter requires a JDK to build Android apps. It's usually bundled with Android Studio.
4.  **Hardware**: An Android device with developer mode enabled or an Android Emulator.

## Build Steps

### 1. Setup Environment

Open your terminal and verify your Flutter installation:

```bash
flutter doctor
```

Ensure that the Android toolchain and Android Studio components are correctly configured.

### 2. Get Dependencies

Navigate to the project root directory and run:

```bash
flutter pub get
```

### 3. Build the APK

To build a release APK, run:

```bash
flutter build apk --release
```

The resulting APK will be located at:
`<project_root>/build/app/outputs/flutter-apk/app-release.apk`

### 4. Build an App Bundle (for Play Store)

If you intend to upload to the Google Play Store, build an Android App Bundle (AABB):

```bash
flutter build appbundle
```

The AAB will be located at:
`<project_root>/build/app/outputs/bundle/release/app-release.aab`

## Running on Device

To run the application directly on a connected device:

```bash
flutter run
```

Ensure your device is connected via USB and recognized by `flutter devices`.

## Troubleshooting

*   **Permissions**: If you encounter issues with Bluetooth or Internet, check `android/app/src/main/AndroidManifest.xml` for the following permissions:
    *   `android.permission.BLUETOOTH_SCAN`
    *   `android.permission.BLUETOOTH_CONNECT`
    *   `android.permission.INTERNET`
*   **Gradle Errors**: If you face Gradle-related issues, try cleaning the project:
    ```bash
    flutter clean
    flutter pub get
    ```
