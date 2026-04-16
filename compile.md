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

> **Note**: If you haven't configured release signing (see below), the resulting APK will be signed with a debug key.

### 4. Build an App Bundle (for Play Store)

If you intend to upload to the Google Play Store, build an Android App Bundle (AABB):

```bash
flutter build appbundle
```

The AAB will be located at:
`<project_root>/build/app/outputs/bundle/release/app-release.aab`

## Release Signing

To build a properly signed release APK for distribution, you need to configure a keystore.

1.  **Generate a Keystore**:
    If you don't have one, generate a keystore using `keytool`:
    ```bash
    keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    ```

2.  **Create `android/key.properties`**:
    Create a file named `key.properties` in the `android/` directory with the following content:
    ```properties
    storePassword=<your-store-password>
    keyPassword=<your-key-password>
    keyAlias=upload
    storeFile=<path-to-your-keystore-file>
    ```
    *Replace the placeholders with your actual values.*

3.  **Build**:
    Now when you run `flutter build apk --release`, Gradle will use these properties to sign the APK.

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
