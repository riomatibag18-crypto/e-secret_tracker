import 'package:e_secret_tracker/config/mapbox_config.dart';
import 'package:e_secret_tracker/screens/auth/login_screen.dart';
import 'package:e_secret_tracker/screens/auth/email_otp_verification_screen.dart';
import 'package:e_secret_tracker/screens/main/home_tab.dart';
import 'package:e_secret_tracker/services/app_messenger_service.dart';
import 'package:e_secret_tracker/services/app_theme_service.dart';
import 'package:e_secret_tracker/services/otp_session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AppThemeService.instance.loadTheme();
  final effectiveMapboxToken = effectiveMapboxAccessToken;
  if (effectiveMapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(effectiveMapboxToken);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'E-Secret Tracker',
          scaffoldMessengerKey:
              AppMessengerService.instance.rootScaffoldMessengerKey,
          themeMode: AppThemeService.instance.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF4F4F4),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF8A2A),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF111111),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF8A2A),
              brightness: Brightness.dark,
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Widget _buildLoadingShell() {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFFF9500))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: OtpSessionService.instance,
      builder: (context, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingShell();
            }

            final challenge = OtpSessionService.instance.challenge;
            if (challenge != null) {
              return EmailOtpVerificationScreen(challenge: challenge);
            }

            if (OtpSessionService.instance.isProcessingLogin) {
              return _buildLoadingShell();
            }

            if (snapshot.hasData && !(snapshot.data?.isAnonymous ?? false)) {
              return const HomeTab();
            }

            return const LoginScreen();
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
