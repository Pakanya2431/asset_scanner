class ImportedItem {
  final String itemCode;
  final String itemName;
  final String building;
  final String room;

  ImportedItem({
    required this.itemCode,
    required this.itemName,
    required this.building,
    required this.room,
  });

  String get locationKey => '$building||$room';
}

/// Describes WHY an item has a particular display status in the current room
enum ItemDisplayStatus {
  /// Item belongs here AND has been scanned here — green
  found,
  /// Item belongs here AND has NOT been scanned yet — red (missing)
  missing,
  /// Item was scanned in THIS room but its registered location is DIFFERENT — orange remark
  wrongLocation,
}

class ItemScanStatus {
  final ImportedItem item;
  bool isScanned;
  DateTime? scannedAt;
  String? scanMode;
  /// The building where the item was actually scanned (may differ from item.building)
  String? scannedBuilding;
  /// The room where the item was actually scanned (may differ from item.room)
  String? scannedRoom;

  ItemScanStatus({required this.item}) : isScanned = false;

  void markScanned({
    required String mode,
    required String building,
    required String room,
  }) {
    isScanned = true;
    scannedAt = DateTime.now();
    scanMode = mode;
    scannedBuilding = building;
    scannedRoom = room;
  }

  /// True when the item was scanned somewhere other than its registered location
  bool get isWrongLocation =>
      isScanned &&
      (scannedBuilding != item.building || scannedRoom != item.room);
}

/// An item scanned in the current location that is NOT in the database at all
class UnexpectedAsset {
  final String id;
  final String code;
  final String building;
  final String room;
  final DateTime scannedAt;
  final String scanMode;

  UnexpectedAsset({
    required this.id,
    required this.code,
    required this.building,
    required this.room,
    required this.scannedAt,
    required this.scanMode,
  });
}

class RoomProgress {
  final String building;
  final String room;
  final int scanned;
  final int total;
  final int wrongLocation;

  RoomProgress({
    required this.building,
    required this.room,
    required this.scanned,
    required this.total,
    this.wrongLocation = 0,
  });

  double get percent => total == 0 ? 0 : scanned / total;

  String get status {
    if (total == 0 || scanned == 0) return 'Not Started';
    if (scanned >= total) return 'Completed';
    return 'In Progress';
  }
}
