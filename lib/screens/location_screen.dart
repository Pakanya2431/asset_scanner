import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import '../models/asset.dart';
import '../widgets/scanner_widget.dart';
import '../theme.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late String _building;
  late String _room;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final s = context.read<AppState>();
    _building = s.selectedBuilding;
    _room = s.selectedRoom;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _saveLocation() {
    if (_building.isEmpty || _room.isEmpty) return;
    context.read<AppState>().setLocation(_building, _room);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('📍 Location set: $_building · $_room'),
      backgroundColor: kGreen,
      behavior: SnackBarBehavior.floating,
    ));
    _tabs.animateTo(1);
  }

  void _handleScanResult(
      BuildContext context, AppState state, String code, ItemScanStatus? result) {
    if (result == null) {
      _snack(context, '⚠ Unknown code: $code', kAmber);
      return;
    }
    final ds = state.displayStatusFor(result);
    if (ds == ItemDisplayStatus.wrongLocation) {
      _snack(
        context,
        '⚠ ${result.item.itemName} — belongs to '
        '${result.item.building.split(" - ").first} / ${result.item.room}',
        const Color(0xFFEA580C),
        duration: const Duration(seconds: 4),
      );
    } else {
      _snack(context, '✓ ${result.item.itemName} — Found', kGreen);
    }
  }

  void _snack(BuildContext context, String msg, Color color,
      {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location Mode'),
            if (state.selectedBuilding.isNotEmpty)
              Text(
                '${state.selectedBuilding.split(" - ").first} · ${state.selectedRoom}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400),
              ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.location_on_rounded, size: 16), text: 'Set Location'),
            Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 16), text: 'Scan Here'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _LocationPickerTab(
            building: _building,
            room: _room,
            onBuildingChanged: (b, firstRoom) =>
                setState(() { _building = b; _room = firstRoom; }),
            onRoomChanged: (r) => setState(() => _room = r),
            onSave: _saveLocation,
          ),
          _ScanTab(
            onScanResult: (code, result) =>
                _handleScanResult(context, state, code, result),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Location picker with search ───────────────────────────────────────
class _LocationPickerTab extends StatefulWidget {
  final String building;
  final String room;
  final void Function(String building, String firstRoom) onBuildingChanged;
  final void Function(String room) onRoomChanged;
  final VoidCallback onSave;

  const _LocationPickerTab({
    required this.building,
    required this.room,
    required this.onBuildingChanged,
    required this.onRoomChanged,
    required this.onSave,
  });

  @override
  State<_LocationPickerTab> createState() => _LocationPickerTabState();
}

class _LocationPickerTabState extends State<_LocationPickerTab> {
  final _searchController = TextEditingController();
  String _query = '';
  // 'building' | 'room' — tracks which section user is searching
  bool _searchFocused = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allBuildings = state.buildings;
    final allRooms = widget.building.isNotEmpty
        ? state.roomsForBuilding(widget.building)
        : <String>[];

    // Filter buildings by search query
    final filteredBuildings = _query.isEmpty
        ? allBuildings
        : allBuildings
            .where((b) => b.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    // Filter rooms by search query (search across ALL buildings when query active)
    List<_RoomResult> filteredRooms = [];
    if (_query.isNotEmpty) {
      // Search all rooms in all buildings
      for (final b in allBuildings) {
        final rooms = state.roomsForBuilding(b);
        for (final r in rooms) {
          if (r.toLowerCase().contains(_query.toLowerCase()) ||
              b.toLowerCase().contains(_query.toLowerCase())) {
            filteredRooms.add(_RoomResult(building: b, room: r));
          }
        }
      }
    }

    final bool isSearching = _query.isNotEmpty;
    final bool showRoomSection =
        !isSearching && widget.building.isNotEmpty;

    return Column(
      children: [
        // ── Search bar ───────────────────────────────────────────────
        Container(
          color: kPrimary,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              // Main search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 14, color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search building or room number...',
                    hintStyle: const TextStyle(color: kTextHint, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: kTextSecondary, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: kTextSecondary, size: 18),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  ),
                ),
              ),
              // Quick room number hint
              if (_query.isEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        color: Colors.white54, size: 13),
                    const SizedBox(width: 5),
                    const Text('Type a room number e.g. "101" or building name',
                        style: TextStyle(
                            fontSize: 11, color: Colors.white60)),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Currently selected location pill ─────────────────────────
        if (widget.building.isNotEmpty && widget.room.isNotEmpty)
          Container(
            width: double.infinity,
            color: const Color(0xFFEEF3FE),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: kPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${widget.building.split(" - ").first}  ·  ${widget.room}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: kPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: widget.onSave,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text('Confirm',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),

        // ── Content ───────────────────────────────────────────────────
        Expanded(
          child: !state.hasDatabaseLoaded
              ? _empty(
                  Icons.upload_file_rounded,
                  'No database loaded',
                  'Import an Excel file first from the home screen',
                )
              : isSearching
                  ? _SearchResults(
                      query: _query,
                      buildings: filteredBuildings,
                      rooms: filteredRooms,
                      selectedBuilding: widget.building,
                      selectedRoom: widget.room,
                      state: state,
                      onSelectBuilding: (b) {
                        final rooms = state.roomsForBuilding(b);
                        widget.onBuildingChanged(
                            b, rooms.isNotEmpty ? rooms.first : '');
                        _clearSearch();
                        FocusScope.of(context).unfocus();
                      },
                      onSelectRoom: (b, r) {
                        widget.onBuildingChanged(b, r);
                        widget.onRoomChanged(r);
                        _clearSearch();
                        FocusScope.of(context).unfocus();
                      },
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Buildings
                          _sectionLabel(
                              Icons.business_rounded, 'Select Building'),
                          const SizedBox(height: 10),
                          ...allBuildings.map((b) {
                            final bItems = state.allItems
                                .where((s) => s.item.building == b);
                            final bScanned =
                                bItems.where((s) => s.isScanned).length;
                            final bTotal = bItems.length;
                            return _BuildingCard(
                              label: b,
                              selected: widget.building == b,
                              scanned: bScanned,
                              total: bTotal,
                              onTap: () {
                                final rooms = state.roomsForBuilding(b);
                                widget.onBuildingChanged(
                                    b,
                                    rooms.isNotEmpty
                                        ? rooms.first
                                        : '');
                              },
                            );
                          }),
                          const SizedBox(height: 16),
                          // Rooms
                          if (showRoomSection) ...[
                            _sectionLabel(
                                Icons.door_front_door_rounded,
                                'Select Room — ${widget.building.split(" - ").first}'),
                            const SizedBox(height: 10),
                            if (allRooms.isEmpty)
                              _hint('No rooms found'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: allRooms.map((r) {
                                final rItems = state.allItems.where((s) =>
                                    s.item.building == widget.building &&
                                    s.item.room == r);
                                final rScanned =
                                    rItems.where((s) => s.isScanned).length;
                                final rTotal = rItems.length;
                                return _RoomChip(
                                  label: r,
                                  selected: widget.room == r,
                                  scanned: rScanned,
                                  total: rTotal,
                                  onTap: () => widget.onRoomChanged(r),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
        ),

        // ── Confirm button ────────────────────────────────────────────
        if (!isSearching)
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirm & Start Scanning'),
              onPressed:
                  (widget.building.isEmpty || widget.room.isEmpty)
                      ? null
                      : widget.onSave,
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(IconData icon, String label) => Row(children: [
        Icon(icon, size: 16, color: kTextSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
        ),
      ]);

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: kTextHint)));

  Widget _empty(IconData icon, String title, String sub) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: kTextHint),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: kTextSecondary)),
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: kTextHint)),
        ]),
      );
}

