# iOS Build Guide

This guide covers building and running the Flutter app on an iOS Simulator or iPhone, and creating an iOS archive. The project currently targets **iOS 15.0 or later**.

> A successful build does not mean every feature is iOS-ready. In particular, notification setup and the update-check path still need iOS-specific verification. See [IOS_PORTING_GUIDE.md](./IOS_PORTING_GUIDE.md) for known feature gaps.

## Requirements

Build on macOS with:

- Xcode and its iOS platform/simulator components installed.
- Flutter and Dart installed and available on `PATH`.
- CocoaPods installed and available on `PATH`.
- An Apple ID for simulator use; an Apple Developer team and signing setup are required to install on a physical device or distribute an archive.

Verify the environment:

```sh
flutter doctor -v
xcodebuild -version
pod --version
```

Open Xcode once, accept its license, and install any requested components before building.

## First-time setup

From the repository root:

```sh
flutter pub get
cd ios
pod install
cd ..
```

The project configures Flutter to use CocoaPods for iOS plugins. Keep `flutter pub get` before `pod install` so CocoaPods sees the current Flutter plugin list. The Runner and CocoaPods targets are configured for iOS 15.

Open the **workspace**, not the project file:

```sh
open ios/Runner.xcworkspace
```

`Runner.xcodeproj` alone does not load the CocoaPods integration.

## Run on an iOS Simulator

List available simulators and Flutter devices:

```sh
xcrun simctl list devices available
flutter devices
```

Start a simulator from Xcode, or select an available simulator in Xcode. Then run from the repository root:

```sh
flutter run -d <simulator-device-id>
```

To build without launching a simulator:

```sh
flutter build ios --simulator --no-codesign
```

The generated simulator app is under `build/ios/iphonesimulator/Runner.app`.

## Run on a physical iPhone

1. Connect and trust the iPhone, enable Developer Mode if prompted, and make sure it runs iOS 15 or later.
2. Open `ios/Runner.xcworkspace` in Xcode.
3. Select the **Runner** target, then **Signing & Capabilities**.
4. Choose your Apple Developer team and use a bundle identifier that is unique and belongs to your team. The current identifier is `live.iqfareez.waktusolatmalaysia`; change it if you do not own that identifier.
5. Select the connected iPhone as the run destination and press **Run**.

Alternatively, list devices with `flutter devices` and launch using:

```sh
flutter run -d <iphone-device-id>
```

If you change the bundle identifier, make sure Firebase's iOS app configuration (`ios/Runner/GoogleService-Info.plist` and `lib/firebase_options.dart`) and any Apple capabilities are configured for the new identifier.

## Create a release build or archive

For a signed iOS build, configure the Runner signing team and provisioning in Xcode first. Then, from the repository root:

```sh
flutter build ipa --release
```

Flutter writes the IPA and archive under `build/ios/`. If you need to choose a specific export method or manage certificates/profiles, use Xcode:

1. Open `ios/Runner.xcworkspace`.
2. Select the **Runner** scheme and a generic iOS device destination.
3. Choose **Product > Archive**.
4. In Organizer, validate and distribute the archive or export it for the intended purpose.

An App Store/TestFlight upload also requires the appropriate Apple Developer account, app record, signing assets, and distribution configuration.

## Troubleshooting

### “Unable to load contents of file list … Pods-Runner-…xcfilelist”

Usually Flutter plugin metadata or CocoaPods integration is missing/out of date. From the repository root:

```sh
flutter pub get
cd ios
pod install
cd ..
```

If CocoaPods reports that a pod spec is missing or stale, retry with:

```sh
cd ios
pod install --repo-update
cd ..
```

Confirm the referenced files exist under `ios/Pods/Target Support Files/Pods-Runner/`, then reopen `Runner.xcworkspace`.

### Deployment target warning says iOS 13.0

The app's minimum target is iOS 15. Check the Runner target in Xcode and the `platform :ios` setting in `ios/Podfile`; after changing Pod settings, run `pod install` again. The checked-in Runner configurations currently set `IPHONEOS_DEPLOYMENT_TARGET` to `15.0`.

### `flutterfire: command not found`

The Xcode Crashlytics build phase invokes the FlutterFire CLI. Install it and add Pub's global executable directory to `PATH`:

```sh
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Restart Xcode after updating `PATH`, then build again.

### Signing or provisioning errors

Select your development team under **Runner > Signing & Capabilities**, use a unique bundle identifier, and allow Xcode to manage signing for development. Distribution builds need a valid distribution profile and signing identity.

### Pods fail to resolve

Check network access to CocoaPods sources, then run `pod install --repo-update` from `ios/`. If an error identifies a particular incompatible pod or deployment target, resolve that error rather than changing unrelated dependencies.

## Build verification

The following simulator build was verified in this repository:

```sh
flutter build ios --simulator --no-codesign
```
