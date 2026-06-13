import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';
import 'pharmacist_homepage.dart';
import 'regulatoryauthority_homepage.dart';
import 'pharmacy_wrapper_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<String?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _getRole();
  }

  Future<String?> _getRole() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return null;
    final userId = session.user.id;

    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        final res = await client
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .maybeSingle();
        final role = res?['role'] as String?;
        if (role != null && role.isNotEmpty) return role;
      } catch (e) {
        debugPrint("AuthGate attempt $attempt error: $e");
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const MyLogin();

    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 16),
                  Text(
                    "Loading your dashboard...",
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Could not load your profile.\nPlease log in again.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MyLogin()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      "Go to Login",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final role = snapshot.data!;
        debugPrint("✅ AuthGate resolved role: $role");

        // ✅ Regulatory goes directly — no pharmacy needed
        if (role == "regulatory") {
          return const RegulatoryHome();
        }

        // ✅ Pharmacist goes through PharmacyWrapperPage FIRST
        // then to dashboard
        return PharmacyWrapperPage(child: const PharmacistHome());
      },
    );
  }
}
