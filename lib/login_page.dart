import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_page.dart';
import 'auth_gate.dart';

class MyLogin extends StatefulWidget {
  const MyLogin({super.key});

  @override
  State<MyLogin> createState() => _MyLoginState();
}

class _MyLoginState extends State<MyLogin> {
  bool rememberMe = false;
  bool loading = false;
  bool _passwordVisible = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final licenseController = TextEditingController();

  String selectedRole = "pharmacist";

  final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  final RegExp _licenseRegex = RegExp(r'^\d{16}$');

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    licenseController.dispose();
    super.dispose();
  }

  String? _getEmailError(String email) {
    if (email.isEmpty) return "Email is required";
    if (!_emailRegex.hasMatch(email)) return "Enter a valid email address";
    return null;
  }

  // ── LICENSE VALIDATION ────────────────────────────────────
  // Shows a clear message when license field is empty or wrong format.

  String? _getLicenseError(String license) {
    if (license.isEmpty) {
      return "Please enter your License Number to continue";
    }
    if (!_licenseRegex.hasMatch(license)) {
      return "License number must be exactly 16 digits";
    }
    return null;
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final license = licenseController.text.trim();

    // Step 1: Validate email
    final emailError = _getEmailError(email);
    if (emailError != null) {
      _error(emailError);
      return;
    }

    // Step 2: Validate password
    if (password.isEmpty) {
      _error("Password is required");
      return;
    }

    if (password.length < 8) {
      _error("Password must be at least 8 characters");
      return;
    }

    // Step 3: Validate license BEFORE attempting login
    // This runs first so the user sees the error immediately
    // without any network call being made yet.
    if (selectedRole == "regulatory") {
      final licenseError = _getLicenseError(license);
      if (licenseError != null) {
        _error(licenseError);
        return;
      }
    }

    setState(() => loading = true);

    try {
      await Supabase.instance.client.auth.signOut();

      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) throw "Login failed";

      // Step 4: For regulatory role, also verify against DB
      if (selectedRole == "regulatory") {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('license_number, role')
            .eq('id', res.user!.id)
            .maybeSingle();

        if (profile == null) {
          await Supabase.instance.client.auth.signOut();
          _error("Profile not found");
          setState(() => loading = false);
          return;
        }

        if (profile['role'] != 'regulatory') {
          await Supabase.instance.client.auth.signOut();
          _error("This account is not a Regulatory Authority account");
          setState(() => loading = false);
          return;
        }

        if (profile['license_number'] != license) {
          await Supabase.instance.client.auth.signOut();
          _error("License number does not match our records");
          setState(() => loading = false);
          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } on AuthException catch (e) {
      _error(e.message);
    } catch (e) {
      _error(e.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    final emailError = _getEmailError(email);
    if (emailError != null) {
      _error("Please enter a valid email first");
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset email sent"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _error(e.toString());
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

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
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.25)),
          ),
          Center(
            child: SingleChildScrollView(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    width: 350,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(0, 0, 0, 0.35),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color.fromRGBO(255, 255, 255, 0.15),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pharmacy icon
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color.fromRGBO(255, 255, 255, 0.08),
                            border: Border.all(
                              color: const Color.fromRGBO(255, 255, 255, 0.12),
                            ),
                          ),
                          child: const Icon(
                            Icons.local_pharmacy_rounded,
                            color: Colors.blueAccent,
                            size: 42,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Welcome Back",
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 26),

                        // EMAIL
                        _input(emailController, "Email", Icons.email_outlined),
                        const SizedBox(height: 12),

                        // PASSWORD with show/hide toggle
                        TextField(
                          controller: passwordController,
                          obscureText: !_passwordVisible,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Colors.white70,
                            ),
                            hintText: "Password (min 8 characters)",
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color.fromRGBO(
                              255,
                              255,
                              255,
                              0.08,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ROLE DROPDOWN
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButton<String>(
                            value: selectedRole,
                            dropdownColor: Colors.black,
                            underline: const SizedBox(),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white),
                            items: const [
                              DropdownMenuItem(
                                value: "pharmacist",
                                child: Text("Pharmacist"),
                              ),
                              DropdownMenuItem(
                                value: "regulatory",
                                child: Text("Regulatory Authority"),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedRole = value!;
                                // Clear license field when switching roles
                                licenseController.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // LICENSE FIELD — only shown for regulatory role
                        if (selectedRole == "regulatory") ...[
                          // Orange info box reminding user to enter license
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(255, 152, 0, 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color.fromRGBO(255, 152, 0, 0.4),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 14,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'License Number is required for Regulatory Authority login',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // License number input field
                          _input(
                            licenseController,
                            "License Number (16 digits)",
                            Icons.badge_outlined,
                            keyboardType: TextInputType.number,
                            maxLength: 16,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              "Must be exactly 16 numeric digits",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // REMEMBER ME + FORGOT PASSWORD
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: rememberMe,
                                  onChanged: (v) =>
                                      setState(() => rememberMe = v!),
                                  activeColor: Colors.blueAccent,
                                ),
                                const Text(
                                  "Remember me",
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: forgotPassword,
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(color: Colors.blueAccent),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // LOGIN BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                            ),
                            onPressed: loading ? null : login,
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "Log In",
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // SIGN UP LINK
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "Don't have an account? Sign Up",
                            style: TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPass = false,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
        counterStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
