import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class EmailOtpService {
  EmailOtpService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  static const _startResetUrl =
      'https://us-central1-e-secret-tracker.cloudfunctions.net/startEmailOtpPasswordResetHttp';
  static const _verifyResetUrl =
      'https://us-central1-e-secret-tracker.cloudfunctions.net/verifyEmailOtpPasswordResetHttp';

  Future<String> startLoginChallenge({required String email}) async {
    await FirebaseAuth.instance.currentUser?.getIdToken(true);

    final callable = _functions.httpsCallable('startEmailOtpLogin');
    HttpsCallableResult result;
    try {
      result = await callable.call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'unauthenticated') {
        rethrow;
      }

      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      result = await callable.call({'email': email});
    }

    final data = Map<String, dynamic>.from(result.data as Map);
    final challengeId = (data['challengeId'] as String?)?.trim();
    if (challengeId == null || challengeId.isEmpty) {
      throw Exception('Challenge was not created.');
    }
    return challengeId;
  }

  Future<void> verifyLoginChallenge({
    required String challengeId,
    required String code,
  }) async {
    final callable = _functions.httpsCallable('verifyEmailOtpLogin');
    await callable.call({'challengeId': challengeId, 'code': code});
  }

  Future<String> startPasswordResetChallenge({required String email}) async {
    final response = await http.post(
      Uri.parse(_startResetUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractHttpError(response.body));
    }

    final data = _parseJsonMap(response.body);
    final challengeId = (data['challengeId'] as String?)?.trim();
    if (challengeId == null || challengeId.isEmpty) {
      throw Exception('Challenge was not created.');
    }
    return challengeId;
  }

  Future<void> verifyPasswordResetChallenge({
    required String challengeId,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse(_verifyResetUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'challengeId': challengeId,
        'code': code,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractHttpError(response.body));
    }
  }

  Map<String, dynamic> _parseJsonMap(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }

  String _extractHttpError(String body) {
    try {
      final data = _parseJsonMap(body);
      final error = (data['error'] as String?)?.trim();
      if (error != null && error.isNotEmpty) {
        return error;
      }
      final code = (data['code'] as String?)?.trim();
      if (code != null && code.isNotEmpty) {
        return code;
      }
    } catch (_) {}

    return 'Could not send code. Please try again.';
  }
}
