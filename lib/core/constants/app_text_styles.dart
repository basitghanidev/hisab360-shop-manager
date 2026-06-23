import 'dart:ui';
import 'package:flutter/material.dart';

class AppTextStyles {
  // Large title (screen headers)
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5,
  );
  
  // Navigation title
  static const TextStyle navTitle = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600,
  );
  
  // Card title
  static const TextStyle cardTitle = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600,
  );
  
  // Body text
  static const TextStyle body = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w400,
  );
  
  // Subheadline
  static const TextStyle subheadline = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
  );
  
  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
  );
  
  // Currency display (large, bold)
  static const TextStyle currencyLarge = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
