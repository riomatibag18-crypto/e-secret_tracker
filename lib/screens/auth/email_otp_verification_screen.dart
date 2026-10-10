import 'package:e_secret_tracker/services/auth_service.dart';
import 'package:e_secret_tracker/services/email_otp_service.dart';
import 'package:e_secret_tracker/services/otp_session_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class EmailOtpVerificationScreen extends StatefulWidget {
  const EmailOtpVerificationScreen({super.key, required this.challenge});

  final PendingOtpChallenge challenge;

  @override
  State<EmailOtpVerificationScreen> createState() =>
      _EmailOtpVerificationScreenState();
}

class _EmailOtpVerificationScreenState
    extends State<EmailOtpVerificationScreen> {
  final _authService = AuthService();
  final _emailOtpService = EmailOtpService();
  final _codeController = TextEditingController();

  bool _isSubmitting = false;
  bool _isResending = false;
  late String _activeChallengeId;

  @override
  void initState() {
    super.initState();
    _activeChallengeId = widget.challenge.challengeId;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<bool> _cancelAndSignOut() async {
    await _authService.signOut();
    OtpSessionService.instance.reset();
    return false;
  }

  String _mapOtpError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'resource-exhausted':
          return 'Please wait a bit before requesting another code.';
        case 'deadline-exceeded':
          return 'Code expired. Request a new code.';
        case 'permission-denied':
          return 'Invalid code. Please try again.';
        case 'failed-precondition':
          return 'This code was already used. Request a new one.';
        case 'not-found':
          return 'Code not found. Request a new one.';
        case 'unavailable':
          return 'OTP service is temporarily unavailable. Try again shortly.';
        default:
          return error.message ?? 'Could not process the OTP request.';
      }
    }

    return 'Could not process the OTP request.';
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      final challengeId = await _emailOtpService.startLoginChallenge(
        email: widget.challenge.email,
      );
      _activeChallengeId = challengeId;
      OtpSessionService.instance.startChallenge(
        PendingOtpChallenge(
          purpose: OtpPurpose.emailLogin,
          challengeId: challengeId,
          email: widget.challenge.email,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent. Check your inbox and spam.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapOtpError(error))));
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter the 6-digit code.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _emailOtpService.verifyLoginChallenge(
        challengeId: _activeChallengeId,
        code: code,
      );

      OtpSessionService.instance.reset();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification successful.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or expired code. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFFF9500);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: WillPopScope(
        onWillPop: _cancelAndSignOut,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _isSubmitting ? null : _cancelAndSignOut,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Email Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the 6-digit code sent to ${widget.challenge.email}.',
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _codeController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter 6-digit code',
                    hintStyle: const TextStyle(color: Color(0xFF666666)),
                    prefixIcon: const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF666666),
                    ),
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
                      borderSide: const BorderSide(color: themeColor),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _isResending) ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: (_isSubmitting || _isResending)
                        ? null
                        : _resendCode,
                    child: _isResending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF9500),
                            ),
                          )
                        : const Text(
                            'Resend Code',
                            style: TextStyle(
                              color: Color(0xFFFF9500),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
