# IoT MasterChef — Mobile Application

A **Flutter** app for wireless temperature monitoring while grilling or barbecuing. The probe sends data over **Bluetooth Low Energy**; the app plots the temperature in real‑time and notifies you (sound + push) when the target value is reached.

---

## Features

* **BLE scanning & pairing** with any sensor that advertises the *Environmental Sensing* service (UUID `181A`) and *Temperature* characteristic (UUID `2A6E`).
* **Live temperature chart** with a rolling 5‑minute window.
* **Circular progress indicator** – current / target temperature.
* **Product presets** with recommended core temperatures for steak, chicken, etc.
* **Manual target input** (0 – 1200 °C).
* **Local notifications & sound** when the threshold is reached.
* "**About**" screen with project information.

---

## Screenshots *(todo)*

> Add a couple of emulator/device screenshots here when available.

---

## Quick Start

```bash
# 1 Clone the repository (the mobileApp module is already inside)
$ git clone https://github.com/Keeeeet/IoTMasterChefProject.git
$ cd IoTMasterChefProject/mobileApp

# 2 Install dependencies
$ flutter pub get

# 3 Run on a connected device / emulator
$ flutter run
```

> **Requirements**: Flutter ≥ 3.19 (Dart ≥ 3.3), Android SDK 33+ or Xcode 14+ for iOS builds. The target device must support Bluetooth LE.

### Build a release APK (Android)

```bash
flutter build apk --release
```

### Android permissions

`android/app/src/main/AndroidManifest.xml` already contains:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

The system will prompt the user for these permissions on first launch.

---

## Project Structure

```
lib/
├── main.dart                    # entry point, notification setup
├── home_screen.dart             # main screen, chart, threshold logic
├── ble_scan_screen.dart         # BLE device discovery & selection
├── product_selection_screen.dart# preset selection dialog
└── developer_info_screen.dart   # "About" screen
assets/
└── beep.mp3                     # alert sound
android/ios/...                  # native Flutter wrappers
```

Everything else is generated and ignored (`build/`, `.dart_tool/`, etc.).

---

## Dependencies (excerpt from `pubspec.yaml`)

* `flutter_reactive_ble` — BLE scanning & subscriptions
* `flutter_local_notifications` — local notifications
* `fl_chart` — chart rendering
* `percent_indicator` — circular progress
* `audioplayers` — plays `beep.mp3`
* `permission_handler` — runtime permission requests

---

## License

Distributed under the **MIT License**. See the `LICENSE` file for details.
