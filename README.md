# e_secret_tracker

E-Secret Tracker Flutter app with Firebase Email/Password authentication.

## Firebase Auth Setup

1. Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
2. Add your Android app:
	- Use your package name from `android/app/build.gradle.kts` (`applicationId`).
	- Download `google-services.json` and place it at `android/app/google-services.json`.
3. Add your iOS app:
	- Use your iOS bundle ID from Xcode project settings.
	- Download `GoogleService-Info.plist` and place it at `ios/Runner/GoogleService-Info.plist`.
4. In Firebase Console, open Authentication -> Sign-in method -> enable `Email/Password`.
5. Run:

```bash
flutter pub get
flutter run
```

## User Data Isolation

- User profile records are stored at `users/{uid}` in Firestore.
- Geofence zones are stored at `users/{uid}/geofence_zones`.
- Deploy the rules in [firestore.rules](firestore.rules) so users can only read and write their own data.

## Password Reset (No Blaze Required)

This app uses the standard Firebase Authentication password reset flow (email reset link), which works on the free Spark plan.

1. In Firebase Console, go to Authentication -> Templates -> Password reset.
2. Customize the email template text (sender name, subject, body) as needed.
3. In the app, users tap Forgot Password and enter their email.
4. Firebase sends them a secure reset link.

## Implemented Auth Features

- Sign in with email and password.
- Register account with email and password.
- Password reset by email link (Firebase built-in).
- Session-aware app startup (opens home when authenticated).
- Sign out from Settings.

## Mapbox Dashboard Setup

The Home dashboard now includes a Mapbox map and a Start Tracking button.
The dashboard map defaults to the user's current location (falls back to a preset coordinate if location is unavailable).

1. Create a public access token in your Mapbox account (starts with `pk.`).
2. Create a secret token in Mapbox with `Downloads:Read` scope (starts with `sk.`).
3. Copy `android/gradle.properties.example` to `android/gradle.properties`, then set:

```properties
MAPBOX_DOWNLOADS_TOKEN=YOUR_MAPBOX_SECRET_TOKEN
```

The local `android/gradle.properties` file is ignored by Git so the secret token
is not published.

4. Install dependencies:

```bash
flutter pub get
```

5. Run the app with the public token:

```bash
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_PUBLIC_TOKEN
```

No Mapbox token is embedded in the source. Without `MAPBOX_ACCESS_TOKEN`, the app shows a message card in place of the map.

### Avoid typing token every time

1. Open `dart_defines.json` and set your token once:

```json
{
	"MAPBOX_ACCESS_TOKEN": "YOUR_MAPBOX_PUBLIC_TOKEN"
}
```

2. Run using the file:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

3. Build release with the same file:

```bash
flutter build apk --release --dart-define-from-file=dart_defines.json
```

You can also use the prepared VS Code launch configs in `.vscode/launch.json`.

## Android Release Build

The Android release build is configured to read signing values from `android/key.properties`.

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Fill in your release keystore path, alias, and passwords.
3. Build the App Bundle for Google Play:

```bash
flutter build appbundle --release --dart-define-from-file=dart_defines.json
```

If `android/key.properties` is missing, release builds will stop with a clear error instead of silently using the debug key.

## Geofence Pin Workflow

When adding a geofence zone:

1. Tap **Add New Zone**.
2. In the map picker, tap the map to place/move the pin.
3. The tapped latitude/longitude becomes the geofence center.
4. Fill required info like zone name and radius, then save.

Saved zones now include center coordinates (`centerLatitude`, `centerLongitude`) in Firestore.
