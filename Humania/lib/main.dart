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

part 'models.dart';
part 'auth_pages.dart';
part 'dashboard_pages.dart';
part 'campaign_pages.dart';
part 'request_pages.dart';
part 'profile_pages.dart';
part 'admin_pages.dart';

const firebaseDatabaseUrl =
    'https://humania-d6c36-default-rtdb.asia-southeast1.firebasedatabase.app';

const designatedAdminEmails = {'xyrusfelix@gmail.com'};

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
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  UserAccount? _currentUser;
  String? _role;

  void _signIn(UserAccount user) {
    setState(() {
      _currentUser = user;
      _role = null;
    });
  }

  void _signOut() {
    firebase_auth.FirebaseAuth.instance.signOut();
    setState(() {
      _currentUser = null;
      _role = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Humania',
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff19704f),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff7faf8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xfff7faf8),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
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
            borderSide: BorderSide(color: Color(0xffdce9e1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xff19704f), width: 2),
          ),
        ),
      ),
      home: kIsWeb
          ? const _AdminWebGate()
          : _currentUser == null
          ? LoginPage(onSignedIn: _signIn)
          : _role == null
          ? RolePage(
              showAdmin: _currentUser!.isAdmin,
              onRoleSelected: (role) => setState(() => _role = role),
            )
          : DashboardPage(
              user: _currentUser!,
              onSignOut: _signOut,
              role: _role!,
            ),
    );
  }
}