// ── Search results view ───────────────────────────────────────────────────────
class _RoomResult {
  final String building;
  final String room;
  _RoomResult({required this.building, required this.room});
}

class _SearchResults extends StatelessWidget {
  final String query;
  final List<String> buildings;
  final List<_RoomResult> rooms;
  final String selectedBuilding;
  final String selectedRoom;
  final AppState state;
  final void Function(String building) onSelectBuilding;
  final void Function(String building, String room) onSelectRoom;

  const _SearchResults({
    required this.query,
    required this.buildings,
    required this.rooms,
    required this.selectedBuilding,
    required this.selectedRoom,
    required this.state,
    required this.onSelectBuilding,
    required this.onSelectRoom,
  });

  @override
  Widget build(BuildContext context) {
    final hasBuildings = buildings.isNotEmpty;
    final hasRooms = rooms.isNotEmpty;

    if (!hasBuildings && !hasRooms) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded, size: 48, color: kTextHint),
          const SizedBox(height: 10),
          Text('No results for "$query"',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: kTextSecondary)),
          const SizedBox(height: 4),
          const Text('Try a different search term',
              style: TextStyle(fontSize: 12, color: kTextHint)),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Matching buildings ─────────────────────────────────────
        if (hasBuildings) ...[
          _resultHeader(Icons.business_rounded,
              '${buildings.length} building${buildings.length > 1 ? "s" : ""}'),
          const SizedBox(height: 8),
          ...buildings.map((b) {
            final bItems =
                state.allItems.where((s) => s.item.building == b);
            final bScanned = bItems.where((s) => s.isScanned).length;
            final bTotal = bItems.length;
            return _BuildingCard(
              label: b,
              selected: selectedBuilding == b,
              scanned: bScanned,
              total: bTotal,
              onTap: () => onSelectBuilding(b),
            );
          }),
          const SizedBox(height: 16),
        ],

        // ── Matching rooms ─────────────────────────────────────────
        if (hasRooms) ...[
          _resultHeader(Icons.door_front_door_rounded,
              '${rooms.length} room${rooms.length > 1 ? "s" : ""}'),
          const SizedBox(height: 8),
          ...rooms.map((r) {
            final rItems = state.allItems.where(
                (s) => s.item.building == r.building && s.item.room == r.room);
            final rScanned = rItems.where((s) => s.isScanned).length;
            final rTotal = rItems.length;
            final isSelected =
                selectedBuilding == r.building && selectedRoom == r.room;

            return GestureDetector(
              onTap: () => onSelectRoom(r.building, r.room),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFEEF3FE)
                      : kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? kPrimary : kBorder,
                    width: isSelected ? 2 : 0.5,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kPrimary
                          : const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.door_front_door_rounded,
                        size: 18,
                        color: isSelected ? Colors.white : kTextSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.room,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? kPrimary
                                    : kTextPrimary)),
                        Text(r.building,
                            style: const TextStyle(
                                fontSize: 11,
                                color: kTextSecondary)),
                      ],
                    ),
                  ),
                  // Progress
                  if (rTotal > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$rScanned/$rTotal',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? kPrimary
                                    : kTextSecondary)),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 60,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: rTotal == 0
                                  ? 0
                                  : rScanned / rTotal,
                              minHeight: 4,
                              backgroundColor:
                                  const Color(0xFFE5E7EB),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                rScanned == rTotal
                                    ? kGreen
                                    : rScanned > 0
                                        ? kAmber
                                        : kGrayText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded,
                        color: kPrimary, size: 20),
                  ],
                ]),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _resultHeader(IconData icon, String label) => Row(children: [
        Icon(icon, size: 14, color: kTextSecondary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kTextSecondary)),
      ]);
}

