import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image_codec;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_theme.dart';
import 'auth/data/auth_error_mapper.dart';
import 'auth/validation/auth_validators.dart';
import 'auth/validation/password_policy.dart';

part 'models.dart';
part 'auth/data/auth_service.dart';
part 'auth/presentation/auth_gate.dart';
part 'auth/presentation/login_page.dart';
part 'auth/presentation/signup_page.dart';
part 'auth/presentation/forgot_password_page.dart';
part 'auth/widgets/auth_text_field.dart';
part 'auth/widgets/password_field.dart';
part 'auth/widgets/password_requirements.dart';
part 'auth/widgets/password_strength_indicator.dart';
part 'auth/widgets/auth_submit_button.dart';
part 'auth/widgets/auth_status_message.dart';
part 'auth_pages.dart';
part 'dashboard_pages.dart';
part 'campaign_pages.dart';
part 'request_pages.dart';
part 'profile_pages.dart';
part 'admin_pages.dart';

const firebaseDatabaseUrl =
    'https://humania-d6c36-default-rtdb.asia-southeast1.firebasedatabase.app';

const designatedAdminEmails = {'xyrusfelix@gmail.com'};

const adminWeb = bool.fromEnvironment('ADMIN_WEB', defaultValue: true);
const adminApp = bool.fromEnvironment('ADMIN_APP', defaultValue: false);
const kindLinkEmerald = Color(0xff2a7f73);
const kindLinkPrimaryDark = Color(0xff1f5f57);
const kindLinkBlue = Color(0xff4a90e2);
const kindLinkCream = Color(0xfffafaf7);
const kindLinkOrange = Color(0xfff4a261);
const kindLinkNavy = Color(0xff263238);
const kindLinkSecondaryText = Color(0xff667085);
const kindLinkSuccess = Color(0xff2e9d63);
const kindLinkWarning = Color(0xfff4b740);
const kindLinkUrgent = Color(0xffd9534f);

class KindLinkLogo extends StatelessWidget {
  const KindLinkLogo({super.key, this.height = 120, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).height < 700) {
      return const SizedBox.shrink();
    }
    return Semantics(
      image: true,
      label: 'KindLink — Connecting Communities with Kindness',
      child: Container(
        height: height,
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kindLinkEmerald.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: kindLinkNavy.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Transform.scale(
            scale: 1.55,
            child: Image.asset(
              'assets/images/kindlink-primary-logo-v2.jpg',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class KindLinkPressScale extends StatefulWidget {
  const KindLinkPressScale({super.key, required this.child});

  final Widget child;

  @override
  State<KindLinkPressScale> createState() => _KindLinkPressScaleState();
}

class _KindLinkPressScaleState extends State<KindLinkPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _setPressed(true),
    onPointerUp: (_) => _setPressed(false),
    onPointerCancel: (_) => _setPressed(false),
    child: AnimatedScale(
      scale: _pressed ? 0.88 : 1,
      duration: Duration(milliseconds: _pressed ? 90 : 170),
      curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

bool isDesignatedAdminEmail(String? email) =>
    email != null && designatedAdminEmails.contains(email.trim().toLowerCase());

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyArj-0jlbVgccZXmygjdZxBUTP80qvEBX0',
        appId: '1:982646246891:android:ef99698cdd6799dafe5dae',
        messagingSenderId: '982646246891',
        projectId: 'humania-d6c36',
        storageBucket: 'humania-d6c36.firebasestorage.app',
        databaseURL: firebaseDatabaseUrl,
      ),
    );
  } else if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.authService});

  final AuthService? authService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? FirebaseAuthService();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KindLink',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.25,
            ),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: kindLinkEmerald,
              brightness: Brightness.light,
            ).copyWith(
              primary: kindLinkEmerald,
              secondary: kindLinkBlue,
              error: kindLinkUrgent,
              surface: Colors.white,
              onSurface: kindLinkNavy,
            ),
        useMaterial3: true,
        scaffoldBackgroundColor: kindLinkCream,
        fontFamily: 'Arial',
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: kindLinkNavy,
          displayColor: kindLinkNavy,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kindLinkCream,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          foregroundColor: kindLinkNavy,
        ),
        iconTheme: const IconThemeData(color: kindLinkNavy, size: 22),
        iconButtonTheme: IconButtonThemeData(
          style:
              IconButton.styleFrom(
                foregroundColor: kindLinkNavy,
                minimumSize: const Size.square(44),
                shape: const CircleBorder(),
              ).copyWith(
                overlayColor: WidgetStatePropertyAll(
                  kindLinkEmerald.withValues(alpha: 0.12),
                ),
                animationDuration: const Duration(milliseconds: 180),
              ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style:
              FilledButton.styleFrom(
                backgroundColor: kindLinkEmerald,
                foregroundColor: Colors.white,
                disabledBackgroundColor: kindLinkEmerald.withValues(
                  alpha: 0.28,
                ),
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size(64, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
                ),
                elevation: 2,
                shadowColor: kindLinkEmerald.withValues(alpha: 0.34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ).copyWith(
                overlayColor: WidgetStatePropertyAll(
                  Colors.white.withValues(alpha: 0.14),
                ),
                elevation: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.pressed) ? 0 : 2,
                ),
                animationDuration: const Duration(milliseconds: 180),
              ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style:
              OutlinedButton.styleFrom(
                foregroundColor: kindLinkPrimaryDark,
                minimumSize: const Size(64, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: kindLinkEmerald.withValues(alpha: 0.45),
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ).copyWith(
                overlayColor: WidgetStatePropertyAll(
                  kindLinkEmerald.withValues(alpha: 0.10),
                ),
                animationDuration: const Duration(milliseconds: 180),
              ),
        ),
        textButtonTheme: TextButtonThemeData(
          style:
              TextButton.styleFrom(
                foregroundColor: kindLinkPrimaryDark,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ).copyWith(
                overlayColor: WidgetStatePropertyAll(
                  kindLinkEmerald.withValues(alpha: 0.10),
                ),
                animationDuration: const Duration(milliseconds: 180),
              ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: kindLinkOrange,
          foregroundColor: Colors.white,
          elevation: 5,
          focusElevation: 7,
          hoverElevation: 7,
          highlightElevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: kindLinkCream,
          selectedColor: kindLinkEmerald.withValues(alpha: 0.16),
          side: BorderSide(color: kindLinkEmerald.withValues(alpha: 0.22)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xffd7e5df)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: kindLinkEmerald, width: 2),
          ),
        ),
      ),
      home: adminApp || (kIsWeb && adminWeb)
          ? const _AdminWebGate()
          : AuthGate(authService: _authService),
    );
  }
}
