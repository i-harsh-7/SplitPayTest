// lib/screens/about_us.dart
import 'package:flutter/material.dart';
import '../components/header.dart';

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> with TickerProviderStateMixin {
  late final AnimationController _iconController;
  late final Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _iconAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          const Header(title: 'About SplitPay'),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _iconAnimation,
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 120,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Yo, lemme break it down for ya — SplitPay ain't your usual money-splitter app. We got the juice to keep your cash drama free and your squad happy. No more nasty IOUs or awkward 'You owe me' convos. Just smooth, slick bill splitting with zero hassle. \n\nNo rocket science, just legit smart tech to track who paid, who owes, and who’s chill. SplitPay keeps your friendships solid and your wallet happy. So whether it’s dinner, drinks, or rent — SplitPay got you covered straight up!",
                    style: TextStyle(fontSize: 16, height: 1.5, color: textColor),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 50),

                  ScaleTransition(
                    scale: _iconAnimation,
                    child: Icon(
                      Icons.group,
                      size: 100,
                      color: primaryColor.withOpacity(0.8),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Our squad’s mission? To make splitting bills sooo easy, you don’t even gotta think about it. Just add your homies, throw in the bills, and SplitPay does the number crunching. You get the creds, they get the deets — everybody's happy, no drama, no stress.",
                    style: TextStyle(fontSize: 16, height: 1.5, color: textColor),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 50),

                  ScaleTransition(
                    scale: _iconAnimation,
                    child: Icon(
                      Icons.lock_clock,
                      size: 90,
                      color: primaryColor.withOpacity(0.7),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    "Time’s precious, fam — don’t waste it grinding through receipts. SplitPay handles all that geeky stuff so you can focus on the fun stuff. Trust the app, and keep your squad tight-knit and your bank account solid.",
                    style: TextStyle(fontSize: 16, height: 1.5, color: textColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
