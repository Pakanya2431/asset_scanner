# Asset Scanner — Flutter Android App

A Fixed Asset Verification System for Android with barcode/QR scanning, RFID input, Excel import/export, and room-by-room progress tracking.

## Features

| Screen | What it does |
|---|---|
| **Home** | Dashboard with 5 tiles + live scan counter badge |
| **Scan Mode** | Toggle between Barcode/QR camera scan and RFID text input. Shows all items for current location with Scanned / Pending status |
| **Location Mode** | Pick building & room (populated from imported database). Chips show per-room scan progress. Full item list with scan status |
| **Report** | Overall progress bar, Completed / In Progress / Not Started stats, room-by-room breakdown |
| **Export Data** | Export scanned assets to Excel (.xlsx) or CSV via Android share sheet |
| **Import Data** | Load asset database from Excel file (Item Code, Item Name, Building, Room) |

## Excel Import Format

Your Excel file must have these column headers (case-insensitive):

| Column     | Required | Aliases accepted                    |
|------------|----------|-------------------------------------|
| Item Code  | Yes      | itemcode, code, asset code          |
| Item Name  | Yes      | itemname, name, description         |
| Building   | Optional | building name, bldg                 |
| Room       | Optional | room name, location, room no        |

Example rows:
```
Item Code | Item Name    | Building                 | Room
AST-001   | Dell Laptop  | Building A - Main Office | Room 101
AST-002   | Office Chair | Building A - Main Office | Room 101
AST-003   | HP Printer   | Building B - Warehouse   | Room 201
```

## Setup & Run

### Prerequisites
- Flutter SDK 3.x  https://docs.flutter.dev/get-started/install
- Android Studio or VS Code with Flutter + Dart plugins
- Android device or emulator (API 21 / Android 5.0+)

### Steps

```bash
# 1. Unzip and enter folder
cd asset_scanner

# 2. Install packages
flutter pub get

# 3. Run on connected device / emulator
flutter run

# 4. Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

```
lib/
  main.dart                  Entry point
  theme.dart                 Colors, styles, shared decorations
  models/
    asset.dart               ImportedItem, ItemScanStatus, RoomProgress
    app_state.dart           ChangeNotifier — all state and business logic
  screens/
    home_screen.dart         Dashboard (5 tiles)
    scan_screen.dart         Barcode/QR camera + RFID input + item list
    location_screen.dart     Building/room picker with per-item scan status
    report_screen.dart       Progress overview
    export_screen.dart       Excel/CSV export
    import_screen.dart       Excel database import with column detection + preview

android/
  app/src/main/
    AndroidManifest.xml      Camera + storage permissions + FileProvider
    res/xml/file_paths.xml   FileProvider paths for share_plus
```

## Dependencies

| Package            | Purpose                              |
|--------------------|--------------------------------------|
| provider ^6.1.2    | State management                     |
| mobile_scanner ^5  | Barcode / QR camera scanning         |
| excel ^4.0.6       | Read and write .xlsx files           |
| file_picker ^8.1.2 | Pick Excel file from device storage  |
| path_provider ^2   | Temp directory for export files      |
| share_plus ^10     | Android share sheet                  |
| intl ^0.19         | Date formatting                      |
| permission_handler | Runtime camera permission            |
