import 'package:flutter/material.dart';

class AppMessengerService {
  AppMessengerService._();

  static final AppMessengerService instance = AppMessengerService._();

  final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  ScaffoldMessengerState? get currentState =>
      rootScaffoldMessengerKey.currentState;

  void showSnackBar(SnackBar snackBar) {
    currentState?.showSnackBar(snackBar);
  }

  void clearSnackBars() {
    currentState?.clearSnackBars();
  }
}