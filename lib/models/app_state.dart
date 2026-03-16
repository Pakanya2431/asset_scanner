import 'package:flutter/foundation.dart';
import 'asset.dart';

class AppState extends ChangeNotifier {
  // ── Location ──────────────────────────────────────────────────────────────
  String selectedBuilding = '';
  String selectedRoom = '';

  // ── Scan mode ─────────────────────────────────────────────────────────────
  String activeScanMode = 'Barcode'; // 'RFID' | 'Barcode'

  // ── Database ──────────────────────────────────────────────────────────────
  final Map<String, ItemScanStatus> _database = {};
  final List<UnexpectedAsset> _unexpected = [];

  bool get hasDatabaseLoaded => _database.isNotEmpty;
  List<ItemScanStatus> get allItems => _database.values.toList();

  // ── Items for current location (sorted: missing first, then found, then wrong-location) ──
  List<ItemScanStatus> get itemsForCurrentLocation {
    // 1. Items whose registered location = current location
    final registered = _database.values
        .where((s) =>
            s.item.building == selectedBuilding &&
            s.item.room == selectedRoom)
        .toList();

    // 2. Items scanned HERE but registered ELSEWHERE (wrong-location)
    final wrongHere = _database.values
        .where((s) =>
            s.isScanned &&
            s.scannedBuilding == selectedBuilding &&
            s.scannedRoom == selectedRoom &&
            (s.item.building != selectedBuilding ||
                s.item.room != selectedRoom))
        .toList();

    // Sort registered: missing first, then found
    registered.sort((a, b) {
      if (!a.isScanned && b.isScanned) return -1;
      if (a.isScanned && !b.isScanned) return 1;
      return a.item.itemName.compareTo(b.item.itemName);
    });

    // Combine: missing + found first, wrong-location appended at end
    return [...registered, ...wrongHere];
  }

  /// Display status for an item in the CURRENT location view
  ItemDisplayStatus displayStatusFor(ItemScanStatus s) {
    // Scanned here but registered elsewhere
    if (s.isScanned &&
        s.scannedBuilding == selectedBuilding &&
        s.scannedRoom == selectedRoom &&
        (s.item.building != selectedBuilding || s.item.room != selectedRoom)) {
      return ItemDisplayStatus.wrongLocation;
    }
    if (s.isScanned) return ItemDisplayStatus.found;
    return ItemDisplayStatus.missing;
  }

  List<UnexpectedAsset> get unexpectedAssets => List.unmodifiable(_unexpected);

  // ── Wrong-location items (for report & export) ────────────────────────────
  List<ItemScanStatus> get wrongLocationItems =>
      _database.values.where((s) => s.isWrongLocation).toList();

  // ── Import ─────────────────────────────────────────────────────────────────
  void importItems(List<ImportedItem> items) {
    _database.clear();
    _unexpected.clear();
    for (final item in items) {
      _database[item.itemCode] = ItemScanStatus(item: item);
    }
    if (items.isNotEmpty && selectedBuilding.isEmpty) {
      selectedBuilding = items.first.building;
      selectedRoom = items.first.room;
    }
    notifyListeners();
  }

  // ── Scan ──────────────────────────────────────────────────────────────────
  /// Returns the ItemScanStatus if found in DB, null if completely unknown
  ItemScanStatus? registerScan(String code) {
    if (_database.containsKey(code)) {
      _database[code]!.markScanned(
        mode: activeScanMode,
        building: selectedBuilding,
        room: selectedRoom,
      );
      notifyListeners();
      return _database[code];
    } else {
      _unexpected.add(UnexpectedAsset(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        code: code,
        building: selectedBuilding,
        room: selectedRoom,
        scannedAt: DateTime.now(),
        scanMode: activeScanMode,
      ));
      notifyListeners();
      return null;
    }
  }

  void setScanMode(String mode) {
    activeScanMode = mode;
    notifyListeners();
  }

  // ── Location ──────────────────────────────────────────────────────────────
  void setLocation(String building, String room) {
    selectedBuilding = building;
    selectedRoom = room;
    notifyListeners();
  }

  // ── Buildings / Rooms ─────────────────────────────────────────────────────
  List<String> get buildings {
    final s = <String>{};
    for (final v in _database.values) s.add(v.item.building);
    return s.toList()..sort();
  }

  List<String> roomsForBuilding(String building) {
    final s = <String>{};
    for (final v in _database.values) {
      if (v.item.building == building) s.add(v.item.room);
    }
    return s.toList()..sort();
  }

  // ── Report ────────────────────────────────────────────────────────────────
  List<RoomProgress> get roomProgress {
    final Map<String, Map<String, List<ItemScanStatus>>> grouped = {};
    for (final s in _database.values) {
      grouped.putIfAbsent(s.item.building, () => {});
      grouped[s.item.building]!.putIfAbsent(s.item.room, () => []);
      grouped[s.item.building]![s.item.room]!.add(s);
    }
    final result = <RoomProgress>[];
    grouped.forEach((building, rooms) {
      rooms.forEach((room, items) {
        result.add(RoomProgress(
          building: building,
          room: room,
          scanned: items.where((i) => i.isScanned).length,
          total: items.length,
          wrongLocation: items.where((i) => i.isWrongLocation).length,
        ));
      });
    });
    result.sort((a, b) {
      final bc = a.building.compareTo(b.building);
      return bc != 0 ? bc : a.room.compareTo(b.room);
    });
    return result;
  }

  double get overallProgress {
    if (_database.isEmpty) return 0;
    final scanned = _database.values.where((s) => s.isScanned).length;
    return scanned / _database.length;
  }

  // ── Export helpers ────────────────────────────────────────────────────────
  List<ItemScanStatus> get todayScanned {
    final now = DateTime.now();
    return _database.values
        .where((s) =>
            s.isScanned &&
            s.scannedAt!.year == now.year &&
            s.scannedAt!.month == now.month &&
            s.scannedAt!.day == now.day)
        .toList();
  }

  List<ItemScanStatus> get currentLocationScanned => _database.values
      .where((s) =>
          s.item.building == selectedBuilding &&
          s.item.room == selectedRoom &&
          s.isScanned)
      .toList();

  List<ItemScanStatus> get allScanned =>
      _database.values.where((s) => s.isScanned).toList();
}
