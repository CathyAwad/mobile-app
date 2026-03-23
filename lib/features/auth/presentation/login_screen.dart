import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../providers/auth_provider.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usernameController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isObscured = useState(true);
    final authState = ref.watch(authStateProvider);

    final theme = Theme.of(context);

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (!next.isLoading && next.user != null) {
        context.go('/');
      }
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo placeholder
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sync, color: theme.colorScheme.primary, size: 48),
                    const SizedBox(width: 8),
                    Text(
                      'FRONA',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Text('Username or email', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    // Style is mostly handled by AppTheme
                  ),
                ),
                const SizedBox(height: 16),
                Text('Password', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: isObscured.value,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscured.value ? Icons.visibility_off : Icons.visibility,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: () => isObscured.value = !isObscured.value,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (authState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      authState.error!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : () {
                    ref.read(authStateProvider.notifier).login(
                      usernameController.text,
                      passwordController.text,
                    );
                  },
                  child: authState.isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Sign in'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Register',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
