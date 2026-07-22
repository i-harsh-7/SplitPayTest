import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? child;
  final double heightFactor;

  const Header({
    Key? key,
    required this.title,
    this.actions,
    this.child,
    this.heightFactor = 0.12, // Default 12% of screen height
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * heightFactor;

    return Container(
      height: headerHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color.lerp(primary, Colors.black, 0.18)!],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Centered Title
            Positioned.fill(
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Optional actions aligned to top-right
            if (actions != null)
              Positioned(
                top: 12,
                right: 24,
                child: Row(children: actions!),
              ),

            // Optional child content inside header
            if (child != null)
              Positioned.fill(
                child: child!,
              ),
          ],
        ),
      ),
    );
  }
}