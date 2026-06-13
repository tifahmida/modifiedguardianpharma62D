import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pharmacy_wrapper_page.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> sales = [];
  bool loading = true;
  String selectedFilter = 'Today';

  final List<String> filters = ['Today', 'This Week', 'This Month', 'All Time'];

  double totalRevenue = 0;
  int totalTransactions = 0;
  int totalStrips = 0;
  int totalBoxes = 0;
  int totalCartons = 0;

  // ── UNDO DELETE STATE ──────────────────────────────────────
  //
  // NEW DESIGN:
  // 1. Delete from Supabase IMMEDIATELY when Delete is pressed,
  //    and verify it actually deleted something (using .select()).
  // 2. Keep a local backup copy (_deletedSale) during the undo window.
  // 3. Show a SnackBar with an UNDO action for 5 seconds.
  // 4. The SnackBar's own `.closed` future is the SINGLE SOURCE OF TRUTH
  //    for when the undo window ends — no separate competing Timer.
  //    - If closed because UNDO was pressed -> restore the row.
  //    - If closed for any other reason (timeout, swipe, replaced by
  //      another snackbar) -> finalize deletion (clear backup).
  // 5. Refresh always shows the real DB state (already deleted).

  Map<String, dynamic>? _deletedSale; // backup copy for potential UNDO
  bool _undoAvailable = false; // true only during the undo window

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _deletedSale = null;
    _undoAvailable = false;
    super.dispose();
  }

  // ── DATE / TIME HELPERS ───────────────────────────────────

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso).toUtc().add(const Duration(hours: 6));
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTime(String iso) {
    final dt = DateTime.parse(iso).toUtc().add(const Duration(hours: 6));
    final h = dt.hour;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0
        ? 12
        : h > 12
        ? h - 12
        : h;
    return '${h12.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')} $period';
  }

  // ── LOAD SALES FROM SUPABASE ──────────────────────────────

  Future<void> _loadSales() async {
    // If user refreshes during an undo window, finalize that pending
    // delete cleanly. The row is already deleted in Supabase so refresh
    // will not bring it back. We just discard the local backup so UNDO
    // no longer works for that row.
    if (_undoAvailable) {
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
      _deletedSale = null;
      _undoAvailable = false;
    }

    setState(() => loading = true);
    try {
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime.utc(now.year, now.month, 1);
      final pharmacyId = PharmacySession.pharmacyId ?? '';

      List<Map<String, dynamic>> res = [];

      if (selectedFilter == 'Today') {
        final r = await supabase
            .from('sales')
            .select('*, profiles(full_name)')
            .eq('pharmacy_id', pharmacyId)
            .gte('created_at', todayStart.toIso8601String())
            .order('created_at', ascending: false);
        res = List<Map<String, dynamic>>.from(r);
      } else if (selectedFilter == 'This Week') {
        final r = await supabase
            .from('sales')
            .select('*, profiles(full_name)')
            .eq('pharmacy_id', pharmacyId)
            .gte('created_at', weekStart.toIso8601String())
            .order('created_at', ascending: false);
        res = List<Map<String, dynamic>>.from(r);
      } else if (selectedFilter == 'This Month') {
        final r = await supabase
            .from('sales')
            .select('*, profiles(full_name)')
            .eq('pharmacy_id', pharmacyId)
            .gte('created_at', monthStart.toIso8601String())
            .order('created_at', ascending: false);
        res = List<Map<String, dynamic>>.from(r);
      } else {
        final r = await supabase
            .from('sales')
            .select('*, profiles(full_name)')
            .eq('pharmacy_id', pharmacyId)
            .order('created_at', ascending: false);
        res = List<Map<String, dynamic>>.from(r);
      }

      double revenue = 0;
      int strips = 0, boxes = 0, cartons = 0;
      for (final s in res) {
        revenue += double.tryParse(s['total_amount'].toString()) ?? 0;
        final type = s['sale_type']?.toString() ?? '';
        final qty = (s['quantity_sold'] as int?) ?? 0;
        if (type == 'strip') strips += qty;
        if (type == 'box') boxes += qty;
        if (type == 'carton') cartons += qty;
      }

      setState(() {
        sales = res;
        totalRevenue = revenue;
        totalTransactions = res.length;
        totalStrips = strips;
        totalBoxes = boxes;
        totalCartons = cartons;
        loading = false;
      });
    } catch (e) {
      _error('Failed to load: $e');
      setState(() => loading = false);
    }
  }

  // ── FETCH SUSPICIOUS LOG FOR A SALE ──────────────────────

  Future<Map<String, dynamic>?> _fetchSuspiciousLog(
    Map<String, dynamic> sale,
  ) async {
    try {
      final String medicineName = sale['medicine_name']?.toString() ?? '';
      final String batchNumber = sale['batch_number']?.toString() ?? '';
      final String pharmacyId = PharmacySession.pharmacyId ?? '';
      final String saleCreatedAt = sale['created_at']?.toString() ?? '';
      final int saleQty = (sale['quantity_sold'] as int?) ?? 0;

      if (medicineName.isEmpty || saleCreatedAt.isEmpty) return null;

      final DateTime? saleTime = DateTime.tryParse(saleCreatedAt);
      if (saleTime == null) return null;

      final res = await supabase
          .from('suspicious_logs')
          .select()
          .eq('pharmacy_id', pharmacyId)
          .eq('medicine_name', medicineName)
          .eq('batch_number', batchNumber)
          .eq('activity_type', 'high_quantity_purchase')
          .eq('quantity', saleQty)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> results =
          List<Map<String, dynamic>>.from(res);

      for (final log in results) {
        final String logCreatedAt = log['created_at']?.toString() ?? '';
        final DateTime? logTime = DateTime.tryParse(logCreatedAt);
        if (logTime == null) continue;
        final int minutesDiff = saleTime.difference(logTime).inMinutes.abs();
        if (minutesDiff <= 10) return log;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ── DELETE WITH UNDO ──────────────────────────────────────
  //
  // STEP 1: If there is already a pending undo from a previous delete,
  //         finalize it (the row was already deleted from Supabase),
  //         and clear its backup + close its SnackBar.
  //
  // STEP 2: Delete the new row from Supabase RIGHT NOW, and VERIFY it
  //         actually deleted a row using .select(). If RLS blocks the
  //         delete, Supabase returns an empty list instead of an error
  //         — so we must check for that and stop if nothing was deleted.
  //
  // STEP 3: Save a local backup copy so UNDO can re-insert it if needed.
  //
  // STEP 4: Remove the row from the local UI list immediately.
  //
  // STEP 5: Show a SnackBar for 5 seconds with an UNDO button. The
  //         SnackBar's own `.closed` future decides what happens next:
  //         - closed via UNDO button -> restore the row
  //         - closed any other way (timeout/swipe/replaced) -> finalize
  //           the deletion permanently (just clear the backup; the DB
  //           row is already gone)

  Future<void> _deleteWithUndo(Map<String, dynamic> sale) async {
    // ── STEP 1: Finalize previous undo window (if any) ────
    // The previous deleted row is already gone from Supabase.
    // We just throw away its local backup and close its SnackBar.
    if (_undoAvailable) {
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
      _deletedSale = null;
      _undoAvailable = false;
    }

    // ── STEP 2: Delete from Supabase IMMEDIATELY, and verify ──
    // .select() makes Supabase return the row(s) it actually deleted.
    // If RLS policies block the delete, Supabase does NOT throw an
    // error — it just deletes 0 rows silently. So we check the result
    // length to know if the delete really happened.
    try {
      final deleteResult = await supabase
          .from('sales')
          .delete()
          .eq('id', sale['id'])
          .select();

      if (deleteResult.isEmpty) {
        // Nothing was actually deleted (permission denied or row gone)
        if (mounted) {
          Navigator.pop(context); // close the bottom sheet
          _error('Delete failed: permission denied or transaction not found.');
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close the bottom sheet
        _error('Could not delete transaction. Please try again.');
      }
      return;
    }

    // ── STEP 3: Save a local backup for potential UNDO ────
    _deletedSale = Map<String, dynamic>.from(sale);
    _undoAvailable = true;

    // ── STEP 4: Remove from local UI list immediately ─────
    setState(() {
      sales.removeWhere((s) => s['id'] == sale['id']);
      _recalculateTotals();
    });

    // ── Close the bottom sheet ────────────────────────────
    if (mounted) Navigator.pop(context);

    // ── STEP 5: Show SnackBar for 5 seconds ──────────────
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFF323232),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.blueAccent,
          onPressed: () {
            // User pressed UNDO — mark it as handled and restore the row.
            // The SnackBar's `.closed` future below will see that this
            // was closed via the action and will NOT finalize deletion.
            _undoAvailable = false;
            _restoreDeletedSale();
          },
        ),
      ),
    );

    // This future completes when the SnackBar disappears, for ANY
    // reason (timeout, swiped away, replaced by another SnackBar).
    // This is now the SINGLE place that decides whether the deletion
    // becomes permanent.
    snackBarController.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) {
        // Not closed via the UNDO button -> deletion is now permanent.
        // The row is already gone from Supabase, so we just drop the
        // local backup. Nothing else needs to happen.
        _deletedSale = null;
        _undoAvailable = false;
      }
    });
  }

  // ── RESTORE DELETED SALE (UNDO pressed) ──────────────────
  //
  // Re-inserts the backup row into Supabase, then refreshes the list.

  Future<void> _restoreDeletedSale() async {
    if (_deletedSale == null) return;

    // Take a local reference before clearing the state variable
    final Map<String, dynamic> rowToRestore = Map<String, dynamic>.from(
      _deletedSale!,
    );
    rowToRestore.remove(
      'profiles',
    ); // 'profiles' is a join artifact, not a real column

    // Clear backup before the async call so a double-tap cannot trigger twice
    _deletedSale = null;

    try {
      await supabase.from('sales').insert(rowToRestore);

      // Refresh the list from Supabase to get the restored row
      await _loadSales();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction restored successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _error('Could not restore transaction: $e');
      // Reload anyway so list is consistent with DB
      _loadSales();
    }
  }

  // ── RECALCULATE TOTALS AFTER LOCAL REMOVAL ────────────────

  void _recalculateTotals() {
    double revenue = 0;
    int strips = 0, boxes = 0, cartons = 0;
    for (final s in sales) {
      revenue += double.tryParse(s['total_amount'].toString()) ?? 0;
      final type = s['sale_type']?.toString() ?? '';
      final qty = (s['quantity_sold'] as int?) ?? 0;
      if (type == 'strip') strips += qty;
      if (type == 'box') boxes += qty;
      if (type == 'carton') cartons += qty;
    }
    totalRevenue = revenue;
    totalTransactions = sales.length;
    totalStrips = strips;
    totalBoxes = boxes;
    totalCartons = cartons;
  }

  // ── SHOW SALE DETAIL BOTTOM SHEET ────────────────────────

  void _showDetail(Map<String, dynamic> sale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (_, ctrl) => FutureBuilder<Map<String, dynamic>?>(
          future: _fetchSuspiciousLog(sale),
          builder: (ctx, snapshot) {
            final Map<String, dynamic>? suspLog = snapshot.data;

            String customerNameFromLog = '';
            String customerAgeFromLog = '';
            String reasonFromLog = '';

            if (suspLog != null) {
              final String desc = suspLog['description']?.toString() ?? '';

              if (desc.contains('Reason: ')) {
                reasonFromLog = desc.split('Reason: ').last.trim();
              }

              final ageMatch = RegExp(r'\(age (\d+),').firstMatch(desc);
              if (ageMatch != null) {
                customerAgeFromLog = ageMatch.group(1) ?? '';
              }

              if (desc.contains(' (age')) {
                customerNameFromLog = desc.split(' (age').first.trim();
              }
            }

            return SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: Colors.blueAccent,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Transaction Receipt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(sale['created_at'])}  •  ${_formatTime(sale['created_at'])} (BD)',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),

                  _row(
                    '💊 Medicine',
                    sale['medicine_name']?.toString() ?? 'N/A',
                  ),
                  _row('🔢 Batch', sale['batch_number']?.toString() ?? 'N/A'),
                  _row(
                    '📦 Type',
                    (sale['sale_type']?.toString() ?? '').toUpperCase(),
                  ),
                  _row('🔢 Quantity', sale['quantity_sold']?.toString() ?? '0'),
                  _row(
                    '💰 Unit Price',
                    'BDT ${double.tryParse(sale['unit_price'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                  ),
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
                        'BDT ${double.tryParse(sale['total_amount'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _row(
                    '👨‍⚕️ Sold By',
                    sale['profiles']?['full_name']?.toString() ?? 'Unknown',
                  ),
                  if ((sale['customer_name']?.toString() ?? '').isNotEmpty)
                    _row(
                      '👤 Customer',
                      sale['customer_name']?.toString() ?? '',
                    ),
                  if ((sale['customer_phone']?.toString() ?? '').isNotEmpty)
                    _row('📱 Phone', sale['customer_phone']?.toString() ?? ''),

                  if (suspLog != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 152, 0, 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 152, 0, 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚠️ High Quantity Sale — OTP Verified',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(
                            color: Color.fromRGBO(255, 152, 0, 0.3),
                            height: 1,
                          ),
                          const SizedBox(height: 10),

                          if (customerNameFromLog.isNotEmpty)
                            _logRow('👤 Customer Name', customerNameFromLog),

                          if (customerAgeFromLog.isNotEmpty)
                            _logRow('🎂 Age', '$customerAgeFromLog years'),

                          _logRow(
                            '🔢 Quantity Flagged',
                            '${suspLog['quantity']?.toString() ?? sale['quantity_sold']?.toString() ?? '0'} units',
                          ),

                          const SizedBox(height: 10),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(255, 152, 0, 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color.fromRGBO(255, 152, 0, 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.notes,
                                      color: Colors.orange,
                                      size: 14,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Reason for Purchase:',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  reasonFromLog.isNotEmpty
                                      ? reasonFromLog
                                      : 'No reason recorded.',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                          _logRow(
                            '🚩 Flagged By',
                            suspLog['flagged_by']?.toString() ?? 'system',
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── DELETE BUTTON ──────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text(
                        'Delete Transaction',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () => _deleteWithUndo(sale),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── ROW WIDGETS ───────────────────────────────────────────

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color.fromRGBO(255, 152, 0, 0.7),
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _error(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

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
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.receipt_long, color: Colors.white),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Transaction History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadSales,
                      ),
                    ],
                  ),
                ),

                // FILTER CHIPS
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filters.length,
                    itemBuilder: (_, i) {
                      final f = filters[i];
                      final isSelected = f == selectedFilter;
                      return GestureDetector(
                        onTap: () {
                          setState(() => selectedFilter = f);
                          _loadSales();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blueAccent
                                : const Color.fromRGBO(255, 255, 255, 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white60,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // SUMMARY CARDS
                if (!loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(68, 138, 255, 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color.fromRGBO(68, 138, 255, 0.4),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '💰 Total Revenue',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'BDT ${totalRevenue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$totalTransactions transactions',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _miniStat(
                              '💊 Strips',
                              '$totalStrips',
                              Colors.blueAccent,
                            ),
                            const SizedBox(width: 8),
                            _miniStat(
                              '📦 Boxes',
                              '$totalBoxes',
                              Colors.greenAccent,
                            ),
                            const SizedBox(width: 8),
                            _miniStat(
                              '🏭 Cartons',
                              '$totalCartons',
                              Colors.orangeAccent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // SALES LIST
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        )
                      : sales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                color: Colors.white24,
                                size: 60,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No transactions for $selectedFilter',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: sales.length,
                          itemBuilder: (_, i) {
                            final sale = sales[i];
                            final type = sale['sale_type']?.toString() ?? '';
                            final double total =
                                double.tryParse(
                                  sale['total_amount'].toString(),
                                ) ??
                                0;
                            final soldBy =
                                sale['profiles']?['full_name']?.toString() ??
                                'Unknown';
                            final customer =
                                sale['customer_name']?.toString() ?? '';
                            final int qty =
                                (sale['quantity_sold'] as int?) ?? 0;

                            Color typeColor;
                            IconData typeIcon;
                            if (type == 'strip') {
                              typeColor = Colors.blueAccent;
                              typeIcon = Icons.medication;
                            } else if (type == 'box') {
                              typeColor = Colors.greenAccent;
                              typeIcon = Icons.inventory_2;
                            } else {
                              typeColor = Colors.orangeAccent;
                              typeIcon = Icons.widgets;
                            }

                            return GestureDetector(
                              onTap: () => _showDetail(sale),
                              child: Card(
                                color: const Color.fromRGBO(
                                  255,
                                  255,
                                  255,
                                  0.10,
                                ),
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: typeColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        child: Icon(
                                          typeIcon,
                                          color: typeColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              sale['medicine_name']
                                                      ?.toString() ??
                                                  'Unknown',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Batch: ${sale['batch_number']}  |  ${type.toUpperCase()}  |  Qty: $qty',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '👨‍⚕️ $soldBy${customer.isNotEmpty ? '  |  👤 $customer' : ''}',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              '${_formatDate(sale['created_at'])}  •  ${_formatTime(sale['created_at'])}',
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'BDT ${total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
