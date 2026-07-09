import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/router/app_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';

class SenteryApp extends ConsumerWidget {
  const SenteryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.primary),
        ),
      ),
      builder: (context, child) {
        return _ResponsiveWrapper(child: child!);
      },
    );
  }
}

class _ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  const _ResponsiveWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Container(
            color: Colors.grey[100],
            alignment: Alignment.center,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: child,
            ),
          );
        }
        return child;
      },
    );
  }
}
