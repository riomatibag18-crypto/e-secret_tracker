import 'package:flutter/foundation.dart';

enum OtpPurpose { emailLogin }

class PendingOtpChallenge {
  const PendingOtpChallenge({
    required this.purpose,
    required this.challengeId,
    required this.email,
  });

  final OtpPurpose purpose;
  final String challengeId;
  final String email;
}

class OtpSessionService extends ChangeNotifier {
  OtpSessionService._();

  static final OtpSessionService instance = OtpSessionService._();

  PendingOtpChallenge? _challenge;
  bool _isProcessingLogin = false;

  PendingOtpChallenge? get challenge => _challenge;
  bool get isProcessingLogin => _isProcessingLogin;

  void beginProcessingLogin() {
    if (_isProcessingLogin) {
      return;
    }
    _isProcessingLogin = true;
    notifyListeners();
  }

  void endProcessingLogin() {
    if (!_isProcessingLogin) {
      return;
    }
    _isProcessingLogin = false;
    notifyListeners();
  }

  void startChallenge(PendingOtpChallenge challenge) {
    _challenge = challenge;
    notifyListeners();
  }

  void clearChallenge() {
    if (_challenge == null) {
      return;
    }
    _challenge = null;
    notifyListeners();
  }

  void reset() {
    _challenge = null;
    _isProcessingLogin = false;
    notifyListeners();
  }
}
