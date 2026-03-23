
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/space_screen.dart';
import '../../../providers/auth_provider.dart';
import 'package:flutter/material.dart';

// Provide the router
final routerProvider = Provider<GoRouter>((ref) {
  print('routerProvider: getting evaluated');
  final notifier = ValueNotifier<Object?>(null);
  ref.onDispose(notifier.dispose);

  // Notify GoRouter whenever authState changes
  ref.listen(authStateProvider, (_, next) {
    print('routerProvider: authStateProvider changed, isInitializing=${next.isInitializing}, user=${next.user?.id}');
    notifier.value = next;
  });

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/splash',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      print('GoRouter.redirect: path=${state.uri.path}, isInitializing=${authState.isInitializing}, hasUser=${authState.user != null}');

      if (authState.isInitializing) {
        print('GoRouter.redirect: still initializing, stay on /splash');
        return '/splash';
      }

      final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/signup';
      final isSplash = state.uri.path == '/splash';
      final isAuth = authState.user != null;

      if (!isAuth) {
        if (!isAuthRoute) {
          print('GoRouter.redirect: redirecting to /login');
          return '/login';
        }
      } else {
        if (isAuthRoute || isSplash) {
          print('GoRouter.redirect: redirecting to /');
          return '/';
        }
      }

      print('GoRouter.redirect: no redirect');
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final title = state.extra as String?;
          return ChatScreen(chatId: id, title: title);
        },
      ),
      GoRoute(
        path: '/space/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.extra as String? ?? 'Space';
          return SpaceScreen(spaceId: id, spaceName: name);
        },
      ),
    ],
  );
});
