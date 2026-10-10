import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:e_secret_tracker/screens/auth/forgot_password_otp_screen.dart';
import 'package:e_secret_tracker/services/email_otp_service.dart';

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});

  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailOtpService = EmailOtpService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF666666)),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF666666)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF444444)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF444444)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF9500)),
      ),
    );
  }

  String _mapResetStartError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'permission-denied':
          final detail = (error.message ?? '').toLowerCase();
          final looksLikeAppCheck =
              detail.contains('app check') ||
              detail.contains('attestation') ||
              detail.contains('debug token') ||
              detail.contains('firebaseappcheck');
          if (looksLikeAppCheck) {
            return 'Firebase blocked this request due to App Check. Register your Android debug token in Firebase Console, then try again.';
          }
          return error.message ?? 'Permission denied. Please try again.';
        case 'resource-exhausted':
          return 'Please wait a bit before requesting another code.';
        case 'deadline-exceeded':
          return 'Request timed out. Please try again.';
        case 'invalid-argument':
          return error.message ?? 'Please enter a valid email.';
        case 'unavailable':
          return 'OTP service is temporarily unavailable. Please try again.';
        default:
          return error.message ?? 'Could not send code. Please try again.';
      }
    }

    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length).trim();
    }

    return 'Could not send code. Please try again.';
  }

  Future<void> _sendResetCode() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final email = _emailController.text.trim().toLowerCase();

    setState(() => _isLoading = true);

    try {
      final challengeId = await _emailOtpService.startPasswordResetChallenge(
        email: email,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              ForgotPasswordOtpScreen(email: email, challengeId: challengeId),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapResetStartError(error))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Color(0xFFFF9500),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF9500),
                            width: 2,
                          ),
                        ),
                      ),
                      const Column(
                        children: [
                          Icon(Icons.wifi, color: Color(0xFFFF9500), size: 20),
                          SizedBox(height: 2),
                          Icon(Icons.pedal_bike, color: Colors.white, size: 50),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Center(
                  child: Text(
                    'E-Secret Tracker',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Forgot Password',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your account email to receive a verification code.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tip: Use the same email you used for sign in and check spam/junk.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration(
                    hint: 'Email address',
                    prefixIcon: Icons.mail_outline,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!text.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendResetCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9500),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Send Verification Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text(
                      'Back to Sign In',
                      style: TextStyle(
                        color: Color(0xFFFF9500),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
