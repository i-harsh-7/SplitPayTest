import 'package:flutter/material.dart';
import 'themes/app_theme.dart';
import 'auth/login.dart';
import 'auth/sign_up.dart';
import 'auth/welcome_screen.dart'; // Add this import
import 'home_panel.dart';
import 'package:provider/provider.dart';
import 'services/group_service.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const SplitPayApp());
}

class SplitPayApp extends StatefulWidget {
  const SplitPayApp({Key? key}) : super(key: key);

  @override
  State<SplitPayApp> createState() => _SplitPayAppState();
}

class _SplitPayAppState extends State<SplitPayApp> {
  bool _isAuthenticated = false;
  bool _isLoading = true; // Add loading state
  ThemeMode _themeMode = ThemeMode.light;
  GroupService? _groupService;

  void _onLoginOrSignUp() {
    setState(() {
      _isAuthenticated = true;
      _isLoading = false;
    });
    // Fetch groups for the newly logged in user
    _groupService?.fetchGroups();
  }

  void _onLogout() async {
    // Clear auth token
    await AuthService.logout();
    
    // Clear groups from service
    _groupService?.clearGroups();
    
    setState(() {
      _isAuthenticated = false;
      _isLoading = false;
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  // Check for existing authentication on app start
  Future<void> _checkAuthStatus() async {
    try {
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        // Verify token is still valid by getting user profile
        final user = await AuthService.getProfile();
        if (user != null) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
          // Fetch groups for the authenticated user
          _groupService?.fetchGroups();
          return;
        }
      }
    } catch (_) {}
    
    setState(() {
      _isAuthenticated = false;
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final svc = GroupService();
        _groupService = svc;
        // Only fetch groups if authenticated
        if (_isAuthenticated) {
          svc.fetchGroups();
        }
        return svc;
      },
      child: MaterialApp(
        title: 'SplitPay',
        theme: AppThemes.lightTheme,
        darkTheme: AppThemes.darkTheme,
        themeMode: _themeMode,
        debugShowCheckedModeBanner: false,
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => LoginScreen(onLoginSuccess: _onLoginOrSignUp),
          '/signup': (context) => SignUpScreen(onSignUpSuccess: _onLoginOrSignUp),
          '/home': (context) => HomePanel(
                toggleTheme: _toggleTheme,
                themeMode: _themeMode,
                onLogout: _onLogout,
              ),
        },
        // Show loading screen while checking auth, then appropriate screen
        home: _isLoading
            ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : _isAuthenticated
                ? HomePanel(
                    toggleTheme: _toggleTheme,
                    themeMode: _themeMode,
                    onLogout: _onLogout,
                  )
                : const WelcomeScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/signup') {
            return PageRouteBuilder(
              pageBuilder: (ctx, anim1, anim2) =>
                  SignUpScreen(onSignUpSuccess: _onLoginOrSignUp),
              transitionsBuilder: (ctx, anim1, anim2, child) {
                final offsetAnim = Tween<Offset>(begin: Offset(1, 0), end: Offset(0, 0))
                    .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut));
                final fadeAnim = Tween<double>(begin: 0, end: 1).animate(anim1);
                return SlideTransition(
                    position: offsetAnim, child: FadeTransition(opacity: fadeAnim, child: child));
              },
              transitionDuration: Duration(milliseconds: 600),
            );
          }
          return null;
        },
      ),
    );
  }
}