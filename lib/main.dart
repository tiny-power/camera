// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, prefer_typing_uninitialized_variables, strict_top_level_inference

import 'dart:async';
import 'dart:io';

import 'package:hand_camera/providers/banner_model.dart';
import 'package:hand_camera/providers/native_model.dart';
import 'package:hand_camera/providers/purchage_model.dart';
import 'package:hand_camera/providers/reward_model.dart';
import 'package:hand_camera/providers/rewarder_model.dart';
import 'package:hand_camera/providers/seconder_model.dart';
import 'package:hand_camera/providers/splash_model.dart';
import 'package:hand_camera/providers/udider_model.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:dio/dio.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'routes/app_routes.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';
import 'package:event_bus/event_bus.dart';

final EventBus eventBus = EventBus();
final dio = Dio();

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await initializeRevenueCat();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const MyApp());
}

Future<void> initializeRevenueCat() async {
  String apiKey;
  if (Platform.isIOS) {
    apiKey = 'appl_jWvcrHaKDyVsrBUoyPIXjzWRUhl';
  } else if (Platform.isAndroid) {
    apiKey = 'test_XeYidoxQMAQYnPozbbOgwXxrdaq';
  } else {
    throw UnsupportedError('Platform not supported');
  }
  await Purchases.configure(PurchasesConfiguration(apiKey));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((_) async {
      await AppTrackingTransparency.requestTrackingAuthorization();
    });
    initialization();
  }

  void initialization() async {
    await Future.delayed(const Duration(seconds: 1));
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BannerModel()),
        ChangeNotifierProvider(create: (_) => NativeModel()),
        ChangeNotifierProvider(create: (_) => PurchageModel()),
        ChangeNotifierProvider(create: (_) => RewardModel()),
        ChangeNotifierProvider(create: (_) => RewarderModel()),
        ChangeNotifierProvider(create: (_) => SeconderModel()),
        ChangeNotifierProvider(create: (_) => SplashModel()),
        ChangeNotifierProvider(create: (_) => UdiderModel()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: FlexThemeData.light(scheme: FlexScheme.shadYellow),
        darkTheme: FlexThemeData.dark(scheme: FlexScheme.shadYellow),
        themeMode: ThemeMode.system,
        routerConfig: AppRoutes.router,
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        builder: EasyLoading.init(),
      ),
    );
  }
}
