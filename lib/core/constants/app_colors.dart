import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF1A56DB);      // Blue (trust)
  static const Color primaryDark = Color(0xFF1143C0);
  static const Color accent = Color(0xFF0EA5E9);        // Light blue
  
  // Status Colors
  static const Color success = Color(0xFF16A34A);       // Green — paid, in stock
  static const Color warning = Color(0xFFD97706);       // Orange — near limit, low stock
  static const Color danger = Color(0xFFDC2626);        // Red — overdue, out of stock
  static const Color info = Color(0xFF0284C7);          // Blue info
  
  // Financial Colors
  static const Color weOwe = Color(0xFFDC2626);         // Red — we owe supplier
  static const Color theyOwe = Color(0xFF16A34A);       // Green — they owe us
  
  // Neutral
  static const Color background = Color(0xFFF9FAFB);    // iOS light bg
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  
  // Dark Mode
  static const Color backgroundDark = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color borderDark = Color(0xFF374151);
}
