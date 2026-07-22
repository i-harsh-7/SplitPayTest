import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../themes/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _loading = false;
  String? _error;

  late AnimationController _controller;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _formFadeAnimation;
  late Animation<Offset> _formSlideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _headerSlideAnimation = Tween<double>(begin: 0.0, end: -30.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.2, 0.7, curve: Curves.easeIn),
      ),
    );

    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    print("Login button pressed"); // Debug log
    
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      print("Attempting login with email: $email"); // Debug log
      
      await AuthService.login(email: email, password: password);
      
      print("Login successful"); // Debug log
      
      if (!mounted) return;
      
      // Pop the login screen first
      Navigator.of(context).pop();
      
      // Then call the callback to update parent state
      widget.onLoginSuccess();
      
    } catch (e) {
      print("Login error: $e"); // Debug log
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final textColor = Colors.black87;
    final size = MediaQuery.of(context).size;
    final horizontalPadding = (size.width * 0.08).clamp(20.0, 40.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Animated SVG Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _headerSlideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _headerSlideAnimation.value),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.55,
                      child: SvgPicture.asset(
                        'assets/images/file.svg',
                        fit: BoxFit.fill,
                        alignment: Alignment.topCenter,
                        placeholderBuilder: (context) => Container(
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Form Content
            Positioned.fill(
              child: SingleChildScrollView(
                physics: ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.42,
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: 32,
                ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _formFadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          _formSlideAnimation.value.dy * 100,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Sign in",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          SizedBox(width: 10),
                          Container(
                            width: 28,
                            height: 3,
                            color: primaryColor,
                          ),
                        ],
                      ),
                      SizedBox(height: 30),

                      // Email Field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(Icons.mail_outline, color: primaryColor),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 18),

                      // Password Field
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 10),

                      // Remember Me & Forgot Password
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v!),
                            activeColor: primaryColor,
                          ),
                          Text("Remember Me", style: TextStyle(color: textColor)),
                          Spacer(),
                          TextButton(
                            onPressed: () {
                              print("Forgot password pressed");
                            },
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          )
                        ],
                      ),
                      SizedBox(height: 18),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: primaryColor.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: _loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  "Login",
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),

                      // Error Message
                      if (_error != null) ...[
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                      SizedBox(height: 18),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an Account? ",
                            style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                          ),
                          GestureDetector(
                            onTap: () {
                              print("Sign up link pressed");
                              Navigator.of(context).pushNamed('/signup');
                            },
                            child: Text(
                              "Sign up",
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}