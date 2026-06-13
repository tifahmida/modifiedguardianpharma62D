import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

// =========================
// GLOBAL PHARMACY SESSION
// =========================
class PharmacySession {
  static String? pharmacyId;
  static String? pharmacyName;
  static String? licenseNumber;
  static String? pharmacyAddress;
  static String? pharmacyPhone;
  static String? ownerName;

  static void clear() {
    pharmacyId = null;
    pharmacyName = null;
    licenseNumber = null;
    pharmacyAddress = null;
    pharmacyPhone = null;
    ownerName = null;
  }

  static bool get isLoaded => pharmacyId != null;
}

// =========================
// WRAPPER PAGE
// Simplified — no selector needed
// pharmacy always set during signup
// =========================
class PharmacyWrapperPage extends StatefulWidget {
  final Widget child;
  const PharmacyWrapperPage({super.key, required this.child});

  @override
  State<PharmacyWrapperPage> createState() => _PharmacyWrapperPageState();
}

class _PharmacyWrapperPageState extends State<PharmacyWrapperPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadPharmacy();
  }

  Future<void> _loadPharmacy() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          loading = false;
          error = "not_logged_in";
        });
        return;
      }

      // Get pharmacy_id from profile
      final profile = await supabase
          .from('profiles')
          .select('pharmacy_id')
          .eq('id', userId)
          .maybeSingle();

      final String? pharmacyId = profile?['pharmacy_id']?.toString();

      // ✅ If no pharmacy — something went wrong
      // during signup. Show error, not selector.
      if (pharmacyId == null || pharmacyId.isEmpty) {
        setState(() {
          loading = false;
          error = "no_pharmacy";
        });
        return;
      }

      // Load pharmacy details
      final pharmacy = await supabase
          .from('pharmacies')
          .select()
          .eq('id', pharmacyId)
          .maybeSingle();

      if (pharmacy == null) {
        setState(() {
          loading = false;
          error = "pharmacy_not_found";
        });
        return;
      }

      // ✅ Check if pharmacy is still active
      if (pharmacy['is_active'] != true) {
        setState(() {
          loading = false;
          error = "pharmacy_inactive";
        });
        return;
      }

      // Save in session
      PharmacySession.pharmacyId = pharmacy['id'].toString();
      PharmacySession.pharmacyName = pharmacy['name'] ?? '';
      PharmacySession.licenseNumber = pharmacy['license_number'] ?? '';
      PharmacySession.pharmacyAddress = pharmacy['address'] ?? '';
      PharmacySession.pharmacyPhone = pharmacy['phone'] ?? '';
      PharmacySession.ownerName = pharmacy['owner_name'] ?? '';

      setState(() {
        loading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _logout() async {
    PharmacySession.clear();
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MyLogin()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── LOADING ──────────────────────────────
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blueAccent),
              SizedBox(height: 16),
              Text(
                "Loading your pharmacy...",
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      );
    }

    // ── NOT LOGGED IN ─────────────────────────
    if (error == "not_logged_in") {
      return const MyLogin();
    }

    // ── NO PHARMACY LINKED ────────────────────
    // This should never happen if signup
    // is completed correctly
    if (error == "no_pharmacy") {
      return _ErrorScreen(
        icon: Icons.local_pharmacy_outlined,
        iconColor: Colors.orange,
        title: "No Pharmacy Linked",
        message:
            "Your account is not linked to any pharmacy.\n\nThis may have happened due to an incomplete signup.\n\nPlease contact your administrator or sign up again.",
        onRetry: _loadPharmacy,
        onLogout: _logout,
      );
    }

    // ── PHARMACY NOT FOUND ────────────────────
    if (error == "pharmacy_not_found") {
      return _ErrorScreen(
        icon: Icons.search_off,
        iconColor: Colors.orange,
        title: "Pharmacy Not Found",
        message:
            "The pharmacy linked to your account could not be found.\n\nIt may have been removed by the Regulatory Authority.\n\nPlease contact your administrator.",
        onRetry: _loadPharmacy,
        onLogout: _logout,
      );
    }

    // ── PHARMACY DEACTIVATED ──────────────────
    if (error == "pharmacy_inactive") {
      return _ErrorScreen(
        icon: Icons.block,
        iconColor: Colors.redAccent,
        title: "Pharmacy Deactivated",
        message:
            "Your pharmacy has been deactivated by the Regulatory Authority.\n\nYou cannot access the system until it is reactivated.\n\nPlease contact the Regulatory Authority.",
        showRetry: false,
        onLogout: _logout,
      );
    }

    // ── GENERIC ERROR ─────────────────────────
    if (error != null) {
      return _ErrorScreen(
        icon: Icons.error_outline,
        iconColor: Colors.redAccent,
        title: "Something Went Wrong",
        message: "An unexpected error occurred.\nPlease try again.",
        onRetry: _loadPharmacy,
        onLogout: _logout,
      );
    }

    // ── SUCCESS — show dashboard ──────────────
    return widget.child;
  }
}

// =========================
// REUSABLE ERROR SCREEN
// =========================
class _ErrorScreen extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onLogout;
  final bool showRetry;

  const _ErrorScreen({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.onRetry,
    required this.onLogout,
    this.showRetry = true,
  });

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
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: iconColor.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(icon, color: iconColor, size: 48),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Retry button
                    if (showRetry && onRetry != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            "Try Again",
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout, color: Colors.white54),
                        label: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
