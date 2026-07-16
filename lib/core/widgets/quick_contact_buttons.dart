import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sentery_app/core/constants/app_colors.dart';

class QuickContactButtons extends StatelessWidget {
  final String? phone;
  const QuickContactButtons({super.key, this.phone});

  @override
  Widget build(BuildContext context) {
    if (phone == null || phone!.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        _button(Icons.phone_outlined, 'Call', () => _launch('tel:$phone')),
        const SizedBox(width: 8),
        _button(Icons.message_outlined, 'Message', () => _launch('https://wa.me/92${phone!.replaceAll(RegExp(r'[^0-9]'), '').substring(1)}')),
      ],
    );
  }

  Widget _button(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }
}
