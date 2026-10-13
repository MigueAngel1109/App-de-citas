import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/almona_logo_data.dart';

class AlmonaTitle extends StatelessWidget {
  final double height;
  final Color? color;
  final double fontSize;

  const AlmonaTitle({
    super.key,
    this.height = 34,
    this.color,
    this.fontSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      AlmonaLogoData.bytes,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/almona_logo.png',
          height: height,
          fit: BoxFit.contain,
          color: color,
          errorBuilder: (_, __, ___) => Text(
            'Almona',
            style: TextStyle(
              fontFamily: 'Style Script',
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}
