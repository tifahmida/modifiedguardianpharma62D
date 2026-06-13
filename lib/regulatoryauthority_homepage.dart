import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guardianpharma/login_page.dart';

// ============================================================
// RegulatoryHome — 3 tabs:
//   Tab 1: Pharmacies
//   Tab 2: Add Pharmacy
//   Tab 3: Pharmacy Verification
// ============================================================
class RegulatoryHome extends StatefulWidget {
  const RegulatoryHome({super.key});

  @override
  State<RegulatoryHome> createState() => _RegulatoryHomeState();
}

class _RegulatoryHomeState extends State<RegulatoryHome>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  // ── TAB 1 STATE ───────────────────────────────
  List<Map<String, dynamic>> allPharmacies = [];
  List<Map<String, dynamic>> filteredPharmacies = [];
  bool loadingPharmacies = true;
  final searchController = TextEditingController();

  // ── TAB 2 STATE ───────────────────────────────
  bool saving = false;
  final nameCtrl = TextEditingController();
  final licCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final ownerCtrl = TextEditingController();

  // ── TAB 3 STATE ───────────────────────────────
  List<Map<String, dynamic>> verifyPharmacies = [];
  bool loadingVerify = true;
  String selectedFilter = 'Pending';
  final List<String> filterOptions = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadAllPharmacies();
    _loadVerifyPharmacies();
    searchController.addListener(_filterPharmacies);
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    nameCtrl.dispose();
    licCtrl.dispose();
    addressCtrl.dispose();
    phoneCtrl.dispose();
    ownerCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // DATA METHODS
  // ══════════════════════════════════════════════

  Future<void> _loadAllPharmacies() async {
    setState(() => loadingPharmacies = true);
    try {
      final res = await supabase.from('pharmacies').select().order('name');
      setState(() {
        allPharmacies = List<Map<String, dynamic>>.from(res);
        filteredPharmacies = allPharmacies;
        loadingPharmacies = false;
      });
    } catch (e) {
      setState(() => loadingPharmacies = false);
      _showMsg('Failed to load: $e', isError: true);
    }
  }

  void _filterPharmacies() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredPharmacies = allPharmacies.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final lic = (p['license_number'] ?? '').toString().toLowerCase();
        final owner = (p['owner_name'] ?? '').toString().toLowerCase();
        return name.contains(q) || lic.contains(q) || owner.contains(q);
      }).toList();
    });
  }

  Future<void> _loadVerifyPharmacies() async {
    setState(() => loadingVerify = true);
    try {
      final res = await supabase.from('pharmacies').select().order('name');
      List<Map<String, dynamic>> all = List<Map<String, dynamic>>.from(res);

      if (selectedFilter == 'Pending') {
        all = all.where((p) => p['is_verified'] == null).toList();
      } else if (selectedFilter == 'Approved') {
        all = all.where((p) => p['is_verified'] == true).toList();
      } else if (selectedFilter == 'Rejected') {
        all = all.where((p) => p['is_verified'] == false).toList();
      }

      setState(() {
        verifyPharmacies = all;
        loadingVerify = false;
      });
    } catch (e) {
      setState(() => loadingVerify = false);
      _showMsg('Failed to load: $e', isError: true);
    }
  }

  Future<void> _addPharmacy() async {
    if (nameCtrl.text.trim().isEmpty) {
      _showMsg('Pharmacy name is required', isError: true);
      return;
    }
    if (licCtrl.text.trim().isEmpty) {
      _showMsg('License number is required', isError: true);
      return;
    }
    setState(() => saving = true);
    try {
      await supabase.from('pharmacies').insert({
        'name': nameCtrl.text.trim(),
        'license_number': licCtrl.text.trim(),
        'address': addressCtrl.text.trim().isEmpty
            ? null
            : addressCtrl.text.trim(),
        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        'owner_name': ownerCtrl.text.trim().isEmpty
            ? null
            : ownerCtrl.text.trim(),
        'is_active': true,
        'is_verified': null,
      });
      _showMsg('Pharmacy added successfully!');
      nameCtrl.clear();
      licCtrl.clear();
      addressCtrl.clear();
      phoneCtrl.clear();
      ownerCtrl.clear();
      await _loadAllPharmacies();
      await _loadVerifyPharmacies();
    } catch (e) {
      _showMsg('Failed to add: $e', isError: true);
    }
    setState(() => saving = false);
  }

  // ══════════════════════════════════════════════
  // TOGGLE ACTIVE  ← NEW METHOD
  // ══════════════════════════════════════════════

  Future<void> _toggleActive(Map<String, dynamic> p) async {
    final bool currentlyActive = p['is_active'] == true;
    try {
      await supabase
          .from('pharmacies')
          .update({'is_active': !currentlyActive})
          .eq('id', p['id']);
      _showMsg(
        currentlyActive ? 'Pharmacy deactivated.' : 'Pharmacy activated!',
        isError: currentlyActive,
      );
      await _loadAllPharmacies();
      await _loadVerifyPharmacies();
    } catch (e) {
      _showMsg('Failed to update: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════

  void _showEditDialog(Map<String, dynamic> p) {
    final eNameCtrl = TextEditingController(text: p['name'] ?? '');
    final eLicCtrl = TextEditingController(text: p['license_number'] ?? '');
    final eAddressCtrl = TextEditingController(text: p['address'] ?? '');
    final ePhoneCtrl = TextEditingController(text: p['phone'] ?? '');
    final eOwnerCtrl = TextEditingController(text: p['owner_name'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text(
              'Edit Pharmacy',
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
              _field(eNameCtrl, 'Pharmacy Name', Icons.local_pharmacy),
              const SizedBox(height: 10),
              _field(eLicCtrl, 'License Number', Icons.badge),
              const SizedBox(height: 10),
              _field(eAddressCtrl, 'Address', Icons.location_on),
              const SizedBox(height: 10),
              _field(
                ePhoneCtrl,
                'Phone',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _field(eOwnerCtrl, 'Owner Name', Icons.person),
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
              try {
                await supabase
                    .from('pharmacies')
                    .update({
                      'name': eNameCtrl.text.trim(),
                      'license_number': eLicCtrl.text.trim(),
                      'address': eAddressCtrl.text.trim().isEmpty
                          ? null
                          : eAddressCtrl.text.trim(),
                      'phone': ePhoneCtrl.text.trim().isEmpty
                          ? null
                          : ePhoneCtrl.text.trim(),
                      'owner_name': eOwnerCtrl.text.trim().isEmpty
                          ? null
                          : eOwnerCtrl.text.trim(),
                    })
                    .eq('id', p['id']);
                if (mounted) Navigator.pop(context);
                _showMsg('Pharmacy updated!');
                _loadAllPharmacies();
                _loadVerifyPharmacies();
              } catch (e) {
                _showMsg('Update failed: $e', isError: true);
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Delete Pharmacy',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${p['name']}"?\n\nThis cannot be undone.',
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
              Navigator.pop(context);
              try {
                await supabase.from('pharmacies').delete().eq('id', p['id']);
                _showMsg('Pharmacy deleted!');
                _loadAllPharmacies();
                _loadVerifyPharmacies();
              } catch (e) {
                _showMsg('Delete failed: $e', isError: true);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateVerification(
    Map<String, dynamic> p,
    String action,
  ) async {
    bool? isVerified;
    if (action == 'approve') isVerified = true;
    if (action == 'reject') isVerified = false;

    try {
      await supabase
          .from('pharmacies')
          .update({'is_verified': isVerified})
          .eq('id', p['id']);
      if (action == 'approve') {
        _showMsg('Pharmacy approved!');
      } else if (action == 'reject') {
        _showMsg('Pharmacy rejected.', isError: true);
      } else {
        _showMsg('Reset to Pending.');
      }
      _loadVerifyPharmacies();
      _loadAllPharmacies();
    } catch (e) {
      _showMsg('Failed: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════

  String _verifyStatus(Map<String, dynamic> p) {
    final v = p['is_verified'];
    if (v == true) return 'approved';
    if (v == false) return 'rejected';
    return 'pending';
  }

  Color _statusColor(String status) {
    if (status == 'approved') return Colors.tealAccent;
    if (status == 'rejected') return Colors.redAccent;
    return Colors.orangeAccent;
  }

  String _statusLabel(String status) {
    if (status == 'approved') return '✅ Approved';
    if (status == 'rejected') return '❌ Rejected';
    return '⏳ Pending';
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ── Reusable text field ──────────────────────
  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
      ),
    );
  }

  // ── Small stat chip ──────────────────────────
  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.25),
              color.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // PHARMACY CARD (Tab 1)  ← UPDATED with Activate/Deactivate
  // ══════════════════════════════════════════════
  Widget _pharmacyCard(Map<String, dynamic> p) {
    final String status = _verifyStatus(p);
    final Color statusColor = _statusColor(status);
    final String statusLabel = _statusLabel(status);
    final bool isActive = p['is_active'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromRGBO(30, 40, 80, 0.95),
            Color.fromRGBO(20, 30, 60, 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pharmacy icon circle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.local_pharmacy,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Pharmacy info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if ((p['license_number'] ?? '').isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.badge,
                              color: Colors.blueAccent,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p['license_number'],
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      if ((p['owner_name'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p['owner_name'],
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((p['phone'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              color: Colors.white54,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p['phone'],
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((p['address'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white54,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                p['address'],
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Status badges column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Active badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color.fromRGBO(105, 240, 174, 0.20)
                            : const Color.fromRGBO(150, 150, 150, 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? Colors.greenAccent.withValues(alpha: 0.6)
                              : Colors.grey.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        isActive ? '🟢 Active' : '⚫ Inactive',
                        style: TextStyle(
                          color: isActive ? Colors.greenAccent : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Verification badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Divider + Action buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // Row 1: Edit + Delete
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                          side: const BorderSide(
                            color: Colors.blueAccent,
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _showEditDialog(p),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text(
                          'Edit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showDeleteDialog(p),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: Activate / Deactivate (full width)  ← NEW
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive
                          ? Colors.orangeAccent
                          : Colors.greenAccent,
                      side: BorderSide(
                        color: isActive
                            ? Colors.orangeAccent
                            : Colors.greenAccent,
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _toggleActive(p),
                    icon: Icon(
                      isActive ? Icons.block : Icons.check_circle_outline,
                      size: 16,
                    ),
                    label: Text(
                      isActive ? 'Deactivate' : 'Activate',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // VERIFY CARD (Tab 3)
  // ══════════════════════════════════════════════
  Widget _verifyCard(Map<String, dynamic> p) {
    final String status = _verifyStatus(p);
    final Color statusColor = _statusColor(status);
    final String statusLabel = _statusLabel(status);
    final bool isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.12),
            const Color.fromRGBO(20, 25, 50, 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.local_pharmacy,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if ((p['license_number'] ?? '').isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.badge,
                              color: Colors.blueAccent,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p['license_number'],
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      if ((p['owner_name'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p['owner_name'],
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((p['address'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white54,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                p['address'],
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: isPending
                ? Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _updateVerification(p, 'approve'),
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.black,
                            size: 16,
                          ),
                          label: const Text(
                            'Approve',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _updateVerification(p, 'reject'),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text(
                            'Reject',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: const BorderSide(
                          color: Colors.orangeAccent,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _updateVerification(p, 'pending'),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text(
                        'Reset to Pending',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 1: Pharmacies
  // ══════════════════════════════════════════════
  Widget _buildAllPharmaciesTab() {
    final int total = allPharmacies.length;
    final int active = allPharmacies
        .where((p) => p['is_active'] == true)
        .length;
    final int verified = allPharmacies
        .where((p) => p['is_verified'] == true)
        .length;
    final int pending = allPharmacies
        .where((p) => p['is_verified'] == null)
        .length;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              hintText: 'Search pharmacy, license, owner...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color.fromRGBO(255, 255, 255, 0.10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Colors.blueAccent,
                  width: 1.5,
                ),
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () {
                        searchController.clear();
                        _filterPharmacies();
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Stat chips
        if (!loadingPharmacies)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _statChip('Total', '$total', Colors.white70),
                const SizedBox(width: 6),
                _statChip('Active', '$active', Colors.greenAccent),
                const SizedBox(width: 6),
                _statChip('Verified', '$verified', Colors.tealAccent),
                const SizedBox(width: 6),
                _statChip('Pending', '$pending', Colors.orangeAccent),
              ],
            ),
          ),

        // List
        Expanded(
          child: loadingPharmacies
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                )
              : filteredPharmacies.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_pharmacy_outlined,
                        color: Colors.white24,
                        size: 60,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No pharmacies found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllPharmacies,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredPharmacies.length,
                    itemBuilder: (_, i) => _pharmacyCard(filteredPharmacies[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // TAB 2: Add Pharmacy
  // ══════════════════════════════════════════════
  Widget _buildAddPharmacyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color.fromRGBO(21, 101, 192, 0.40),
                  Color.fromRGBO(0, 131, 143, 0.30),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.5),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.lightBlueAccent,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pharmacies added here will appear in the pharmacist sign-up list.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Section label
          const Text(
            'Pharmacy Details',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          _field(nameCtrl, 'Pharmacy Name *', Icons.local_pharmacy),
          const SizedBox(height: 12),
          _field(licCtrl, 'License Number *', Icons.badge_outlined),
          const SizedBox(height: 12),

          const Text(
            'Contact & Location (optional)',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          _field(addressCtrl, 'Address', Icons.location_on_outlined),
          const SizedBox(height: 12),
          _field(
            phoneCtrl,
            'Phone Number',
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _field(ownerCtrl, 'Owner Name', Icons.person_outline),
          const SizedBox(height: 28),

          // Add button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              onPressed: saving ? null : _addPharmacy,
              icon: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add_business, color: Colors.white),
              label: Text(
                saving ? 'Saving...' : 'Add Pharmacy',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 3: Pharmacy Verification
  // ══════════════════════════════════════════════
  Widget _buildVerificationTab() {
    final int pendingCount = verifyPharmacies
        .where((p) => _verifyStatus(p) == 'pending')
        .length;
    final int approvedCount = verifyPharmacies
        .where((p) => _verifyStatus(p) == 'approved')
        .length;
    final int rejectedCount = verifyPharmacies
        .where((p) => _verifyStatus(p) == 'rejected')
        .length;

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterOptions.map((f) {
                final bool isSelected = selectedFilter == f;
                Color chipColor = Colors.blueAccent;
                if (f == 'Approved') chipColor = Colors.tealAccent;
                if (f == 'Rejected') chipColor = Colors.redAccent;
                if (f == 'Pending') chipColor = Colors.orangeAccent;

                return GestureDetector(
                  onTap: () {
                    setState(() => selectedFilter = f);
                    _loadVerifyPharmacies();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                chipColor.withValues(alpha: 0.35),
                                chipColor.withValues(alpha: 0.15),
                              ],
                            )
                          : null,
                      color: isSelected
                          ? null
                          : const Color.fromRGBO(255, 255, 255, 0.08),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? chipColor
                            : Colors.white.withValues(alpha: 0.2),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: isSelected ? chipColor : Colors.white60,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Stat chips
        if (!loadingVerify)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _statChip(
                  'Showing',
                  '${verifyPharmacies.length}',
                  Colors.white70,
                ),
                const SizedBox(width: 6),
                _statChip('Pending', '$pendingCount', Colors.orangeAccent),
                const SizedBox(width: 6),
                _statChip('Approved', '$approvedCount', Colors.tealAccent),
                const SizedBox(width: 6),
                _statChip('Rejected', '$rejectedCount', Colors.redAccent),
              ],
            ),
          ),

        // List
        Expanded(
          child: loadingVerify
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent),
                )
              : verifyPharmacies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        color: Colors.white24,
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No $selectedFilter pharmacies',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVerifyPharmacies,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: verifyPharmacies.length,
                    itemBuilder: (_, i) => _verifyCard(verifyPharmacies[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // MAIN BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/guardianpharmapills.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── TOP BAR ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.local_pharmacy,
                          color: Colors.blueAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GuardianPharma',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Regulatory Authority',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        onPressed: () {
                          _loadAllPharmacies();
                          _loadVerifyPharmacies();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white70),
                        onPressed: () async {
                          await supabase.auth.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyLogin(),
                              ),
                              (r) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // ── HEADER GRADIENT BANNER ────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF00838F)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REGULATORY AUTHORITY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              'Pharmacy Management Panel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── TAB BAR ───────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 11),
                    tabs: const [
                      Tab(text: '🏥 Pharmacies'),
                      Tab(text: '➕ Add Pharmacy'),
                      Tab(text: '✅ Verification'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ── TAB CONTENT ───────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllPharmaciesTab(),
                      _buildAddPharmacyTab(),
                      _buildVerificationTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
