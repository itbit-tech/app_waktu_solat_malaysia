# Malaysia Prayer Time App — Feature and API Guide

This document describes the existing Flutter app as implemented in the repository and provides a functional reference for a native iOS port. It is based on app version **2.14.4 (build 177)** and the `waktusolat_api_client` dependency resolved in `pubspec.lock`.

The project README says the app is not currently available on iOS. An iOS Runner target and Firebase configuration exist, but that does not mean every feature is implemented or production-ready on iOS. See [iOS porting considerations](#ios-porting-considerations).

## 1. Product overview

The app provides Malaysian prayer times by JAKIM zone. Users can select a zone manually or resolve one from their current location. The main screen shows today's prayer times and date; supporting tools include a monthly timetable, local prayer notifications, a Qibla compass, Tasbih counter, and sharing.

Supported app languages are English (`en`) and Bahasa Malaysia (`ms`). The app supports light, dark, and system theme modes.

## 2. App structure and startup

### Architecture

- Flutter UI is organized by feature under `lib/features/`.
- `provider` / `ChangeNotifier` providers own selected location, prayer data, settings, theme, locale, and update state.
- `GetStorage` persists preferences and cached responses locally.
- `waktusolat_api_client` wraps the Waktu Solat API.
- Shared utilities handle notifications, location, app startup, widgets, dates, and URL launching.
- App strings are localized through `lib/l10n/` (ARB source files: `app_en.arb`, `app_ms.arb`).

Useful entry points:

- `lib/main.dart` — startup, dependency providers, themes, localization, and home scaffold.
- `lib/shared/utils/startup_routine.dart` — Firebase, ads, timezone, notification, storage, and zone-catalog initialization.
- `lib/networking/mpt_fetch_api.dart` — prayer-time cache and monthly PDF download.
- `lib/features/prayer_time/providers/prayer_time_provider.dart` and `lib/features/prayer_time/services/prayer_time_service.dart` — prayer-time state and selectors.

### Startup sequence

1. Initialize Firebase and Google Mobile Ads.
2. Connect Flutter and uncaught asynchronous errors to Crashlytics. Analytics and Crashlytics collection are enabled only in release builds.
3. Configure the local notification timezone as `Asia/Kuala_Lumpur` and initialize the notification plugin.
4. Initialize local storage and populate defaults where values are missing.
5. Set the Waktu Solat API `User-Agent` to `<packageName>/<appVersion>`.
6. Load the cached zone catalogue and refresh it if absent or older than 72 hours.
7. Show onboarding for first launch; otherwise show the home screen.

Important defaults include zone `WLY01`, 12-hour time, optional prayer times shown, azan notification mode, 16-point prayer-time text, English except when the device locale is Malay, and light theme.

## 3. User-facing features

### Onboarding

The first-run flow lets the user:

1. Choose English or Bahasa Malaysia.
2. Set a location (GPS-assisted or manual JAKIM zone selection).
3. Choose a theme.
4. Choose notification sound: default notification, short azan, or full azan.
5. Finish setup and continue to the home screen.

The current permission and auto-start prompts are Android-oriented. The location selection step can be skipped. Onboarding completion is recorded locally.

### Home and today's prayer times

- Shows the Gregorian date, Hijri date from the prayer response, selected zone, a banner ad, prompts, and today's prayer times.
- The main displayed prayers are Fajr, Dhuhr, Asr, Maghrib, and Isha.
- Imsak, Syuruk (sunrise), and Dhuha are optional and shown by default.
- The current prayer interval is highlighted. The UI refreshes this highlight when the app resumes.
- Time format is configurable as 12-hour or 24-hour; prayer-time font size is adjustable.
- A retry action is shown if loading prayer times fails.
- A first-time coachmark introduces location, utility, and settings controls.
- The app checks for an available update on launch and can show release notes after an app version change.

### Location and zone selection

- Tapping the zone control opens a GPS-assisted confirmation dialog.
- The app requests a high-accuracy device position, calls the API to map coordinates to a JAKIM zone, and reverse-geocodes the coordinates for a readable place label.
- The user confirms the suggested zone or opens the manual selector.
- Manual selection groups the API zone catalogue by state and then presents the zones within that state.
- Selecting a zone persists its JAKIM code, updates the home-screen widget title, and marks prayer notifications for rescheduling.
- Long-pressing the home location control shows the full zone description and a shortcut to manual selection.

The selected zone, not continuous GPS, is the source of prayer times. GPS is used for zone selection and the Qibla compass.

### Monthly timetable

- Displays every day in the current month, including date, Hijri date, Imsak, Fajr, Syuruk, Dhuha, Dhuhr, Asr, Maghrib, and Isha.
- Highlights today and dims past dates.
- Optional settings control whether Hijri dates are shown, their short/full format, and whether to show the calculated last third of the night.
- The timetable initially scrolls to the current day.
- A download action fetches the JAKIM monthly PDF for the selected zone. The PDF is cached in the temporary directory for the current zone/month and can be opened or shared.

### Prayer notifications

Notification choices:

- Default system notification sound for each prayer.
- Short azan for Fajr, Dhuhr, Asr, Maghrib, and Isha.
- Full azan for those prayers, with a different Fajr sound.

Syuruk is also scheduled, but with a normal notification rather than an azan. Notification text is localized and includes the selected district/location. The app also schedules a monthly reminder at 00:05 on the first day of the next month.

Scheduling behavior:

- Schedules only prayer times later than the current time, beginning with today.
- Cancels all existing scheduled notifications before rebuilding the schedule.
- By default schedules the remaining available days in the monthly response; an advanced setting limits scheduling to seven days.
- Reschedules after a zone change or explicit request, when the month changes, or after more than two days.
- Uses the Malaysia timezone for scheduled notifications.
- Android exact-alarm permission is checked before scheduling.

Notification settings also include system notification settings, a device-specific troubleshooting page, a force-reschedule action, a schedule-limit switch, and developer test notifications.

### Qibla compass

- Requests location permission and a current location, then computes the initial great-circle bearing from the user to the Kaaba (21.422487° N, 39.826206° E).
- Reads device compass heading, shows the turn needed to face Qibla, and provides sensor-accuracy/calibration guidance.
- Gives location-service, permission, and no-compass-sensor states with retry/settings actions.
- Reverse-geocodes the position for a location label and warns when the country is not Malaysia.
- Provides an initial accuracy/use disclaimer, shown once.
- Pauses compass updates when the app is backgrounded and resumes them when active.
- Triggers haptic feedback when aligned within 2 degrees; alignment is re-armed after the heading moves at least 5 degrees away.

### Tasbih

- Tap or swipe down to increment the counter; increments provide light haptic feedback.
- Counter and selected bead color persist locally.
- Users can select a bead color design and reset the count after confirmation.

### Sharing

Today's prayer times can be:

- Shared as localized plain text through the system share sheet.
- Shared with WhatsApp-specific formatting.
- Copied to the clipboard.
- Rendered as one of two image-card designs and shared as an image.

Shared text includes date, district/state, Hijri date, the five main prayers, and an app website link. It follows the chosen 12/24-hour preference.

### Settings, themes, feedback, and updates

- Settings: time format, optional prayer display, prayer font size, app language, notification options, and app/about information.
- Themes: system, light, and dark.
- Feedback: required message, optional email, optional device information (checked by default), and app metadata. Recent GPS coordinates are included only when the user explicitly opts in to additional sensitive data. A question without an email prompts the user before sending.
- Update screen: shows release title, published date, latest/current version, and a store link.
- “Rate” opens the Android Play Store listing; the web app, support site, privacy policy, changelog, and GitHub are external links.
- Review prompt is considered on the tenth launch if the platform review API is available.
- A banner ad is shown on the home screen unless a local ten-minute ad suppression window is active.

### Android home-screen widget and quick actions

The prayer-time service saves the month's prayer data, a location title, and an update timestamp for home-screen widgets named `SolatHorizontalWidget` and `SolatVerticalWidget`. The app also registers quick actions from the home screen. These are native integrations and need explicit iOS widget/shortcut equivalents if they are in scope for the port.

## 4. Backend and external API contract

### Waktu Solat API

Base URL: `https://api.waktusolat.app`

The app uses the `waktusolat_api_client` Dart package. The app's current calls and corresponding HTTP operations are:

| Purpose | HTTP request | Called by |
|---|---|---|
| Current month's prayer data for selected zone | `GET /v2/solat/{zone}?year={year}&month={month}` | Home prayer-time load and monthly timetable |
| All Malaysian JAKIM zones | `GET /zones` | Manual zone selector/catalogue |
| Determine JAKIM zone from coordinates | `GET /zones/{latitude}/{longitude}` | GPS-assisted zone selection |
| Monthly JAKIM timetable PDF | `GET /jadual_solat/{zone}?year={year}&month={month}` (`Accept: application/pdf`) | Monthly timetable export |

`year` and `month` are set by the app to the device's current Gregorian year/month. Zone codes are JAKIM codes such as `WLY01` and `SGR01`. The catalogue response is a JSON array with `jakimCode`, `negeri` (state), and `daerah` (covered area). GPS lookup returns `zone`, `state`, and `district`; the app uses `zone` and native reverse-geocoding for the user-facing label.

The prayer response model is:

```json
{
  "zone": "WLY01",
  "year": 2026,
  "month": "November",
  "month_number": 11,
  "last_updated": "optional server value",
  "prayers": [
    {
      "day": 1,
      "hijri": "1448-05-20",
      "imsak": 1793,
      "fajr": 1793,
      "syuruk": 1793,
      "dhuha": 1793,
      "dhuhr": 1793,
      "asr": 1793,
      "maghrib": 1793,
      "isha": 1793
    }
  ]
}
```

The numeric prayer-time values are Unix epoch **seconds** (the SDK converts them to dates). The numbers above are placeholders, not actual timetable values. Hijri dates are serialized as `YYYY-MM-DD`; the client formats them into full or abbreviated Hijri names.

### App-side caching and API errors

- Prayer responses are cached in local storage using a key composed of a cache-prefix, zone, year, and month. Cache hits are returned without a network request. There is no time-based expiry; changing the prefix is the existing cache-bust mechanism.
- A cache hit emits the Firebase Analytics event `api_fetch` with `type=cached`. The API wrapper itself does not emit a corresponding network-success event.
- Zone catalogues are cached separately for 72 hours. The app validates non-empty fields and unique zone codes before saving. A failed refresh retains an existing cache; without cached data the selector exposes a retry state.
- Monthly PDF files are stored in the temporary directory with zone/year/month in the filename and reused if still present.
- The API client throws for non-success/empty-body responses. Prayer loading exposes an error/retry state; the PDF flow shows an export error.

The client dependency is Git-based, with resolved revision recorded in `pubspec.lock`. The maintained API reference is [api.waktusolat.app/docs](https://api.waktusolat.app/docs); the zone catalogue is also available at [api.waktusolat.app/zones](https://api.waktusolat.app/zones).

### Feedback service

Base URL: `https://feedback.waktusolat.app/api/send`

The app sends a JSON `POST` with:

```json
{
  "message": "Required user message",
  "email": "optional@example.com",
  "app_info": {
    "App version": "app version",
    "App build number": "build number",
    "zone": "WLY01",
    "app locale": "en"
  },
  "device_info": {
    "Android version": "OS release",
    "Android Sdk": 35,
    "Device": "device identifier",
    "Brand": "device brand",
    "Model": "device model",
    "Supported ABIs": ["arm64-v8a"],
    "Screen Sizes": "screen dimensions",
    "Timezone": "+08:00",
    "Device Locale": "en_MY"
  },
  "additional_info": {
    "Recent GPS": "latitude,longitude"
  },
  "platform_info": {
    "platform": "Flutter",
    "channel": "Flutter channel",
    "version": "Flutter version",
    "dart_sdk": "Dart version"
  }
}
```

`device_info` contains Android release/SDK, device/brand/model, supported ABIs, screen size, timezone offset, and device locale. It is included only when the device-info checkbox (checked by default) remains selected. The current view-model calls `androidInfo`; an iOS implementation must supply iOS-appropriate metadata or omit this optional field. `additional_info` currently contains the most recently acquired GPS latitude/longitude (or null values if no position has been acquired) and is included only after explicit user opt-in. App metadata and platform information are included by the current implementation. The service does not parse a response body or explicitly validate the HTTP status; consider defining a stable response/error contract when reimplementing this endpoint.

### Version-check service

`GET https://waktusolat.app/check_version.json`

The response is currently Android-only:

```json
{
  "android": {
    "tag": "release tag",
    "releaseTitle": "release title",
    "version": "app version",
    "buildNumber": 177,
    "publishedAt": "ISO-8601 timestamp"
  }
}
```

The current app compares the installed Android build number with `android.buildNumber` and skips the check below Android SDK 23. `getUpdateInfo()` reads the same response for the update screen. There is no iOS version/build field or App Store update check in the current implementation.

### Other network-backed resources

- Mosque background images in the monthly timetable are fetched from network URLs constructed by `MosqueBackgroundImages`.
- Reverse geocoding is performed through the platform geocoding plugin, not the Waktu Solat API.
- No authenticated user account or sign-in flow is used by the app's core prayer-time features.

## 5. Persisted state and derived behavior

The storage implementation uses local key/value storage. Main persisted values include:

| Category | Stored values |
|---|---|
| First run and preferences | First-run flag, locale, theme, 12/24-hour format, optional prayer visibility, prayer font size |
| Location | Selected JAKIM zone code, human-readable widget location |
| Notifications | Sound type, prompt dismissal, reschedule flag, last schedule timestamp, seven-day limit |
| Timetable | Hijri visibility/style and last-third-of-night visibility |
| Qibla and onboarding | Disclaimer shown, coachmark shown |
| Tasbih | Count and selected bead color |
| Caches | Prayer response per zone/year/month; zone catalogue and successful-fetch timestamp |

For an iOS implementation, preserve user preferences and selected zone across upgrades. Cached prayer data can be treated as replaceable data; current cache keys have a manually versioned prefix.

## 6. iOS porting considerations

The repository already includes `ios/Runner`, Firebase iOS configuration, and CocoaPods dependencies, but feature behavior is not yet fully wired for iOS.

### Location permission and usage description

- `ios/Runner/Info.plist` includes `NSLocationWhenInUseUsageDescription` for the existing foreground location flows. The app requests location only when the user invokes GPS zone selection or Qibla; it does not need background or Always location access. Preserve manual zone selection when permission is denied.
- Explain the distinction between device location used locally for zone/Qibla and the optional feedback GPS field.
- Test denied, restricted, and location-services-off states on real iOS devices as well as simulators.

### Notifications and azan audio

- The notification initializer constructs `DarwinInitializationSettings`, but its source contains a TODO for completing iOS setup.
- Scheduled notification details are currently Android-only. Darwin notification details, authorization requests, sound selection, categories, and tap behavior need implementation and testing on iOS.
- Android exact-alarm permission and auto-start flows do not apply on iOS. Replace those screens with the correct iOS notification authorization/settings behavior rather than carrying over Android-specific wording.
- iOS local notifications are subject to system scheduling limits and user Focus/Silent settings; do not promise Android-style exact alarm behavior.
- Custom notification sounds must be bundled in the iOS app and conform to Apple notification sound constraints. Current azan sounds are referred to as Android raw resources; inspect available/licensed source audio and package iOS-compatible files explicitly.
- Verify timezone changes, daylight-saving behavior, schedule refresh, monthly reminder, and rescheduling after app updates or device reboot.

### Compass, haptics, and lifecycle

- Verify the selected compass package uses an iOS heading source and exposes a meaningful accuracy value on supported devices.
- Confirm magnetic-heading calibration guidance and north reference match the iOS sensor behavior.
- Preserve lifecycle pausing/resuming so heading streams do not remain active in the background.
- Test device haptics and a no-sensor fallback; simulators may not provide compass readings.

### Widgets, shortcuts, ads, Firebase, and app review

- iOS includes WidgetKit horizontal and vertical prayer-time widgets backed by the `group.live.iqfareez.waktusolatmalaysia` App Group. The app writes monthly prayer data and refreshes both widget timelines after fetching prayer times. WidgetKit refresh timing is best-effort; exact prayer notifications remain separate from widget updates.
- The App Group must be enabled for both the Runner and `SolatWidgetExtension` identifiers in the Apple Developer account and included in both provisioning profiles for signed device builds.
- Reimplement or omit the current quick actions after checking which user-visible shortcuts should exist on iOS.
- The iOS Runner has a Google Mobile Ads application identifier, but the banner code uses one hard-coded ad-unit ID. Confirm it is an iOS ad unit and that consent/privacy configuration and App Store disclosures are correct.
- Firebase iOS configuration exists in `ios/Runner/GoogleService-Info.plist` and `lib/firebase_options.dart`; verify bundle ID, signing, Crashlytics symbol upload, Analytics configuration, and release behavior in the target Firebase project.
- The “rate” action points to Google Play. Use an App Store listing/review action for iOS, and avoid using the Android-only check-version result to present an iOS update.
- Add iOS build/version and store links to a version-check contract if in-app iOS update notices are required.

### Sharing, files, and UI

- Use the native iOS share sheet for text, images, and PDFs; confirm temporary-file lifetime and file URL handling.
- Verify PDF open/share behavior using iOS document/preview controllers rather than assuming Android file-opening behavior.
- Test dynamic type, VoiceOver labels, safe areas, orientation, and dark mode. Most content is localized, though some labels and developer-oriented strings are hard-coded.
- Decide whether to retain tablet/landscape layouts; the existing Flutter UI supports wider layouts in several features.

## 7. Suggested iOS port acceptance checklist

- [ ] First-run defaults, language/theme choice, and persisted settings match current behavior.
- [ ] Manual zone selection works offline when a valid zone catalogue is cached.
- [ ] GPS lookup handles all permission and failure states and selects the correct JAKIM zone.
- [ ] iOS home-screen widgets show the selected zone's current prayer times and update after a zone or prayer-data refresh.
- [ ] Today's and monthly prayer responses parse correctly, including epoch seconds and Hijri dates.
- [ ] Cache behavior does not show stale data across zones or months; refresh and error states are explicit.
- [ ] Prayer-time display honors locale, 12/24-hour preference, optional rows, current-prayer highlight, and text size.
- [ ] PDF export is cached and can be previewed/shared on iOS.
- [ ] Local notifications request authorization correctly, use supported sounds, and reschedule after zone/month/settings changes.
- [ ] Qibla bearing, sensor error, accuracy, lifecycle, haptic feedback, and location privacy are tested on physical hardware.
- [ ] Tasbih counter/color persistence and all share targets work.
- [ ] Feedback consent and transmitted fields match the behavior documented above.
- [ ] Version checking and rate/review actions use iOS build metadata and App Store destinations.
- [ ] Decide explicitly whether to ship iOS home widgets, shortcuts, ads, and review prompts.

## 8. Source map

| Area | Main source paths |
|---|---|
| App/startup | `lib/main.dart`, `lib/shared/utils/startup_routine.dart` |
| API/cache | `lib/networking/mpt_fetch_api.dart`, `lib/shared/services/prayer_zone_catalog.dart` |
| Prayer times | `lib/features/prayer_time/`, `lib/features/home/views/home_page.dart` |
| Zones/location | `lib/features/prayer_zone/`, `lib/shared/services/location_service/location_data.dart` |
| Notifications | `lib/shared/services/notification_services/`, `lib/views/settings/notification_page_setting.dart` |
| Timetable/PDF | `lib/features/monthly_timetable/` |
| Qibla | `lib/features/kompas_kiblat/` |
| Sharing | `lib/features/sharing/` |
| Settings/themes | `lib/views/settings/`, `lib/features/theme_options/`, `lib/providers/` |
| Feedback/update | `lib/features/feedback/`, `lib/features/check_updates/` |
| iOS native setup | `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`, `ios/Runner/GoogleService-Info.plist` |
