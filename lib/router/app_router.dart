import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:navbr/screens/charts_download_screen.dart';
import 'package:navbr/screens/charts_view_screen.dart';
import 'package:navbr/screens/main_shell.dart';
import 'package:navbr/screens/flights_screen.dart';
import 'package:navbr/screens/navigation_map_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/charts',
  observers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/airports',
            builder: (context, state) => const PlaceholderScreen(
              title: 'Aeroportos',
              icon: Icons.local_airport,
            ),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/map',
            builder: (context, state) => const NavigationMapScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/charts',
            builder: (context, state) => const ChartsViewScreen(),
            routes: [
              GoRoute(
                path: 'download',
                builder: (context, state) => const ChartsDownloadScreen(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/flights',
            builder: (context, state) => const FlightsScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const PlaceholderScreen(
              title: 'Opções',
              icon: Icons.settings,
            ),
          ),
        ]),
      ],
    ),
  ],
);
