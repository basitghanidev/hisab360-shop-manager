import 'package:flutter/material.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';

class BilingualLabel extends StatelessWidget {
  final String english;
  final String urdu;
  final TextStyle? englishStyle;
  final Color? urduColor;
  
  const BilingualLabel({super.key, required this.english, required this.urdu, this.englishStyle, this.urduColor});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(english, style: englishStyle ?? AppTextStyles.body),
        Text(urdu, style: AppTextStyles.caption.copyWith(
          color: urduColor ?? AppColors.textSecondary,
        )),
      ],
    );
  }
}
