import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../themes/app_theme.dart';

class SignUpScreen extends StatefulWidget {
  final VoidCallback onSignUpSuccess;

  const SignUpScreen({Key? key, required this.onSignUpSuccess}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  // Must match the backend's validation (AuthDtos): a valid email address, and a password of at
  // least 8 characters with at least one letter and one digit.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _passwordPolicy = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  late AnimationController _controller;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _formFadeAnimation;
  late Animation<Offset> _formSlideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Header slides up slightly
    _headerSlideAnimation = Tween<double>(begin: 0.0, end: -30.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Form fades in
    _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 0.9, curve: Curves.easeIn),
      ),
    );

    // Form slides up
    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _signUp() {
    _performSignUp();
  }

  Future<void> _performSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match')));
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(child: CircularProgressIndicator()));

    try {
      await AuthService.signUp(name: name, email: email, phone: phone, password: password);
      
      if (!mounted) return;
      
      Navigator.of(context).pop(); // close progress dialog
      Navigator.of(context).pop(); // close signup screen
      
      // Then call callback to update parent state
      widget.onSignUpSuccess();
      
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final textColor = Colors.black87;
    final size = MediaQuery.of(context).size;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final horizontalPadding = (size.width * 0.08).clamp(16.0, 28.0);
    final gapSmall = (size.height * 0.018).clamp(10.0, 20.0);
    final gapMedium = (size.height * 0.03).clamp(16.0, 30.0);
    final buttonHeight = (size.height * 0.06).clamp(44.0, 56.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Animated SVG Header
          AnimatedBuilder(
            animation: _headerSlideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _headerSlideAnimation.value),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.40,
                  width: double.infinity,
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

          // Form Content - Use SlideTransition and FadeTransition
          SlideTransition(
            position: _formSlideAnimation,
            child: FadeTransition(
              opacity: _formFadeAnimation,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.32,
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: 40,
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Sign up",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(width: gapSmall),
                        Container(
                          width: (size.width * 0.08).clamp(24.0, 36.0),
                          height: (size.height * 0.004).clamp(2.0, 4.0),
                          color: primaryColor,
                        ),
                      ],
                    ),
                    SizedBox(height: gapMedium),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Name",
                        prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: gapSmall),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.mail_outline, color: primaryColor),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!_emailPattern.hasMatch(v)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: gapSmall),

                    // Phone Field
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Phone no",
                        prefixIcon: Icon(Icons.phone_outlined, color: primaryColor),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: gapSmall),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                        border: OutlineInputBorder(),
                        helperText: 'At least 8 characters, with a letter and a number',
                        helperMaxLines: 2,
                      ),
                      validator: (value) {
                        final v = value ?? '';
                        if (v.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (!_passwordPolicy.hasMatch(v)) {
                          return 'Password must be at least 8 characters and include a letter and a number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: gapSmall),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      style: TextStyle(color: textColor),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: "Confirm Password",
                        prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: gapMedium),

                    // Create Account Button
                    SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: (size.width * 0.042).clamp(14.0, 18.0) * textScale,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: gapSmall),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an Account? ",
                          style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            "Login",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gapMedium),
                  ],
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}