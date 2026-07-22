import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../themes/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _svgSlideAnimation;
  late Animation<Offset> _welcomeSlideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // SVG slides from top
    _svgSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // Split/pay text fades in
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 0.8, curve: Curves.easeIn),
      ),
    );

    // Welcome section slides from left
    _welcomeSlideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.5, 1.0, curve: Curves.easeOut),
    ));

    // General fade for button
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Light-only visuals

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Column(
            children: [
              // Top Blue Header Section with Pattern
              Expanded(
                flex: 6,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Pattern with blue background - animated from top
                    Transform.translate(
                      offset: Offset(
                        0,
                        _svgSlideAnimation.value.dy * MediaQuery.of(context).size.height * 0.6,
                      ),
                      child: SizedBox.expand(
                        child: SvgPicture.asset(
                          'assets/images/file.svg',
                          fit: BoxFit.cover,
                          placeholderBuilder: (context) => Container(
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ),
                    
                    // Content on top of pattern
                    SafeArea(
                      child: Center(
                        child: Opacity(
                          opacity: _textFadeAnimation.value,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Wallet Icon
                              SvgPicture.asset(
                                'assets/images/wallet_icon.svg',
                                width: 100,
                                height: 100,
                              ),
                              
                              const SizedBox(height: 30),
                              
                              // App Name
                              Text(
                                'Split',
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'pay',
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom White Section
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Transform.translate(
                    offset: Offset(
                      _welcomeSlideAnimation.value.dx * MediaQuery.of(context).size.width,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        
                        // Welcome Text
                        Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Description
                        Text(
                          'Split expenses easily with friends and keep track of who owes what.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black45,
                            height: 1.5,
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Continue Button
                        Opacity(
                          opacity: _fadeAnimation.value,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FloatingActionButton.extended(
                              onPressed: () {
                                Navigator.pushNamed(context, '/login');
                              },
                              backgroundColor: AppColors.primaryLight,
                              elevation: 2,
                              icon: Icon(Icons.arrow_forward, color: Colors.white),
                              label: Text(
                                'Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}