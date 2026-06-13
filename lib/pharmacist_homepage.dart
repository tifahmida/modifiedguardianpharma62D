import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner_plus/flutter_barcode_scanner_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'sell_medicine_and_inventory_trackingpage.dart';
import 'transaction_history_page.dart';
import 'pharmacy_wrapper_page.dart';

class PharmacistHome extends StatefulWidget {
  const PharmacistHome({super.key});

  @override
  State<PharmacistHome> createState() => _PharmacistHomeState();
}

class _PharmacistHomeState extends State<PharmacistHome> {
  final supabase = Supabase.instance.client;
  final searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int totalInStock = 0;
  int expiryAlertCount = 0;
  int outOfStockCount = 0;
  double todaySalesTotal = 0;
  int todaySalesCount = 0;
  String topSoldMedicine = '—';

  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  bool hasSearched = false;

  List<Map<String, dynamic>> lowStockMeds = [];
  List<Map<String, dynamic>> expiringMeds = [];

  bool loadingStats = true;
  bool loadingAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadAlerts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => loadingStats = true);
    try {
      final pid = PharmacySession.pharmacyId ?? '';
      final now = DateTime.now();
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc().toIso8601String();

      final allMeds = await supabase
          .from('medicine_boxes')
          .select('id, quantity, expiry_date')
          .eq('pharmacy_id', pid);

      final todaySales = await supabase
          .from('sales')
          .select('total_amount, medicine_name')
          .eq('pharmacy_id', pid)
          .gte('created_at', todayStart);

      int inStock = 0, outStock = 0, expAlert = 0;
      for (final m in allMeds) {
        final qty = (m['quantity'] as int?) ?? 0;
        final exp = DateTime.tryParse(m['expiry_date']?.toString() ?? '');
        if (qty <= 0) {
          outStock++;
        } else {
          inStock++;
          if (exp != null) {
            final days = exp.difference(now).inDays;
            if (days <= 30 && days >= 0) expAlert++;
          }
        }
      }

      double totalRev = 0;
      final Map<String, int> nameCount = {};
      for (final s in todaySales) {
        totalRev += double.tryParse(s['total_amount'].toString()) ?? 0;
        final mName = s['medicine_name']?.toString() ?? '';
        if (mName.isNotEmpty) {
          nameCount[mName] = (nameCount[mName] ?? 0) + 1;
        }
      }

      String topSold = '—';
      if (nameCount.isNotEmpty) {
        topSold = nameCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      setState(() {
        totalInStock = inStock;
        outOfStockCount = outStock;
        expiryAlertCount = expAlert;
        todaySalesTotal = totalRev;
        todaySalesCount = (todaySales as List).length;
        topSoldMedicine = topSold;
        loadingStats = false;
      });
    } catch (e) {
      setState(() => loadingStats = false);
    }
  }

  Future<void> _loadAlerts() async {
    setState(() => loadingAlerts = true);
    try {
      final pid = PharmacySession.pharmacyId ?? '';
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final in30 = now.add(const Duration(days: 30));
      final in30Str =
          '${in30.year}-${in30.month.toString().padLeft(2, '0')}-${in30.day.toString().padLeft(2, '0')}';

      final low = await supabase
          .from('medicine_boxes')
          .select()
          .eq('pharmacy_id', pid)
          .gt('quantity', 0)
          .lte('quantity', 5)
          .order('quantity', ascending: true)
          .limit(5);

      final expiring = await supabase
          .from('medicine_boxes')
          .select()
          .eq('pharmacy_id', pid)
          .gte('expiry_date', todayStr)
          .lte('expiry_date', in30Str)
          .order('expiry_date', ascending: true)
          .limit(5);

      setState(() {
        lowStockMeds = List<Map<String, dynamic>>.from(low);
        expiringMeds = List<Map<String, dynamic>>.from(expiring);
        loadingAlerts = false;
      });
    } catch (e) {
      setState(() => loadingAlerts = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
        hasSearched = false;
      });
      return;
    }
    setState(() => isSearching = true);
    try {
      final pid = PharmacySession.pharmacyId ?? '';
      final q = query.trim();
      final res = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', pid)
          .or(
            'medicine_name.ilike.%$q%,generic_name.ilike.%$q%,batch_number.ilike.%$q%',
          )
          .order('expiry_date', ascending: true);

      setState(() {
        searchResults = List<Map<String, dynamic>>.from(res);
        hasSearched = true;
        isSearching = false;
      });
    } catch (e) {
      setState(() => isSearching = false);
    }
  }

  // ✅ REAL BARCODE SCANNER using flutter_barcode_scanner_plus
  Future<void> _scanBarcode() async {
    String barcodeScanResult;

    try {
      barcodeScanResult = await FlutterBarcodeScanner.scanBarcode(
        '#FF2196F3', // scan line color (blue)
        'Cancel', // cancel button text
        true, // show flash icon
        ScanMode.BARCODE,
      );
    } on PlatformException {
      barcodeScanResult = '-1';
    }

    // '-1' means the user cancelled or scan failed
    if (!mounted) return;
    if (barcodeScanResult == '-1' || barcodeScanResult.isEmpty) return;

    // Put the scanned value into the search field and search
    searchController.text = barcodeScanResult;
    _search(barcodeScanResult);
  }

  void _logout() async {
    PharmacySession.clear();
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MyLogin()),
      (r) => false,
    );
  }

  void _navigate(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      _loadStats();
      _loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String pharmacyName = PharmacySession.pharmacyName ?? 'My Pharmacy';
    final String licenseNumber = PharmacySession.licenseNumber ?? '';
    final String address = PharmacySession.pharmacyAddress ?? '';

    return Scaffold(
      key: _scaffoldKey,

      // NAVIGATION DRAWER
      drawer: Drawer(
        backgroundColor: const Color(0xFF0D1B2A),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF00838F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_pharmacy_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    pharmacyName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (licenseNumber.isNotEmpty)
                    Text(
                      '🪪 $licenseNumber',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  if (address.isNotEmpty)
                    Text(
                      '📍 $address',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PHARMACIST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  _drawerSection('🧾 Features'),
                  _drawerItem(
                    '💊 Sell Medicine & Inventory',
                    Icons.local_pharmacy,
                    Colors.greenAccent,
                    () => _navigate(const SellMedicineAndInventoryPage()),
                  ),
                  _drawerItem(
                    '🧾 Transaction History',
                    Icons.receipt_long,
                    Colors.purpleAccent,
                    () => _navigate(const TransactionHistoryPage()),
                  ),
                  const Divider(color: Colors.white12),
                  _drawerSection('⚙️ Account'),
                  _drawerItem('🚪 Logout', Icons.logout, Colors.redAccent, () {
                    Navigator.pop(context);
                    _logout();
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'GuardianPharma v1.0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/guardianpharmapills.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.50)),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadStats();
                await _loadAlerts();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 10),

                  // TOP BAR
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.local_pharmacy,
                        color: Colors.blueAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'GuardianPharma',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // HEADER CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF00838F)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_pharmacy_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pharmacyName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (licenseNumber.isNotEmpty)
                                    Text(
                                      '🪪 $licenseNumber',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (address.isNotEmpty)
                                    Text(
                                      '📍 $address',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _summaryItem(
                              '💰 Revenue',
                              'BDT ${todaySalesTotal.toStringAsFixed(0)}',
                            ),
                            _vDivider(),
                            _summaryItem('🧾 Sales', '$todaySalesCount'),
                            _vDivider(),
                            _summaryItem(
                              '🔥 Top',
                              topSoldMedicine,
                              small: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // QUICK STATS
                  Row(
                    children: [
                      _statChip(
                        'In Stock',
                        '$totalInStock',
                        Colors.greenAccent,
                        Icons.inventory,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        'Expiry Alert',
                        '$expiryAlertCount',
                        Colors.orange,
                        Icons.warning_amber,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        'Out of Stock',
                        '$outOfStockCount',
                        Colors.redAccent,
                        Icons.remove_circle,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // INVENTORY & MEDICINE LOOKUP
                  _sectionTitle('🔍 Inventory & Medicine Lookup'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.4),
                            ),
                          ),
                          child: TextField(
                            controller: searchController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            onChanged: _search,
                            onSubmitted: _search,
                            decoration: InputDecoration(
                              hintText: 'Search name, generic, batch...',
                              hintStyle: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.blueAccent,
                              ),
                              suffixIcon: isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    )
                                  : searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Colors.white38,
                                      ),
                                      onPressed: () {
                                        searchController.clear();
                                        setState(() {
                                          searchResults = [];
                                          hasSearched = false;
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ✅ REAL SCANNER BUTTON
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                          ),
                          tooltip: 'Scan Barcode',
                          onPressed: _scanBarcode,
                        ),
                      ),
                    ],
                  ),

                  // SEARCH RESULTS
                  if (hasSearched) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: Colors.blueAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${searchResults.length} result(s) for "${searchController.text}"',
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (searchResults.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              color: Colors.white38,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No medicine found',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Try generic name or batch number',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...searchResults.map((m) => _searchResultCard(m)),
                  ],

                  // ALERTS (when not searching)
                  if (!hasSearched) ...[
                    const SizedBox(height: 16),

                    // FEFO reminder
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.blueAccent,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'FEFO: Always dispense medicines with earliest expiry date first.',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (expiringMeds.isNotEmpty) ...[
                      _sectionTitle('⚠️ Expiring Soon (≤ 30 days)'),
                      const SizedBox(height: 8),
                      ...expiringMeds.map((m) => _alertCard(m, isExpiry: true)),
                      const SizedBox(height: 12),
                    ],

                    if (lowStockMeds.isNotEmpty) ...[
                      _sectionTitle('📉 Low Stock'),
                      const SizedBox(height: 8),
                      ...lowStockMeds.map(
                        (m) => _alertCard(m, isExpiry: false),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchResultCard(Map<String, dynamic> m) {
    final int qty = (m['quantity'] as int?) ?? 0;
    final int stripsPerBox = (m['strips_per_box'] as int?) ?? 10;
    final int totalStrips = qty * stripsPerBox;
    final Color expColor = _expiryColor(m['expiry_date']?.toString());
    final String mfr =
        m['cartons']?['manufacturers']?['name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: expColor.withOpacity(0.4)),
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
                      m['medicine_name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if ((m['generic_name'] ?? '').isNotEmpty)
                      Text(
                        m['generic_name'],
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                        ),
                      ),
                    if (mfr.isNotEmpty)
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
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _infoChip('📦 $qty boxes', Colors.blueAccent),
              _infoChip('💊 $totalStrips strips', Colors.tealAccent),
              _infoChip('🔢 ${m['batch_number'] ?? 'N/A'}', Colors.white54),
              if ((m['unit'] ?? '').isNotEmpty)
                _infoChip('📏 ${m['unit']}', Colors.white38),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: expColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: expColor.withOpacity(0.4)),
            ),
            child: Text(
              _expiryLabel(m['expiry_date']?.toString()),
              style: TextStyle(
                color: expColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: qty > 0 ? Colors.greenAccent : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: qty > 0
                      ? () => _navigate(
                          SellMedicineAndInventoryPage(preSelected: m),
                        )
                      : null,
                  icon: const Icon(
                    Icons.point_of_sale,
                    color: Colors.black,
                    size: 16,
                  ),
                  label: const Text(
                    'Sell',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> m, {required bool isExpiry}) {
    final int qty = (m['quantity'] as int?) ?? 0;
    final Color color = isExpiry ? Colors.orange : Colors.redAccent;

    return GestureDetector(
      onTap: () => _navigate(SellMedicineAndInventoryPage(preSelected: m)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              isExpiry ? Icons.warning_amber : Icons.inventory_2,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['medicine_name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (isExpiry)
                    Text(
                      _expiryLabel(m['expiry_date']?.toString()),
                      style: TextStyle(color: color, fontSize: 11),
                    )
                  else
                    Text(
                      '$qty boxes remaining',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white24,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // DRAWER HELPERS
  Widget _drawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _drawerItem(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white24,
        size: 12,
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  // HELPER WIDGETS
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

  Widget _summaryItem(String label, String value, {bool small = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: small ? 11 : 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2));

  Widget _sectionTitle(String t) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
