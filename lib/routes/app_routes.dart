import 'package:camera/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/pages/record_page.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class AppRoutes {
  static final GoRouter router = GoRouter(
    observers: [routeObserver],
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(path: '/record', builder: (context, state) => const RecordPage()),
    ],
  );
}