// ── Tab 1: Scan in this location ──────────────────────────────────────────────
class _ScanTab extends StatelessWidget {
  final void Function(String code, ItemScanStatus? result) onScanResult;
  const _ScanTab({required this.onScanResult});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final locationItems = state.itemsForCurrentLocation;
    final missingCount = locationItems
        .where((i) => state.displayStatusFor(i) == ItemDisplayStatus.missing)
        .length;
    final foundCount = locationItems
        .where((i) => state.displayStatusFor(i) == ItemDisplayStatus.found)
        .length;
    final wrongCount = locationItems
        .where((i) =>
            state.displayStatusFor(i) == ItemDisplayStatus.wrongLocation)
        .length;
    final timeFmt = DateFormat('hh:mm a');

    return Column(
      children: [
        ScannerWidget(compact: true, onScanResult: onScanResult),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Row(children: [
            _chip('Missing', missingCount, kRed,
                const Color(0xFFFEF2F2)),
            const SizedBox(width: 6),
            _chip('Found', foundCount, kGreen,
                const Color(0xFFF0FDF4)),
            const SizedBox(width: 6),
            _chip('Wrong', wrongCount, const Color(0xFFEA580C),
                const Color(0xFFFFF7ED)),
          ]),
        ),
        Expanded(
          child: !state.hasDatabaseLoaded
              ? _empty(Icons.upload_file_rounded, 'No database',
                  'Import Excel first')
              : locationItems.isEmpty
                  ? _empty(Icons.location_off_rounded, 'No items here',
                      'Set location in the first tab')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                      itemCount: locationItems.length,
                      itemBuilder: (_, i) {
                        final s = locationItems[i];
                        final ds = state.displayStatusFor(s);
                        return _CompactItemRow(
                            item: s,
                            displayStatus: ds,
                            timeFmt: timeFmt);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _chip(String label, int count, Color color, Color bg) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: color.withOpacity(0.3), width: 0.5),
          ),
          child: Column(children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ]),
        ),
      );

  Widget _empty(IconData icon, String title, String sub) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: kTextHint),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: kTextSecondary)),
          const SizedBox(height: 3),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: kTextHint)),
        ]),
      );
}

