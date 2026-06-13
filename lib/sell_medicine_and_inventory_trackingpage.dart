import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner_plus/flutter_barcode_scanner_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pharmacy_wrapper_page.dart';

// ============================================================
// InventoryListPage
// ============================================================
class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key});

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> allMedicines = [];
  List<Map<String, dynamic>> filtered = [];
  bool loading = true;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    searchController.addListener(_filter);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .order('medicine_name');
      setState(() {
        allMedicines = List<Map<String, dynamic>>.from(res);
        filtered = allMedicines;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void _filter() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filtered = allMedicines.where((m) {
        final name = (m['medicine_name'] ?? '').toString().toLowerCase();
        final generic = (m['generic_name'] ?? '').toString().toLowerCase();
        final batch = (m['batch_number'] ?? '').toString().toLowerCase();
        return name.contains(q) || generic.contains(q) || batch.contains(q);
      }).toList();
    });
  }

  Color _expiryColor(String? s) {
    if (s == null) return Colors.grey;
    final d = DateTime.tryParse(s);
    if (d == null) return Colors.grey;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.redAccent;
    if (days <= 30) return Colors.orange;
    return Colors.greenAccent;
  }

  String _expiryLabel(String? s) {
    if (s == null) return 'Expiry: N/A';
    final d = DateTime.tryParse(s);
    if (d == null) return 'Expiry: $s';
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return '⛔ EXPIRED ($s)';
    if (days == 0) return '⚠️ Expires TODAY';
    if (days <= 30) return '⚠️ Expires in $days days ($s)';
    return '✅ Expires: $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/guardianpharmapills.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.50)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.inventory_2, color: Colors.blueAccent),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Inventory & Medicine Lookup',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _load,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.blueAccent,
                      ),
                      hintText: 'Search by name, generic name, batch...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white38,
                              ),
                              onPressed: () => searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        )
                      : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.medication_outlined,
                                color: Colors.white24,
                                size: 60,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                searchController.text.isEmpty
                                    ? 'No medicines in inventory'
                                    : 'No results found',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final m = filtered[i];
                            final int qty = (m['quantity'] as int?) ?? 0;
                            final int spb = (m['strips_per_box'] as int?) ?? 10;
                            final int stripsRem =
                                (m['strips_remaining'] as int?) ?? (qty * spb);
                            final String batch =
                                m['batch_number']?.toString() ?? 'N/A';
                            final Color expColor = _expiryColor(
                              m['expiry_date']?.toString(),
                            );
                            final String mfr =
                                m['cartons']?['manufacturers']?['name']
                                    ?.toString() ??
                                'Unknown';
                            final String shelfNum =
                                m['shelf_number']?.toString() ?? '';
                            final String shelfSide =
                                m['shelf_side']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(
                                  255,
                                  255,
                                  255,
                                  0.10,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: expColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m['medicine_name'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            if ((m['generic_name'] ?? '')
                                                .isNotEmpty)
                                              Text(
                                                m['generic_name'],
                                                style: const TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            Text(
                                              '🔢 Batch: $batch',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '🏭 $mfr',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: qty > 0
                                              ? const Color.fromRGBO(
                                                  105,
                                                  240,
                                                  174,
                                                  0.15,
                                                )
                                              : const Color.fromRGBO(
                                                  255,
                                                  82,
                                                  82,
                                                  0.15,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: qty > 0
                                                ? const Color.fromRGBO(
                                                    105,
                                                    240,
                                                    174,
                                                    0.5,
                                                  )
                                                : const Color.fromRGBO(
                                                    255,
                                                    82,
                                                    82,
                                                    0.5,
                                                  ),
                                          ),
                                        ),
                                        child: Text(
                                          qty > 0
                                              ? '✅ In Stock'
                                              : '❌ Out of Stock',
                                          style: TextStyle(
                                            color: qty > 0
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(
                                    color: Colors.white12,
                                    height: 1,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _chip('📦 $qty boxes', Colors.blueAccent),
                                      _chip(
                                        '💊 $stripsRem strips remaining',
                                        Colors.tealAccent,
                                      ),
                                      if (shelfNum.isNotEmpty)
                                        _chip(
                                          '🗄️ Shelf $shelfNum',
                                          Colors.purpleAccent,
                                        ),
                                      if (shelfSide.isNotEmpty)
                                        _chip(
                                          '◀ $shelfSide ▶',
                                          Colors.cyanAccent,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: expColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: expColor.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      _expiryLabel(
                                        m['expiry_date']?.toString(),
                                      ),
                                      style: TextStyle(
                                        color: expColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

// ============================================================
// SellMedicineAndInventoryPage
// ============================================================
class SellMedicineAndInventoryPage extends StatefulWidget {
  final Map<String, dynamic>? preSelected;
  final bool openBarcode;

  const SellMedicineAndInventoryPage({
    super.key,
    this.preSelected,
    this.openBarcode = false,
  });

  @override
  State<SellMedicineAndInventoryPage> createState() =>
      _SellMedicineAndInventoryPageState();
}

class _SellMedicineAndInventoryPageState
    extends State<SellMedicineAndInventoryPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> allMedicines = [];
  List<Map<String, dynamic>> filteredMedicines = [];
  bool loadingMedicines = true;
  final searchController = TextEditingController();

  List<Map<String, dynamic>> manufacturers = [];
  bool loadingManufacturers = true;

  // ── SAFE LIMIT MAP ─────────────────────────────────────────
  // Keys are keywords found in medicine name (lowercase).
  // Values are the strip safe limit for that medicine type.
  // OTP triggers when totalStrips > safeLimit (NOT >=).
  final Map<String, int> _safeLimitsByKeyword = {
    'paracetamol': 5,
    'napa': 5,
    'sleeping': 2,
    'painkiller': 3,
    'antibiotic': 4,
  };
  static const int _defaultSafeLimit = 10;

  final List<String> _units = [
    'Tablets',
    'Syrup',
    'Powder',
    'Capsules',
    'Injection',
    'Custom',
  ];
  final List<String> _shelfSides = ['Left', 'Right', 'Middle', 'Top', 'Bottom'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadMedicines();
    _loadManufacturers();
    searchController.addListener(_filterMedicines);

    final preSelected = widget.preSelected;
    if (preSelected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSellDialog(preSelected);
      });
    }

    if (widget.openBarcode) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final code = await _scanBarcodeCamera();
        if (code != null && code.isNotEmpty) {
          searchController.text = code;
          _filterMedicines();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  // ── LOAD DATA ─────────────────────────────────────────────

  Future<void> _loadMedicines() async {
    setState(() => loadingMedicines = true);
    try {
      final res = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .order('medicine_name');
      setState(() {
        allMedicines = List<Map<String, dynamic>>.from(res);
        filteredMedicines = allMedicines;
        loadingMedicines = false;
      });
    } catch (e) {
      _error('Failed to load medicines: $e');
      setState(() => loadingMedicines = false);
    }
  }

  Future<void> _loadManufacturers() async {
    setState(() => loadingManufacturers = true);
    try {
      final res = await supabase.from('manufacturers').select().order('name');
      setState(() {
        manufacturers = List<Map<String, dynamic>>.from(res);
        loadingManufacturers = false;
      });
    } catch (e) {
      setState(() => loadingManufacturers = false);
    }
  }

  void _filterMedicines() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredMedicines = allMedicines.where((m) {
        final name = (m['medicine_name'] ?? '').toString().toLowerCase();
        final generic = (m['generic_name'] ?? '').toString().toLowerCase();
        final batch = (m['batch_number'] ?? '').toString().toLowerCase();
        final mfr = (m['cartons']?['manufacturers']?['name'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(q) ||
            generic.contains(q) ||
            batch.contains(q) ||
            mfr.contains(q);
      }).toList();
    });
  }

  Future<Map<String, dynamic>> _fetchRealCartonInfo(String medicineName) async {
    try {
      final rows = await supabase
          .from('medicine_boxes')
          .select('quantity, carton_id')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .eq('medicine_name', medicineName);

      final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
        rows,
      );

      int totalBoxes = 0;
      final Set<String> uniqueCartons = {};
      for (final row in list) {
        totalBoxes += (row['quantity'] as int?) ?? 0;
        final String cid = row['carton_id']?.toString() ?? '';
        if (cid.isNotEmpty) uniqueCartons.add(cid);
      }

      final int cartonCount = uniqueCartons.isEmpty ? 1 : uniqueCartons.length;
      final int avgBoxes = cartonCount > 0
          ? (totalBoxes / cartonCount).round()
          : totalBoxes;

      return {
        'cartonCount': cartonCount,
        'totalBoxes': totalBoxes,
        'avgBoxes': avgBoxes,
      };
    } catch (e) {
      return {'cartonCount': 1, 'totalBoxes': 0, 'avgBoxes': 0};
    }
  }

  // ── SAFE LIMIT ────────────────────────────────────────────

  int _getSafeLimit(String medicineName) {
    final name = medicineName.toLowerCase();
    for (final entry in _safeLimitsByKeyword.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return _defaultSafeLimit;
  }

  // ── CORE FIX: Convert sale quantity to total strip equivalent ──
  //
  // This is the single source of truth for OTP decisions.
  // ALL sale types are converted to strips before comparing to safeLimit.
  //
  // Formula:
  //   strip  → qty strips
  //   box    → qty × stripsPerBox strips
  //   carton → all strips currently in stock for this medicine_boxes entry
  //
  // OTP rule: requiresOtp = (totalStrips > safeLimit)   ← strictly greater than
  //           NO OTP when totalStrips == safeLimit
  //
  // Test cases (safeLimit = 5):
  //   5 strips  → 5 > 5 = false → No OTP ✅
  //   6 strips  → 6 > 5 = true  → OTP ✅
  //   1 box(10) → 10 > 5 = true  → OTP ✅
  //
  // Test cases (safeLimit = 10):
  //   10 strips  → 10 > 10 = false → No OTP ✅
  //   1 box(10)  → 10 > 10 = false → No OTP ✅
  //   11 strips  → 11 > 10 = true  → OTP ✅
  //   2 boxes(20)→ 20 > 10 = true  → OTP ✅
  int _calculateStripEquivalent({
    required String saleType,
    required int qty,
    required int stripsPerBox,
    required int totalStripsInStock,
  }) {
    if (saleType == 'strip') {
      return qty;
    } else if (saleType == 'box') {
      return qty * stripsPerBox;
    } else {
      // carton = selling all remaining strips in this medicine_boxes entry
      return totalStripsInStock;
    }
  }

  // ── HELPERS ───────────────────────────────────────────────

  bool _isExpired(String? expiryStr) {
    if (expiryStr == null) return false;
    final d = DateTime.tryParse(expiryStr);
    if (d == null) return false;
    return d.difference(DateTime.now()).inDays < 0;
  }

  Color _expiryColor(String? s) {
    if (s == null) return Colors.grey;
    final d = DateTime.tryParse(s);
    if (d == null) return Colors.grey;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.redAccent;
    if (days <= 30) return Colors.orange;
    return Colors.greenAccent;
  }

  String _expiryLabel(String? s) {
    if (s == null) return 'Expiry: N/A';
    final d = DateTime.tryParse(s);
    if (d == null) return 'Expiry: $s';
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return '⛔ EXPIRED ($s)';
    if (days == 0) return '⚠️ Expires TODAY';
    if (days <= 30) return '⚠️ Expires in $days days ($s)';
    return '✅ Expires: $s';
  }

  // ── BARCODE SCANNING ──────────────────────────────────────

  Future<String?> _scanBarcodeCamera() async {
    try {
      final String scanned = await FlutterBarcodeScanner.scanBarcode(
        '#2196F3',
        'Cancel',
        true,
        ScanMode.BARCODE,
      );
      if (scanned == '-1' || scanned.isEmpty) return null;
      return scanned;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _lookupMedicineByBarcode(
    String barcodeValue,
  ) async {
    try {
      final byBatch = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .eq('batch_number', barcodeValue)
          .limit(1);

      final List<Map<String, dynamic>> batchResults =
          List<Map<String, dynamic>>.from(byBatch);
      if (batchResults.isNotEmpty) return batchResults.first;

      final byName = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .ilike('medicine_name', '%$barcodeValue%')
          .limit(1);

      final List<Map<String, dynamic>> nameResults =
          List<Map<String, dynamic>>.from(byName);
      if (nameResults.isNotEmpty) return nameResults.first;

      return null;
    } catch (e) {
      return null;
    }
  }

  // ── SELL DIALOG ───────────────────────────────────────────

  void _showSellDialog(Map<String, dynamic> medicine) {
    if (_isExpired(medicine['expiry_date']?.toString())) {
      _error('This medicine is expired and cannot be sold.');
      return;
    }

    final int availableBoxes = (medicine['quantity'] as int?) ?? 0;
    final int stripsPerBox = (medicine['strips_per_box'] as int?) ?? 10;
    final int totalStripsAvailable =
        (medicine['strips_remaining'] as int?) ??
        (availableBoxes * stripsPerBox);

    if (availableBoxes <= 0 || totalStripsAvailable <= 0) {
      _showOutOfStockDialog(medicine);
      return;
    }

    const int availableCartons = 1;

    String saleType = 'strip';
    final qtyCtrl = TextEditingController(text: '1');
    final cartonQtyCtrl = TextEditingController(text: '1');
    final customerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final double pricePerBox =
        double.tryParse(medicine['price'].toString()) ?? 0.0;
    final double pricePerStrip = medicine['price_per_strip'] != null
        ? double.tryParse(medicine['price_per_strip'].toString()) ??
              (pricePerBox / stripsPerBox)
        : pricePerBox / stripsPerBox;

    final String medicineName = medicine['medicine_name']?.toString() ?? '';
    final String genericName = medicine['generic_name']?.toString() ?? '';
    final String batchNumber = medicine['batch_number']?.toString() ?? 'N/A';
    final String mfr =
        medicine['cartons']?['manufacturers']?['name']?.toString() ?? 'Unknown';
    final String expiry = medicine['expiry_date']?.toString() ?? 'N/A';
    final int safeLimit = _getSafeLimit(medicineName);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) {
          final double pricePerCarton = pricePerBox * availableBoxes;

          double unitPrice;
          if (saleType == 'strip') {
            unitPrice = pricePerStrip;
          } else if (saleType == 'box') {
            unitPrice = pricePerBox;
          } else {
            unitPrice = pricePerCarton;
          }

          final int enteredQty = saleType == 'carton'
              ? (int.tryParse(cartonQtyCtrl.text) ?? 1)
              : (int.tryParse(qtyCtrl.text) ?? 1);

          final double total = unitPrice * enteredQty;

          bool exceedsStock = false;
          String stockHintText = '';
          if (saleType == 'strip') {
            exceedsStock = enteredQty > totalStripsAvailable;
            stockHintText =
                'Available: $totalStripsAvailable strips ($availableBoxes boxes)';
          } else if (saleType == 'box') {
            exceedsStock = enteredQty > availableBoxes;
            stockHintText = 'Available: $availableBoxes boxes';
          } else {
            exceedsStock = enteredQty > availableCartons;
            stockHintText =
                'Available: $availableCartons carton(s) ($availableBoxes boxes total)';
          }

          // ── CORE FIX: Calculate strip equivalent for this sale ──
          // Convert entered qty to strips regardless of sale type,
          // then compare to safeLimit using strictly greater than (>).
          // This means: equal to safeLimit = NO OTP, over = OTP.
          final int stripEquivalent = _calculateStripEquivalent(
            saleType: saleType,
            qty: enteredQty,
            stripsPerBox: stripsPerBox,
            totalStripsInStock: totalStripsAvailable,
          );

          // OTP required only when stripEquivalent STRICTLY GREATER THAN safeLimit
          final bool willNeedOtp = stripEquivalent > safeLimit;

          // Debug prints (remove before production)
          debugPrint('--- OTP CHECK ---');
          debugPrint('Safe Limit: $safeLimit');
          debugPrint('Sale Type: $saleType');
          debugPrint('Entered Qty: $enteredQty');
          debugPrint('Strips Per Box: $stripsPerBox');
          debugPrint('Total Strips In Stock: $totalStripsAvailable');
          debugPrint('Strip Equivalent: $stripEquivalent');
          debugPrint('OTP Required: $willNeedOtp');
          debugPrint('-----------------');

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  medicineName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (genericName.isNotEmpty)
                  Text(
                    genericName,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _infoRow('🏭 Manufacturer', mfr),
                        _infoRow('🔢 Batch Number', batchNumber),
                        _infoRow('📅 Expiry', expiry),
                        _infoRow(
                          '📦 Stock',
                          '$availableBoxes boxes  •  $totalStripsAvailable strips',
                        ),
                        _infoRow(
                          '🏭 Cartons Available',
                          '$availableCartons carton(s)',
                        ),
                        _infoRow('💊 Strips/Box', '$stripsPerBox strips'),
                        _infoRow(
                          '💰 Price/Box',
                          'BDT ${pricePerBox.toStringAsFixed(2)}',
                        ),
                        _infoRow(
                          '💊 Price/Strip',
                          'BDT ${pricePerStrip.toStringAsFixed(2)}',
                        ),
                        _infoRow(
                          '🏭 Price/Carton',
                          'BDT ${pricePerCarton.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sell as:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _saleTypeChip(
                        'strip',
                        '💊 Strip',
                        saleType,
                        (v) => setDs(() {
                          saleType = v;
                          qtyCtrl.text = '1';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _saleTypeChip(
                        'box',
                        '📦 Box',
                        saleType,
                        (v) => setDs(() {
                          saleType = v;
                          qtyCtrl.text = '1';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _saleTypeChip(
                        'carton',
                        '🏭 Carton',
                        saleType,
                        (v) => setDs(() {
                          saleType = v;
                          cartonQtyCtrl.text = '1';
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (saleType == 'strip' || saleType == 'box') ...[
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: exceedsStock ? Colors.redAccent : Colors.white,
                      ),
                      onChanged: (_) => setDs(() {}),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.numbers,
                          color: exceedsStock
                              ? Colors.redAccent
                              : Colors.white70,
                        ),
                        hintText: 'Quantity',
                        hintStyle: const TextStyle(color: Colors.white38),
                        helperText: stockHintText,
                        helperStyle: TextStyle(
                          color: exceedsStock
                              ? Colors.redAccent
                              : Colors.white38,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: exceedsStock
                            ? const Color.fromRGBO(255, 82, 82, 0.1)
                            : const Color.fromRGBO(255, 255, 255, 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: exceedsStock
                              ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: exceedsStock
                              ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                      ),
                    ),
                    if (exceedsStock) ...[
                      const SizedBox(height: 6),
                      _stockErrorBox(
                        saleType == 'strip'
                            ? '❌ Only $totalStripsAvailable strips available ($availableBoxes boxes)'
                            : '❌ Only $availableBoxes boxes available',
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                  if (saleType == 'carton') ...[
                    TextField(
                      controller: cartonQtyCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: exceedsStock ? Colors.redAccent : Colors.white,
                      ),
                      onChanged: (_) => setDs(() {}),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.widgets,
                          color: exceedsStock
                              ? Colors.redAccent
                              : Colors.white70,
                        ),
                        hintText: 'Number of cartons',
                        hintStyle: const TextStyle(color: Colors.white38),
                        helperText: stockHintText,
                        helperStyle: TextStyle(
                          color: exceedsStock
                              ? Colors.redAccent
                              : Colors.white38,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: exceedsStock
                            ? const Color.fromRGBO(255, 82, 82, 0.1)
                            : const Color.fromRGBO(255, 255, 255, 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: exceedsStock
                              ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: exceedsStock
                              ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: exceedsStock
                            ? const Color.fromRGBO(255, 82, 82, 0.12)
                            : const Color.fromRGBO(255, 152, 0, 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: exceedsStock
                              ? const Color.fromRGBO(255, 82, 82, 0.5)
                              : const Color.fromRGBO(255, 152, 0, 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            exceedsStock
                                ? Icons.error_outline
                                : Icons.info_outline,
                            color: exceedsStock
                                ? Colors.redAccent
                                : Colors.orange,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exceedsStock
                                  ? '❌ Not enough cartons in stock.\n   Available: $availableCartons carton(s)'
                                  : '1 carton = $availableBoxes boxes ($totalStripsAvailable strips total).\nSelling clears ALL stock for this entry.',
                              style: TextStyle(
                                color: exceedsStock
                                    ? Colors.redAccent
                                    : Colors.orange,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: customerCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Colors.white70,
                      ),
                      hintText: 'Customer name (optional)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: Colors.white70,
                      ),
                      hintText: 'Customer phone (optional)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // OTP warning box — shows strip equivalent and safe limit clearly
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: willNeedOtp
                          ? const Color.fromRGBO(244, 67, 54, 0.1)
                          : const Color.fromRGBO(255, 152, 0, 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: willNeedOtp
                            ? const Color.fromRGBO(255, 82, 82, 0.4)
                            : const Color.fromRGBO(255, 152, 0, 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          willNeedOtp
                              ? Icons.lock_outline
                              : Icons.warning_amber,
                          color: willNeedOtp ? Colors.redAccent : Colors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            willNeedOtp
                                ? '⚠️ $stripEquivalent strips > safe limit of $safeLimit. OTP required!'
                                : 'Safe limit: $safeLimit strips. This sale = $stripEquivalent strip(s). OTP only if exceeded.',
                            style: TextStyle(
                              color: willNeedOtp
                                  ? Colors.redAccent
                                  : Colors.orange,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(68, 138, 255, 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromRGBO(68, 138, 255, 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'BDT ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: exceedsStock
                      ? Colors.grey
                      : Colors.greenAccent,
                ),
                icon: Icon(
                  Icons.check_circle,
                  color: exceedsStock ? Colors.white54 : Colors.black,
                  size: 18,
                ),
                label: Text(
                  'Sell',
                  style: TextStyle(
                    color: exceedsStock ? Colors.white54 : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: exceedsStock
                    ? null
                    : () async {
                        final int qty = saleType == 'carton'
                            ? (int.tryParse(cartonQtyCtrl.text) ?? 1)
                            : (int.tryParse(qtyCtrl.text) ?? 1);
                        if (qty <= 0) {
                          _error('Quantity must be at least 1');
                          return;
                        }
                        final String customer = customerCtrl.text.trim();
                        final String phone = phoneCtrl.text.trim();
                        Navigator.pop(context);

                        // ── CORE FIX: Recalculate strip equivalent at sell time ──
                        // This is the definitive OTP gate.
                        // We recalculate here (not reuse willNeedOtp from the
                        // StatefulBuilder) to ensure no stale state is used.
                        final int stripsForThisSale = _calculateStripEquivalent(
                          saleType: saleType,
                          qty: qty,
                          stripsPerBox: stripsPerBox,
                          totalStripsInStock: totalStripsAvailable,
                        );

                        // Debug prints (remove before production)
                        debugPrint('--- SELL BUTTON PRESSED ---');
                        debugPrint('Safe Limit: $safeLimit');
                        debugPrint('Sale Type: $saleType');
                        debugPrint('Qty: $qty');
                        debugPrint('Strips Per Box: $stripsPerBox');
                        debugPrint('Strips In Stock: $totalStripsAvailable');
                        debugPrint('Strip Equivalent: $stripsForThisSale');
                        debugPrint(
                          'OTP Required: ${stripsForThisSale > safeLimit}',
                        );
                        debugPrint('---------------------------');

                        // OTP triggers ONLY when strictly greater than (>), NOT >=
                        if (stripsForThisSale > safeLimit) {
                          _showHighQtyWarning(
                            medicine: medicine,
                            qty: qty,
                            saleType: saleType,
                            unitPrice: unitPrice,
                            total: total,
                            customer: customer,
                            phone: phone,
                            medicineName: medicineName,
                            batchNumber: batchNumber,
                            stripsPerBox: stripsPerBox,
                            safeLimit: safeLimit,
                            stripEquivalent: stripsForThisSale,
                          );
                        } else {
                          await _completeSale(
                            medicine: medicine,
                            saleType: saleType,
                            qty: qty,
                            unitPrice: unitPrice,
                            total: total,
                            customer: customer,
                            phone: phone,
                            medicineName: medicineName,
                            batchNumber: batchNumber,
                            stripsPerBox: stripsPerBox,
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stockErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 82, 82, 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromRGBO(255, 82, 82, 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── OUT OF STOCK ──────────────────────────────────────────

  void _showOutOfStockDialog(Map<String, dynamic> medicine) {
    final String medicineName =
        medicine['medicine_name']?.toString() ?? 'This medicine';
    final String genericName = medicine['generic_name']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.remove_circle, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'Out of Stock',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 82, 82, 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color.fromRGBO(255, 82, 82, 0.4),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.inventory_2,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    medicineName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (genericName.isNotEmpty)
                    Text(
                      genericName,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    '❌ 0 boxes  •  0 strips',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This medicine is currently out of stock.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ── HIGH QTY WARNING ──────────────────────────────────────

  void _showHighQtyWarning({
    required Map<String, dynamic> medicine,
    required int qty,
    required String saleType,
    required double unitPrice,
    required double total,
    required String customer,
    required String phone,
    required String medicineName,
    required String batchNumber,
    required int stripsPerBox,
    required int safeLimit,
    required int stripEquivalent,
  }) {
    final nameCtrl = TextEditingController(text: customer);
    final phoneCtrl2 = TextEditingController(text: phone);
    final ageCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    // Human-readable sale description for the warning message
    String saleDescription;
    if (saleType == 'strip') {
      saleDescription = '$qty strips';
    } else if (saleType == 'box') {
      saleDescription = '$qty box(es) = $stripEquivalent strips';
    } else {
      saleDescription = '1 carton = $stripEquivalent strips';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ High Quantity Detected!',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(244, 67, 54, 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 82, 82, 0.4),
                  ),
                ),
                child: Text(
                  'You are selling $saleDescription of $medicineName.\n\n'
                  'Safe limit is $safeLimit strips.\n'
                  'This sale equals $stripEquivalent strip equivalent(s).\n\n'
                  'Customer details required to proceed.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _dialogField(nameCtrl, 'Customer Full Name', Icons.person),
              const SizedBox(height: 10),
              _dialogField(
                phoneCtrl2,
                'Phone Number',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _dialogField(
                ageCtrl,
                'Age',
                Icons.cake,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _dialogField(reasonCtrl, 'Reason for Purchase', Icons.note),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel Sale',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.lock_open, color: Colors.white, size: 16),
            label: const Text(
              'Send OTP',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final ph = phoneCtrl2.text.trim();
              final age = int.tryParse(ageCtrl.text.trim()) ?? 0;
              final reason = reasonCtrl.text.trim();
              if (name.isEmpty || ph.isEmpty || reason.isEmpty) {
                _error('Please fill all required fields');
                return;
              }
              Navigator.pop(context);
              _showOtpDialog(
                medicine: medicine,
                qty: qty,
                saleType: saleType,
                unitPrice: unitPrice,
                total: total,
                customerName: name,
                phone: ph,
                age: age,
                reason: reason,
                medicineName: medicineName,
                batchNumber: batchNumber,
                stripsPerBox: stripsPerBox,
                stripEquivalent: stripEquivalent,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── OTP DIALOG ────────────────────────────────────────────

  void _showOtpDialog({
    required Map<String, dynamic> medicine,
    required int qty,
    required String saleType,
    required double unitPrice,
    required double total,
    required String customerName,
    required String phone,
    required int age,
    required String reason,
    required String medicineName,
    required String batchNumber,
    required int stripsPerBox,
    required int stripEquivalent,
  }) {
    final String generatedOtp = (100000 + Random().nextInt(900000)).toString();
    final otpCtrl = TextEditingController();
    bool otpError = false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📱 Demo OTP: $generatedOtp',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 15),
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                'OTP Verification',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(68, 138, 255, 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color.fromRGBO(68, 138, 255, 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.sms, color: Colors.blueAccent, size: 28),
                    const SizedBox(height: 8),
                    const Text(
                      'Demo OTP Sent',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      generatedOtp,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '(In real app sent via SMS)',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (_) => setDs(() => otpError = false),
                decoration: InputDecoration(
                  hintText: 'Enter OTP',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                  counterStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (otpError)
                const Text(
                  '❌ Incorrect OTP. Try again.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              icon: const Icon(Icons.check, color: Colors.white, size: 16),
              label: const Text(
                'Verify & Sell',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                if (otpCtrl.text.trim() == generatedOtp) {
                  Navigator.pop(context);
                  await _saveSuspiciousLog(
                    medicineName: medicineName,
                    batchNumber: batchNumber,
                    qty: qty,
                    customerName: customerName,
                    phone: phone,
                    age: age,
                    reason: reason,
                    stripEquivalent: stripEquivalent,
                    saleType: saleType,
                  );
                  await _completeSale(
                    medicine: medicine,
                    saleType: saleType,
                    qty: qty,
                    unitPrice: unitPrice,
                    total: total,
                    customer: customerName,
                    phone: phone,
                    medicineName: medicineName,
                    batchNumber: batchNumber,
                    stripsPerBox: stripsPerBox,
                  );
                } else {
                  setDs(() => otpError = true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── SUSPICIOUS LOG ────────────────────────────────────────

  Future<void> _saveSuspiciousLog({
    required String medicineName,
    required String batchNumber,
    required int qty,
    required String customerName,
    required String phone,
    required int age,
    required String reason,
    required int stripEquivalent,
    required String saleType,
  }) async {
    try {
      // Build a clear description showing original qty AND strip equivalent
      String saleDescription;
      if (saleType == 'strip') {
        saleDescription = '$qty strips';
      } else if (saleType == 'box') {
        saleDescription = '$qty box(es) ($stripEquivalent strip equivalents)';
      } else {
        saleDescription = '1 carton ($stripEquivalent strip equivalents)';
      }

      await supabase.from('suspicious_logs').insert({
        'pharmacy_id': PharmacySession.pharmacyId,
        'pharmacy_name': PharmacySession.pharmacyName,
        'medicine_name': medicineName,
        'batch_number': batchNumber,
        'quantity': qty,
        'activity_type': 'high_quantity_purchase',
        'description':
            '$customerName (age $age, $phone) purchased $saleDescription of $medicineName. '
            'Strip equivalent: $stripEquivalent. Reason: $reason',
        'flagged_by': 'system',
      });
    } catch (e) {
      debugPrint('Suspicious log error: $e');
    }
  }

  // ── COMPLETE SALE ─────────────────────────────────────────

  Future<void> _completeSale({
    required Map<String, dynamic> medicine,
    required String saleType,
    required int qty,
    required double unitPrice,
    required double total,
    required String customer,
    required String phone,
    required String medicineName,
    required String batchNumber,
    required int stripsPerBox,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      final String medicineId = medicine['id'].toString();
      final String cartonId = medicine['carton_id']?.toString() ?? '';

      await supabase.from('sales').insert({
        'medicine_name': medicineName,
        'batch_number': batchNumber,
        'sale_type': saleType,
        'quantity_sold': qty,
        'unit_price': unitPrice,
        'total_amount': total,
        'customer_name': customer.isEmpty ? null : customer,
        'customer_phone': phone.isEmpty ? null : phone,
        'sold_by': userId,
        'pharmacy_id': PharmacySession.pharmacyId,
      });

      final freshRow = await supabase
          .from('medicine_boxes')
          .select('quantity, strips_per_box, strips_remaining')
          .eq('id', medicineId)
          .single();

      final int currentBoxes = (freshRow['quantity'] as int?) ?? 0;
      final int spb = (freshRow['strips_per_box'] as int?) ?? stripsPerBox;
      final int currentStrips =
          (freshRow['strips_remaining'] as int?) ?? (currentBoxes * spb);

      int stripsToDeduct;
      if (saleType == 'carton') {
        stripsToDeduct = currentStrips;
      } else if (saleType == 'box') {
        stripsToDeduct = qty * spb;
      } else {
        stripsToDeduct = qty;
      }

      final int newStrips = (currentStrips - stripsToDeduct).clamp(
        0,
        currentStrips,
      );
      final int newBoxes = (spb > 0 && newStrips > 0)
          ? (newStrips / spb).ceil()
          : 0;

      if (newBoxes <= 0) {
        await supabase.from('medicine_boxes').delete().eq('id', medicineId);
      } else {
        await supabase
            .from('medicine_boxes')
            .update({'quantity': newBoxes, 'strips_remaining': newStrips})
            .eq('id', medicineId);
      }

      if (cartonId.isNotEmpty) {
        await _deleteCartonIfEmpty(cartonId);
      }

      if (!mounted) return;

      // Auto-refresh both lists after sale — no manual refresh needed
      _loadMedicines();
      _loadManufacturers();

      _showReceipt(
        medicineName: medicineName,
        batchNumber: batchNumber,
        saleType: saleType,
        qty: qty,
        unitPrice: unitPrice,
        total: total,
        customer: customer,
        phone: phone,
        newBoxes: newBoxes,
        newStrips: newStrips,
        spb: spb,
      );
    } catch (e) {
      _error('Sale failed: $e');
    }
  }

  Future<void> _deleteCartonIfEmpty(String cartonId) async {
    try {
      final remaining = await supabase
          .from('medicine_boxes')
          .select('id, quantity')
          .eq('carton_id', cartonId)
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '');

      bool hasStock = false;
      for (final box in List.from(remaining)) {
        if (((box['quantity'] as int?) ?? 0) > 0) {
          hasStock = true;
          break;
        }
      }
      if (!hasStock) {
        await supabase.from('cartons').delete().eq('id', cartonId);
      }
    } catch (e) {
      debugPrint('Carton delete check error: $e');
    }
  }

  // ── RECEIPT ───────────────────────────────────────────────

  void _showReceipt({
    required String medicineName,
    required String batchNumber,
    required String saleType,
    required int qty,
    required double unitPrice,
    required double total,
    required String customer,
    required String phone,
    required int newBoxes,
    required int newStrips,
    required int spb,
  }) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hour = now.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeStr =
        '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $period';

    final int partialStrips = (spb > 0) ? (newStrips % spb) : 0;
    final bool hasPartialBox = newBoxes > 0 && partialStrips != 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text(
              'Sale Receipt',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_pharmacy_rounded,
                color: Colors.blueAccent,
                size: 36,
              ),
              const SizedBox(height: 6),
              Text(
                PharmacySession.pharmacyName ?? 'GuardianPharma',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                '$dateStr  •  $timeStr',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (customer.isNotEmpty)
                Text(
                  'Customer: $customer',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              if (phone.isNotEmpty)
                Text(
                  '📱 $phone',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              _infoRow('💊 Medicine', medicineName),
              _infoRow('🔢 Batch', batchNumber),
              _infoRow('📦 Type', saleType.toUpperCase()),
              _infoRow('🔢 Quantity Sold', '$qty'),
              _infoRow('💰 Unit Price', 'BDT ${unitPrice.toStringAsFixed(2)}'),
              const Divider(color: Colors.white24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'BDT ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: newBoxes == 0
                      ? const Color.fromRGBO(255, 82, 82, 0.12)
                      : newBoxes <= 2
                      ? const Color.fromRGBO(255, 152, 0, 0.12)
                      : const Color.fromRGBO(76, 175, 80, 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: newBoxes == 0
                        ? const Color.fromRGBO(255, 82, 82, 0.4)
                        : newBoxes <= 2
                        ? const Color.fromRGBO(255, 152, 0, 0.4)
                        : const Color.fromRGBO(76, 175, 80, 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '📦 Remaining Stock',
                      style: TextStyle(
                        color: newBoxes == 0
                            ? Colors.redAccent
                            : newBoxes <= 2
                            ? Colors.orange
                            : Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$newBoxes boxes',
                          style: TextStyle(
                            color: newBoxes == 0
                                ? Colors.redAccent
                                : newBoxes <= 2
                                ? Colors.orange
                                : Colors.greenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.medication,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$newStrips strips remaining',
                          style: TextStyle(
                            color: newStrips == 0
                                ? Colors.redAccent
                                : newStrips <= (spb * 2)
                                ? Colors.orange
                                : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (hasPartialBox) ...[
                      const SizedBox(height: 4),
                      Text(
                        '(1 partially used box — $partialStrips strips left in it)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (newBoxes == 0) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '⚠️ OUT OF STOCK',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else if (newBoxes <= 2) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '⚠️ LOW STOCK — Reorder soon',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '✅ Sale saved & inventory auto-updated!',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Done', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── ADD / EDIT MEDICINE BOX ───────────────────────────────

  void _showMedicineBoxDialog(
    String cartonId,
    String manufacturerName, {
    Map<String, dynamic>? existing,
  }) {
    final nameCtrl = TextEditingController(
      text: existing?['medicine_name'] ?? '',
    );
    final genericCtrl = TextEditingController(
      text: existing?['generic_name'] ?? '',
    );
    final batchCtrl = TextEditingController(
      text: existing?['batch_number'] ?? '',
    );
    final expiryCtrl = TextEditingController(
      text: existing?['expiry_date'] ?? '',
    );
    final qtyCtrl = TextEditingController(
      text: existing?['quantity']?.toString() ?? '',
    );
    final priceCtrl = TextEditingController(
      text: existing?['price']?.toString() ?? '',
    );
    final stripsCtrl = TextEditingController(
      text: existing?['strips_per_box']?.toString() ?? '10',
    );
    final stripPriceCtrl = TextEditingController(
      text: existing?['price_per_strip']?.toString() ?? '',
    );
    final customUnitCtrl = TextEditingController();
    final shelfNumCtrl = TextEditingController(
      text: existing?['shelf_number']?.toString() ?? '',
    );

    String? selectedShelfSide = existing?['shelf_side']?.toString();
    String selectedUnit = existing?['unit'] ?? 'Tablets';
    bool isCustomUnit = !_units.contains(selectedUnit);
    if (isCustomUnit) {
      customUnitCtrl.text = selectedUnit;
      selectedUnit = 'Custom';
    }

    final bool isEditing = existing != null;
    final String existingId = existing?['id']?.toString() ?? '';

    bool isScanning = false;
    String scanStatusMessage = '';
    bool scanSuccess = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) {
          Future<void> handleBarcodeScan() async {
            setDs(() {
              isScanning = true;
              scanStatusMessage = '';
            });

            final String? scanned = await _scanBarcodeCamera();

            if (scanned == null || scanned.isEmpty) {
              setDs(() {
                isScanning = false;
                scanStatusMessage = '';
              });
              return;
            }

            final Map<String, dynamic>? found = await _lookupMedicineByBarcode(
              scanned,
            );

            if (found != null) {
              setDs(() {
                isScanning = false;
                scanSuccess = true;
                scanStatusMessage =
                    '✅ Medicine found! Fields auto-filled. You can still edit them.';

                if ((found['medicine_name'] ?? '').toString().isNotEmpty) {
                  nameCtrl.text = found['medicine_name'].toString();
                }
                if ((found['generic_name'] ?? '').toString().isNotEmpty) {
                  genericCtrl.text = found['generic_name'].toString();
                }
                if ((found['batch_number'] ?? '').toString().isNotEmpty) {
                  batchCtrl.text = found['batch_number'].toString();
                }
                if ((found['expiry_date'] ?? '').toString().isNotEmpty) {
                  expiryCtrl.text = found['expiry_date'].toString();
                }
                if ((found['price'] ?? '').toString().isNotEmpty) {
                  priceCtrl.text = found['price'].toString();
                }
                if ((found['strips_per_box'] ?? '').toString().isNotEmpty) {
                  stripsCtrl.text = found['strips_per_box'].toString();
                }
                if ((found['price_per_strip'] ?? '').toString().isNotEmpty) {
                  stripPriceCtrl.text = found['price_per_strip'].toString();
                }
                final String foundUnit = found['unit']?.toString() ?? '';
                if (foundUnit.isNotEmpty && _units.contains(foundUnit)) {
                  selectedUnit = foundUnit;
                  isCustomUnit = false;
                }
              });
            } else {
              setDs(() {
                isScanning = false;
                scanSuccess = false;
                scanStatusMessage =
                    '⚠️ No medicine found for this barcode.\nPlease enter details manually below.';
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Row(
              children: [
                const Icon(Icons.medication, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Medicine Box' : 'Add Medicine Box',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(105, 240, 174, 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.business,
                          color: Colors.greenAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          manufacturerName,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isScanning ? null : handleBarcodeScan,
                          icon: isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.white,
                                  size: 20,
                                ),
                          label: Text(
                            isScanning ? 'Scanning...' : '📷 Scan Barcode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (scanStatusMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scanSuccess
                            ? const Color.fromRGBO(76, 175, 80, 0.12)
                            : const Color.fromRGBO(255, 152, 0, 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: scanSuccess
                              ? const Color.fromRGBO(76, 175, 80, 0.4)
                              : const Color.fromRGBO(255, 152, 0, 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            scanSuccess
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            color: scanSuccess
                                ? Colors.greenAccent
                                : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              scanStatusMessage,
                              style: TextStyle(
                                color: scanSuccess
                                    ? Colors.greenAccent
                                    : Colors.orange,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'or enter manually',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _dialogField(nameCtrl, 'Medicine Name *', Icons.medication),
                  const SizedBox(height: 10),
                  _dialogField(
                    genericCtrl,
                    'Generic Name (e.g. Paracetamol)',
                    Icons.science_outlined,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(batchCtrl, 'Batch Number *', Icons.numbers),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expiryCtrl,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                      ),
                      hintText: 'Expiry Date *',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 30),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDs(() {
                          expiryCtrl.text =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    qtyCtrl,
                    'Quantity (boxes) *',
                    Icons.inventory,
                    isNumber: true,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    stripsCtrl,
                    'Strips per Box',
                    Icons.view_module,
                    isNumber: true,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    priceCtrl,
                    'Price per Box (BDT) *',
                    Icons.attach_money,
                    isDecimal: true,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    stripPriceCtrl,
                    'Price per Strip (BDT)',
                    Icons.money,
                    isDecimal: true,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButton<String>(
                      value: selectedUnit,
                      dropdownColor: const Color(0xFF1A1A2E),
                      underline: const SizedBox(),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white54,
                      ),
                      items: _units
                          .map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.category,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    u,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDs(() {
                        selectedUnit = v ?? selectedUnit;
                        isCustomUnit = selectedUnit == 'Custom';
                      }),
                    ),
                  ),
                  if (isCustomUnit) ...[
                    const SizedBox(height: 10),
                    _dialogField(customUnitCtrl, 'Custom Unit', Icons.edit),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(179, 136, 255, 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color.fromRGBO(179, 136, 255, 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.shelves,
                              color: Colors.purpleAccent,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Shelf Location (optional)',
                              style: TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _dialogField(
                          shelfNumCtrl,
                          'Shelf Number (e.g. A1, B2)',
                          Icons.tag,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButton<String>(
                            value: selectedShelfSide,
                            dropdownColor: const Color(0xFF1A1A2E),
                            underline: const SizedBox(),
                            isExpanded: true,
                            hint: const Text(
                              'Shelf Side (optional)',
                              style: TextStyle(color: Colors.white38),
                            ),
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white54,
                            ),
                            items: _shelfSides
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.align_horizontal_center,
                                          color: Colors.white70,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          s,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDs(() => selectedShelfSide = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final batch = batchCtrl.text.trim();
                  final expiry = expiryCtrl.text.trim();
                  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final strips = int.tryParse(stripsCtrl.text.trim()) ?? 10;
                  final stripPrice = double.tryParse(
                    stripPriceCtrl.text.trim(),
                  );
                  final unit = isCustomUnit
                      ? customUnitCtrl.text.trim()
                      : selectedUnit;
                  final shelfNum = shelfNumCtrl.text.trim();
                  final int initialStrips = qty * strips;

                  if (name.isEmpty || batch.isEmpty || expiry.isEmpty) {
                    _error('Fill all required fields (*)');
                    return;
                  }

                  try {
                    if (isEditing) {
                      await supabase
                          .from('medicine_boxes')
                          .update({
                            'medicine_name': name,
                            'generic_name': genericCtrl.text.trim().isEmpty
                                ? null
                                : genericCtrl.text.trim(),
                            'batch_number': batch,
                            'expiry_date': expiry,
                            'quantity': qty,
                            'strips_per_box': strips,
                            'strips_remaining': initialStrips,
                            'unit': unit,
                            'price': price,
                            'price_per_strip': stripPrice,
                            'shelf_number': shelfNum.isEmpty ? null : shelfNum,
                            'shelf_side': selectedShelfSide,
                          })
                          .eq('id', existingId);
                      _success('Medicine box updated!');
                    } else {
                      await supabase.from('medicine_boxes').insert({
                        'carton_id': cartonId,
                        'medicine_name': name,
                        'generic_name': genericCtrl.text.trim().isEmpty
                            ? null
                            : genericCtrl.text.trim(),
                        'batch_number': batch,
                        'expiry_date': expiry,
                        'quantity': qty,
                        'strips_per_box': strips,
                        'strips_remaining': initialStrips,
                        'unit': unit,
                        'price': price,
                        'price_per_strip': stripPrice,
                        'shelf_number': shelfNum.isEmpty ? null : shelfNum,
                        'shelf_side': selectedShelfSide,
                        'created_by': supabase.auth.currentUser?.id,
                        'pharmacy_id': PharmacySession.pharmacyId,
                      });
                      _success('Medicine box added!');
                    }
                    if (mounted) Navigator.pop(context);
                    _loadMedicines();
                  } catch (e) {
                    _error('Error: $e');
                  }
                },
                child: Text(
                  isEditing ? 'Update' : 'Add',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── ADD / EDIT MANUFACTURER ───────────────────────────────

  void _showManufacturerDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final countryCtrl = TextEditingController(text: existing?['country'] ?? '');
    final cartonNumCtrl = TextEditingController(text: '1');
    final boxesPerCartonCtrl = TextEditingController(text: '50');
    final bool isEditing = existing != null;
    final String existingId = existing?['id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          isEditing ? 'Edit Manufacturer' : 'Add Manufacturer',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, 'Manufacturer Name *', Icons.business),
              const SizedBox(height: 10),
              _dialogField(countryCtrl, 'Country', Icons.flag),
              if (!isEditing) ...[
                const SizedBox(height: 10),
                _dialogField(
                  cartonNumCtrl,
                  'Number of Cartons',
                  Icons.widgets,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  boxesPerCartonCtrl,
                  'Boxes per Carton (default 50)',
                  Icons.inventory_2,
                  isNumber: true,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(68, 138, 255, 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color.fromRGBO(68, 138, 255, 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blueAccent,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Total boxes = Boxes per Carton × Number of Cartons',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                _error('Manufacturer name required');
                return;
              }
              try {
                if (isEditing) {
                  await supabase
                      .from('manufacturers')
                      .update({
                        'name': name,
                        'country': countryCtrl.text.trim().isEmpty
                            ? null
                            : countryCtrl.text.trim(),
                      })
                      .eq('id', existingId);
                  _success('Manufacturer updated!');
                } else {
                  final cartonNum = int.tryParse(cartonNumCtrl.text) ?? 1;
                  final boxesPerCarton =
                      int.tryParse(boxesPerCartonCtrl.text) ?? 50;

                  final mfrRes = await supabase
                      .from('manufacturers')
                      .insert({
                        'name': name,
                        'country': countryCtrl.text.trim().isEmpty
                            ? null
                            : countryCtrl.text.trim(),
                      })
                      .select()
                      .single();

                  await supabase.from('cartons').insert({
                    'manufacturer_id': mfrRes['id'],
                    'carton_number': cartonNum,
                    'boxes_per_carton': boxesPerCarton,
                    'received_date': DateTime.now().toIso8601String().split(
                      'T',
                    )[0],
                    'created_by': supabase.auth.currentUser?.id,
                  });

                  _success(
                    'Manufacturer added! $cartonNum × $boxesPerCarton = ${cartonNum * boxesPerCarton} total boxes',
                  );
                }
                if (mounted) Navigator.pop(context);
                _loadManufacturers();
              } catch (e) {
                _error('Error: $e');
              }
            },
            child: Text(
              isEditing ? 'Update' : 'Add',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── VIEW MEDICINE BOXES ───────────────────────────────────

  void _viewMedicineBoxes(
    String manufacturerId,
    String manufacturerName,
  ) async {
    try {
      final cartonsRes = await supabase
          .from('cartons')
          .select()
          .eq('manufacturer_id', manufacturerId)
          .order('received_date', ascending: false);

      final List<Map<String, dynamic>> cartonList =
          List<Map<String, dynamic>>.from(cartonsRes);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1A2E),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => StatefulBuilder(
          builder: (ctx, setSheet) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🏭 $manufacturerName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${cartonList.length} carton(s)',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddCartonDialog(
                            manufacturerId,
                            manufacturerName,
                          );
                        },
                        icon: const Icon(
                          Icons.add_box,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          'New Carton',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                cartonList.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Text(
                            'No cartons found',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: cartonList.length,
                          itemBuilder: (_, ci) {
                            final carton = cartonList[ci];
                            final int displayNum = ci + 1;
                            return _buildCartonCard(
                              carton: carton,
                              displayNumber: displayNum,
                              manufacturerName: manufacturerName,
                              manufacturerId: manufacturerId,
                              onDeleted: () {
                                Navigator.pop(context);
                                _viewMedicineBoxes(
                                  manufacturerId,
                                  manufacturerName,
                                );
                              },
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _error('Error: $e');
    }
  }

  // ── CARTON CARD ───────────────────────────────────────────

  Widget _buildCartonCard({
    required Map<String, dynamic> carton,
    required int displayNumber,
    required String manufacturerName,
    required String manufacturerId,
    required VoidCallback onDeleted,
  }) {
    final String cartonId = carton['id'];
    final String receivedDate = carton['received_date']?.toString() ?? 'N/A';
    final String? cartonLabel = carton['carton_label']?.toString();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('medicine_boxes')
          .select()
          .eq('carton_id', cartonId)
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .order('expiry_date')
          .then((r) => List<Map<String, dynamic>>.from(r)),
      builder: (ctx, snapshot) {
        final List<Map<String, dynamic>> boxes = snapshot.data ?? [];

        int totalBoxes = 0;
        for (final box in boxes) {
          totalBoxes += (box['quantity'] as int?) ?? 0;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color.fromRGBO(68, 138, 255, 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(68, 138, 255, 0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.widgets,
                          color: Colors.blueAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cartonLabel ?? 'Carton #$displayNumber',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white54,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Received: $receivedDate',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditCartonDialog(
                              carton: carton,
                              displayNumber: displayNumber,
                              manufacturerId: manufacturerId,
                              manufacturerName: manufacturerName,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteCartonDialog(
                              cartonId: cartonId,
                              displayNumber: displayNumber,
                              manufacturerId: manufacturerId,
                              manufacturerName: manufacturerName,
                              onDeleted: onDeleted,
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showMedicineBoxDialog(cartonId, manufacturerName);
                          },
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 14,
                          ),
                          label: const Text(
                            'Add Box',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _cartonStat(
                          '📦 Boxes',
                          '$totalBoxes',
                          color: Colors.greenAccent,
                        ),
                        _cartonStat('💊 Medicines', '${boxes.length}'),
                      ],
                    ),
                  ],
                ),
              ),
              if (boxes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No medicine boxes added to this carton yet',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              else
                ...boxes.map((box) {
                  final expiry = DateTime.tryParse(box['expiry_date'] ?? '');
                  final daysLeft = expiry?.difference(DateTime.now()).inDays;
                  final bool isExpired = daysLeft != null && daysLeft < 0;
                  final bool isExpiringSoon =
                      daysLeft != null && daysLeft <= 30 && daysLeft >= 0;
                  final int qty = (box['quantity'] as int?) ?? 0;
                  final int spb = (box['strips_per_box'] as int?) ?? 10;
                  final int stripsRem =
                      (box['strips_remaining'] as int?) ?? (qty * spb);
                  final String batchNum =
                      box['batch_number']?.toString() ?? 'N/A';
                  final String shelfNum = box['shelf_number']?.toString() ?? '';
                  final String shelfSide = box['shelf_side']?.toString() ?? '';

                  final int fullBoxStrips = qty * spb;
                  final bool hasPartial = qty > 0 && stripsRem < fullBoxStrips;
                  final int partialLeft = (spb > 0)
                      ? (stripsRem % spb == 0 ? spb : stripsRem % spb)
                      : 0;

                  return Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? const Color.fromRGBO(244, 67, 54, 0.1)
                          : isExpiringSoon
                          ? const Color.fromRGBO(255, 152, 0, 0.1)
                          : const Color.fromRGBO(255, 255, 255, 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isExpired
                            ? const Color.fromRGBO(255, 82, 82, 0.3)
                            : isExpiringSoon
                            ? const Color.fromRGBO(255, 152, 0, 0.3)
                            : const Color.fromRGBO(255, 255, 255, 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    box['medicine_name'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if ((box['generic_name'] ?? '').isNotEmpty)
                                    Text(
                                      '🧬 ${box['generic_name']}',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 11,
                                      ),
                                    ),
                                  Text(
                                    '🔢 Batch: $batchNum',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueAccent,
                                size: 16,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _showMedicineBoxDialog(
                                  cartonId,
                                  manufacturerName,
                                  existing: box,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              onPressed: () async {
                                try {
                                  await supabase
                                      .from('medicine_boxes')
                                      .delete()
                                      .eq('id', box['id']);
                                  await _deleteCartonIfEmpty(cartonId);
                                  _success('Medicine deleted!');
                                  _loadMedicines();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _viewMedicineBoxes(
                                      manufacturerId,
                                      manufacturerName,
                                    );
                                  }
                                } catch (e) {
                                  _error('Delete failed: $e');
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '📦 $qty boxes',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '💊 $spb strips/box',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '🔢 $stripsRem strips left',
                                    style: TextStyle(
                                      color: stripsRem == 0
                                          ? Colors.redAccent
                                          : Colors.greenAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (hasPartial) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '⚠️ Partial box: $partialLeft strips in current box',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (shelfNum.isNotEmpty || shelfSide.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.shelves,
                                color: Colors.purpleAccent,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              if (shelfNum.isNotEmpty)
                                Text(
                                  'Shelf: $shelfNum',
                                  style: const TextStyle(
                                    color: Colors.purpleAccent,
                                    fontSize: 11,
                                  ),
                                ),
                              if (shelfNum.isNotEmpty && shelfSide.isNotEmpty)
                                const Text(
                                  ' | ',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              if (shelfSide.isNotEmpty)
                                Text(
                                  'Side: $shelfSide',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          isExpired
                              ? '⛔ EXPIRED'
                              : isExpiringSoon
                              ? '⚠️ Expires in $daysLeft days'
                              : '✅ Expires: ${box['expiry_date']}',
                          style: TextStyle(
                            color: isExpired
                                ? Colors.redAccent
                                : isExpiringSoon
                                ? Colors.orange
                                : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // ── EDIT CARTON DIALOG ────────────────────────────────────

  void _showEditCartonDialog({
    required Map<String, dynamic> carton,
    required int displayNumber,
    required String manufacturerId,
    required String manufacturerName,
  }) {
    final String cartonId = carton['id'];
    final labelCtrl = TextEditingController(
      text: carton['carton_label']?.toString() ?? '',
    );
    final boxesCtrl = TextEditingController(
      text: carton['boxes_per_carton']?.toString() ?? '50',
    );
    DateTime receivedDate =
        DateTime.tryParse(carton['received_date']?.toString() ?? '') ??
        DateTime.now();
    final receivedCtrl = TextEditingController(
      text:
          carton['received_date']?.toString() ??
          DateTime.now().toIso8601String().split('T')[0],
    );

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text(
                    'Edit Carton',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Carton #$displayNumber',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  labelCtrl,
                  'Carton Label (optional)',
                  Icons.label_outline,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  boxesCtrl,
                  'Boxes per Carton',
                  Icons.inventory_2,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: receivedCtrl,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                    ),
                    hintText: 'Date Received',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: receivedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDs(() {
                        receivedDate = picked;
                        receivedCtrl.text =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final boxesPerCarton =
                    int.tryParse(boxesCtrl.text.trim()) ?? 50;
                try {
                  await supabase
                      .from('cartons')
                      .update({
                        'carton_label': label.isEmpty ? null : label,
                        'boxes_per_carton': boxesPerCarton,
                        'received_date': receivedCtrl.text.trim(),
                      })
                      .eq('id', cartonId);
                  _success('Carton updated!');
                  if (mounted) Navigator.pop(context);
                  _viewMedicineBoxes(manufacturerId, manufacturerName);
                } catch (e) {
                  _error('Update failed: $e');
                }
              },
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── DELETE CARTON DIALOG ──────────────────────────────────

  void _showDeleteCartonDialog({
    required String cartonId,
    required int displayNumber,
    required String manufacturerId,
    required String manufacturerName,
    required VoidCallback onDeleted,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Delete Carton',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Carton #$displayNumber?\n\nThis will also delete ALL medicine boxes inside this carton.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                await supabase
                    .from('medicine_boxes')
                    .delete()
                    .eq('carton_id', cartonId);
                await supabase.from('cartons').delete().eq('id', cartonId);
                _success('Carton #$displayNumber deleted!');
                _loadMedicines();
                _loadManufacturers();
                if (context.mounted) {
                  Navigator.pop(context);
                  _viewMedicineBoxes(manufacturerId, manufacturerName);
                }
              } catch (e) {
                _error('Delete failed: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── ADD NEW CARTON DIALOG ─────────────────────────────────

  void _showAddCartonDialog(String manufacturerId, String manufacturerName) {
    final cartonLabelCtrl = TextEditingController();
    final howManyCtrl = TextEditingController(text: '1');
    final boxesPerCartonCtrl = TextEditingController(text: '50');
    DateTime receivedDate = DateTime.now();
    final receivedCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_box, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Add New Carton',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '🏭 $manufacturerName',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  cartonLabelCtrl,
                  'Carton Label (e.g. "Batch Jan 2025")',
                  Icons.label_outline,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  howManyCtrl,
                  'How many cartons to add',
                  Icons.widgets,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  boxesPerCartonCtrl,
                  'Boxes per Carton',
                  Icons.inventory_2,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: receivedCtrl,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                    ),
                    hintText: 'Date Received *',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: receivedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDs(() {
                        receivedDate = picked;
                        receivedCtrl.text =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 152, 0, 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 152, 0, 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'New cartons will continue numbering from the highest existing carton number.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              icon: const Icon(Icons.add, color: Colors.white, size: 16),
              label: const Text(
                'Add Carton',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                final int howMany = int.tryParse(howManyCtrl.text.trim()) ?? 1;
                final int boxesPerCarton =
                    int.tryParse(boxesPerCartonCtrl.text.trim()) ?? 50;
                final String label = cartonLabelCtrl.text.trim();

                try {
                  final existingCartons = await supabase
                      .from('cartons')
                      .select('carton_number')
                      .eq('manufacturer_id', manufacturerId);

                  int maxExisting = 0;
                  for (final row in List.from(existingCartons)) {
                    final int num = (row['carton_number'] as int?) ?? 0;
                    if (num > maxExisting) maxExisting = num;
                  }

                  for (int i = 1; i <= howMany; i++) {
                    final int newCartonNumber = maxExisting + i;
                    await supabase.from('cartons').insert({
                      'manufacturer_id': manufacturerId,
                      'carton_number': newCartonNumber,
                      'boxes_per_carton': boxesPerCarton,
                      'received_date': receivedCtrl.text.trim(),
                      'carton_label': label.isEmpty ? null : label,
                      'created_by': supabase.auth.currentUser?.id,
                    });
                  }

                  _success(
                    '$howMany carton(s) added! Numbers: ${maxExisting + 1} to ${maxExisting + howMany}',
                  );
                  if (mounted) Navigator.pop(context);
                  _viewMedicineBoxes(manufacturerId, manufacturerName);
                } catch (e) {
                  _error('Error: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPER WIDGETS ────────────────────────────────────────

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saleTypeChip(
    String value,
    String label,
    String selected,
    Function(String) onTap,
  ) {
    final bool isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent
              : const Color.fromRGBO(255, 255, 255, 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent
                : const Color.fromRGBO(255, 255, 255, 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
    bool isDecimal = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType:
          keyboardType ??
          (isDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : isNumber
              ? TextInputType.number
              : TextInputType.text),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _cartonStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _error(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _success(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/guardianpharmapills.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.45)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(
                        Icons.local_pharmacy,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sell Medicine & Inventory',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              PharmacySession.pharmacyName ?? '',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () {
                          _loadMedicines();
                          _loadManufacturers();
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontSize: 11),
                    tabs: const [
                      Tab(text: '💊 Sell'),
                      Tab(text: '📦 Inventory'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildSellTab(), _buildInventoryTab()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              heroTag: 'addManufacturer',
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Manufacturer',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _showManufacturerDialog,
            )
          : null,
    );
  }

  // ── TAB 1: SELL ───────────────────────────────────────────

  Widget _buildSellTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    hintText: 'Search name, generic, batch...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  onPressed: () async {
                    final String? scanned = await _scanBarcodeCamera();
                    if (scanned != null && scanned.isNotEmpty) {
                      searchController.text = scanned;
                      _filterMedicines();
                    }
                  },
                  tooltip: 'Scan Barcode',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: loadingMedicines
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                )
              : filteredMedicines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.medication_outlined,
                        color: Colors.white24,
                        size: 60,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        searchController.text.isEmpty
                            ? 'No medicines in stock'
                            : 'No results for "${searchController.text}"',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredMedicines.length,
                  itemBuilder: (_, i) {
                    final m = filteredMedicines[i];
                    final bool isExpired = _isExpired(
                      m['expiry_date']?.toString(),
                    );
                    final Color statusColor = _expiryColor(
                      m['expiry_date']?.toString(),
                    );
                    final int qty = (m['quantity'] as int?) ?? 0;
                    final int spb = (m['strips_per_box'] as int?) ?? 10;
                    final int stripsRem =
                        (m['strips_remaining'] as int?) ?? (qty * spb);
                    final String batch = m['batch_number']?.toString() ?? 'N/A';
                    final bool outOfStock = !isExpired && qty <= 0;
                    final String medicineName =
                        m['medicine_name']?.toString() ?? '';

                    return Card(
                      color: isExpired
                          ? const Color.fromRGBO(244, 67, 54, 0.15)
                          : outOfStock
                          ? const Color.fromRGBO(100, 100, 100, 0.15)
                          : const Color.fromRGBO(255, 255, 255, 0.10),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => _showSellDialog(m),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: statusColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    radius: 20,
                                    child: Icon(
                                      Icons.medication,
                                      color: statusColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          medicineName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if ((m['generic_name']?.toString() ??
                                                '')
                                            .isNotEmpty)
                                          Text(
                                            m['generic_name'],
                                            style: const TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        Text(
                                          '🔢 Batch: $batch',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isExpired)
                                    const Icon(
                                      Icons.block,
                                      color: Colors.redAccent,
                                    )
                                  else if (outOfStock)
                                    const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.grey,
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white54,
                                      size: 14,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<Map<String, dynamic>>(
                                future: _fetchRealCartonInfo(medicineName),
                                builder: (ctx, snap) {
                                  final int cartonCount =
                                      snap.data?['cartonCount'] as int? ?? 1;
                                  final int totalBoxes =
                                      snap.data?['totalBoxes'] as int? ?? qty;
                                  final int avgBoxes =
                                      snap.data?['avgBoxes'] as int? ?? qty;
                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _badge(
                                        '📦 $qty boxes',
                                        qty > 0
                                            ? Colors.blueAccent
                                            : Colors.grey,
                                      ),
                                      _badge(
                                        '💊 $stripsRem strips',
                                        qty > 0
                                            ? Colors.greenAccent
                                            : Colors.grey,
                                      ),
                                      _badge(
                                        '🏭 $cartonCount carton(s)  •  $avgBoxes avg boxes  •  $totalBoxes total',
                                        Colors.orange,
                                      ),
                                      _badge(
                                        _expiryLabel(
                                          m['expiry_date']?.toString(),
                                        ),
                                        statusColor,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🏭 ${m['cartons']?['manufacturers']?['name'] ?? 'Unknown'}  |  BDT ${m['price']}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              if (isExpired) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(
                                      255,
                                      82,
                                      82,
                                      0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color.fromRGBO(
                                        255,
                                        82,
                                        82,
                                        0.5,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    '⛔ EXPIRED — Cannot be sold',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ] else if (outOfStock) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(
                                      150,
                                      150,
                                      150,
                                      0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    '❌ OUT OF STOCK — Tap to see options',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── TAB 2: INVENTORY ──────────────────────────────────────

  Widget _buildInventoryTab() {
    return loadingManufacturers
        ? const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          )
        : manufacturers.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, color: Colors.white24, size: 60),
                SizedBox(height: 12),
                Text(
                  'No manufacturers yet',
                  style: TextStyle(color: Colors.white54),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button below to add one',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: manufacturers.length,
            itemBuilder: (_, i) {
              final m = manufacturers[i];
              return Card(
                color: const Color.fromRGBO(255, 255, 255, 0.10),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.business, color: Colors.white),
                  ),
                  title: Text(
                    m['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    m['country'] ?? 'Country N/A',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        onPressed: () => _showManufacturerDialog(existing: m),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () async {
                          await supabase
                              .from('manufacturers')
                              .delete()
                              .eq('id', m['id']);
                          _loadManufacturers();
                          _success('Deleted!');
                        },
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                  onTap: () => _viewMedicineBoxes(m['id'], m['name']),
                ),
              );
            },
          );
  }
}
