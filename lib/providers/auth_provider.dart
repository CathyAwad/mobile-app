import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/api/api_client.dart';
import '../features/auth/domain/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final bool isInitializing;
  final User? user;
  final String? error;

  AuthState({
    this.isLoading = false, 
    this.isInitializing = true, 
    this.user, 
    this.error,
  });

  AuthState copyWith({
    bool? isLoading, 
    bool? isInitializing,
    User? user, 
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      user: user ?? this.user,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  Dio get _dio => ref.read(dioProvider);

  @override
  AuthState build() {
    print('AuthNotifier: build called');
    checkAuthStatus();
    return AuthState();
  }

  Future<void> checkAuthStatus() async {
    print('AuthNotifier: checkAuthStatus started');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print('AuthNotifier: token from prefs = $token');

      if (token != null && token.isNotEmpty) {
        print('AuthNotifier: fetching /auth/me');
        final response = await _dio.get('/auth/me');
        print('AuthNotifier: /auth/me response = ${response.statusCode}');
        final user = User.fromJson(response.data);
        state = state.copyWith(isInitializing: false, user: user);
        print('AuthNotifier: isInitializing set to false (user loaded)');
      } else {
        print('AuthNotifier: no token, isInitializing set to false');
        state = state.copyWith(isInitializing: false);
      }
    } on DioException catch (e) {
      print('AuthNotifier: checkAuthStatus DioException = ${e.message}');
      if (e.response?.statusCode == 401) {
        // Session expired, clear token and just stop initializing
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        state = state.copyWith(isInitializing: false, user: null, error: null);
      } else {
        state = state.copyWith(isInitializing: false, error: e.message);
      }
    } catch (e) {
      print('AuthNotifier: checkAuthStatus unknown error = $e');
      state = state.copyWith(isInitializing: false, error: e.toString());
    }
  }

  Future<void> login(String identifier, String password) async {
    print('AuthNotifier: login called for $identifier');
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('AuthNotifier: making POST request to /auth/login...');
      final response = await _dio.post('/auth/login', data: {
        'identifier': identifier,
        'password': password,
      });

      print('AuthNotifier: login success, response code = ${response.statusCode}');
      
      final user = User.fromJson(response.data['user']);
      final token = response.data['token'];
      print('AuthNotifier: parsed user ${user.username} and token');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      state = state.copyWith(isLoading: false, user: user);
      print('AuthNotifier: login complete');
    } on DioException catch (e) {
      print('AuthNotifier: DioException on login = ${e.message}');
      print('AuthNotifier: DioException response = ${e.response?.data}');
      state = state.copyWith(
        isLoading: false, 
        error: e.response?.data['message'] ?? 'Login failed (${e.message})',
      );
    } catch (e) {
      print('AuthNotifier: unknown error on login = $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register(String username, String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post('/auth/register', data: {
        'username': username,
        'name': name,
        'email': email,
        'password': password,
      });

      final user = User.fromJson(response.data['user']);
      final token = response.data['token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      state = state.copyWith(isLoading: false, user: user);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false, 
        error: e.response?.data['message'] ?? 'Registration failed',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _dio.post('/auth/logout');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      state = AuthState();
    } catch (e) {
      // Force logout locally even if server call fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      state = AuthState();
    }
  }
}