// ── Compact item row ──────────────────────────────────────────────────────────
class _CompactItemRow extends StatelessWidget {
  final ItemScanStatus item;
  final ItemDisplayStatus displayStatus;
  final DateFormat timeFmt;

  const _CompactItemRow(
      {required this.item,
      required this.displayStatus,
      required this.timeFmt});

  @override
  Widget build(BuildContext context) {
    late Color borderColor, bgColor, iconColor;
    late IconData iconData;
    late String badgeText;

    switch (displayStatus) {
      case ItemDisplayStatus.found:
        borderColor = const Color(0xFF86EFAC);
        bgColor = const Color(0xFFF0FDF4);
        iconColor = kGreen;
        iconData = Icons.check_circle_rounded;
        badgeText = 'Found';
        break;
      case ItemDisplayStatus.missing:
        borderColor = const Color(0xFFFCA5A5);
        bgColor = const Color(0xFFFEF2F2);
        iconColor = kRed;
        iconData = Icons.cancel_rounded;
        badgeText = 'Missing';
        break;
      case ItemDisplayStatus.wrongLocation:
        borderColor = const Color(0xFFFDBA74);
        bgColor = const Color(0xFFFFF7ED);
        iconColor = const Color(0xFFEA580C);
        iconData = Icons.swap_horiz_rounded;
        badgeText = 'Wrong Loc.';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(children: [
        Icon(iconData, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.item.itemName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(item.item.itemCode,
                  style: const TextStyle(
                      fontSize: 11, color: kTextSecondary)),
              if (displayStatus == ItemDisplayStatus.wrongLocation)
                Text(
                  'Reg: ${item.item.building.split(" - ").first}/${item.item.room}',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFFEA580C)),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(badgeText,
                  style: TextStyle(
                      fontSize: 10,
                      color: iconColor,
                      fontWeight: FontWeight.w700)),
            ),
            if (item.isScanned && item.scannedAt != null) ...[
              const SizedBox(height: 3),
              Text(timeFmt.format(item.scannedAt!),
                  style: const TextStyle(
                      fontSize: 10, color: kTextHint)),
            ],
          ],
        ),
      ]),
    );
  }
}

// ── Building card ─────────────────────────────────────────────────────────────
class _BuildingCard extends StatelessWidget {
  final String label;
  final bool selected;
  final int scanned, total;
  final VoidCallback onTap;

  const _BuildingCard({
    required this.label,
    required this.selected,
    required this.scanned,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: cardDecoration(selected: selected),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: selected ? kPrimary : kTextPrimary)),
                  if (total > 0)
                    Text('$scanned / $total items scanned',
                        style: const TextStyle(
                            fontSize: 11, color: kTextSecondary)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: kPrimary, size: 20),
          ]),
        ),
      );
}

// ── Room chip ─────────────────────────────────────────────────────────────────
class _RoomChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int scanned, total;
  final VoidCallback onTap;

  const _RoomChip({
    required this.label,
    required this.selected,
    required this.scanned,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor = kGrayText;
    if (total > 0) {
      if (scanned == total)
        dotColor = kGreen;
      else if (scanned > 0)
        dotColor = kAmber;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimary : kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? kPrimary : kBorder,
              width: selected ? 2 : 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : kTextPrimary)),
            if (total > 0) ...[
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: selected ? Colors.white70 : dotColor,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 3),
                Text('$scanned/$total',
                    style: TextStyle(
                        fontSize: 10,
                        color: selected
                            ? Colors.white70
                            : kTextSecondary)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
