import 'package:flutter/material.dart';

class WaveHeader extends StatelessWidget {
  final double height;
  final Color gradientStart;
  final Color gradientEnd;

  const WaveHeader({
    Key? key,
    this.height = 230,
    this.gradientStart = const Color(0xFF65A7E7),
    this.gradientEnd = const Color(0xFFB3D8F6),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(gradientStart, gradientEnd),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color gradientStart;
  final Color gradientEnd;

  _WavePainter(this.gradientStart, this.gradientEnd);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Gradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [gradientStart, gradientEnd],
    );

    final Paint paint = Paint()
      ..shader = gradient.createShader(rect);

    final Path path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 60);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
