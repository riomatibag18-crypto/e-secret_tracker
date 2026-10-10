import 'package:e_secret_tracker/screens/auth/forgot_screen.dart';
import 'package:e_secret_tracker/screens/auth/registration_screen.dart';
import 'package:e_secret_tracker/services/app_messenger_service.dart';
import 'package:e_secret_tracker/services/auth_service.dart';
import 'package:e_secret_tracker/services/email_otp_service.dart';
import 'package:e_secret_tracker/services/otp_session_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _messengerService = AppMessengerService.instance;
  final _authService = AuthService();
  final _emailOtpService = EmailOtpService();
  final _otpSessionService = OtpSessionService.instance;

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _loginErrorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _mapLoginError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'resource-exhausted':
          return 'Please wait a bit, then request another OTP code.';
        case 'deadline-exceeded':
          return 'OTP request timed out. Please try again.';
        case 'permission-denied':
          return 'OTP verification is not allowed for this account.';
        case 'unavailable':
          return 'OTP service is temporarily unavailable. Please try again.';
        default:
          return error.message ?? 'Could not start OTP verification.';
      }
    }

    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length).trim();
    }

    return _authService.mapAuthError(error);
  }

  void _showLoginError(String message) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(message),
    );

    _messengerService.clearSnackBars();
    _messengerService.showSnackBar(snackBar);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Sign In Failed'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _handleLogin() async {
    _otpSessionService.reset();
    if (mounted) {
      setState(() => _loginErrorMessage = null);
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    _otpSessionService.beginProcessingLogin();

    try {
      final userCredential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('No authenticated user.');
      }

      String challengeId;
      try {
        challengeId = await _emailOtpService.startLoginChallenge(email: email);
      } catch (error) {
        // OTP challenge is mandatory. If challenge creation fails, do not keep
        // the user authenticated.
        await _authService.signOut();
        rethrow;
      }

      _otpSessionService.startChallenge(
        PendingOtpChallenge(
          purpose: OtpPurpose.emailLogin,
          challengeId: challengeId,
          email: email,
        ),
      );
      _otpSessionService.endProcessingLogin();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email.'),
          ),
        );
      }
    } catch (error) {
      _otpSessionService.reset();
      if (!mounted) {
        return;
      }
      final message = _mapLoginError(error);
      _showLoginError(message);
      setState(() {
        _loginErrorMessage = message;
      });
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
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Bike Icon with WiFi
              Stack(
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
                  Column(
                    children: [
                      const Icon(
                        Icons.wifi,
                        color: Color(0xFFFF9500),
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Icon(Icons.pedal_bike, color: Colors.white, size: 50),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // App Title and Tagline
              const Text(
                'E-Secret Tracker',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track your routes, secure your journey',
                style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Welcome Back Section
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to continue tracking',
                      style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Email Input
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email address',
                  hintStyle: const TextStyle(color: Color(0xFF666666)),
                  prefixIcon: const Icon(
                    Icons.mail_outline,
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
                    borderSide: const BorderSide(color: Color(0xFFFF9500)),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              // Password Input
              TextField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Color(0xFF666666)),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF666666),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF666666),
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
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
                    borderSide: const BorderSide(color: Color(0xFFFF9500)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Color(0xFFFF9500), fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_loginErrorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A2222),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF7A3A3A)),
                  ),
                  child: Text(
                    _loginErrorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFFD6D6),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
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
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              // Sign Up Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegistrationScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        color: Color(0xFFFF9500),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
