import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/lookups.dart';
import 'models/ticket.dart';

/// HelpDesk Pro colour palette. Status and priority colours live here so
/// the mobile app can match the web app if the frontend team changes them.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF5B3FE4);
  static const primaryDeep = Color(0xFF3F2BB8);
  static const bg = Color(0xFFF3F3FA);
  static const surface = Colors.white;
  static const field = Color(0xFFF6F6FC);
  static const ink = Color(0xFF16142B);
  static const inkSoft = Color(0xFF4A4766);
  static const muted = Color(0xFF8A88A3);
  static const line = Color(0xFFE7E6F2);

  static const success = Color(0xFF12B76A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF2E90FA);
  static const teal = Color(0xFF14B8A6);
  static const pink = Color(0xFFE5489E);
  static const orange = Color(0xFFF97316);
  static const violet = Color(0xFF8B5CF6);

  static const noteBg = Color(0xFFFFF8E6);
  static const noteBorder = Color(0xFFFCC74B);
  static const noteInk = Color(0xFF8A4B08);

  /// The brand gradient used for headers, the main button and highlights.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4338CA), Color(0xFF6D28D9), Color(0xFFA21CAF)],
    stops: [0, 0.6, 1],
  );

  static const avatarPalette = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFE5489E),
    Color(0xFF2E90FA),
    Color(0xFFF97316),
  ];
}

class AppShadows {
  AppShadows._();

  static final card = [
    BoxShadow(color: const Color(0xFF2B1F7A).withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10)),
      ];
}

/// Colour and icon for each ticket status.
typedef StatusStyle = ({Color color, IconData icon});

class AppTheme {
  AppTheme._();

  static StatusStyle status(TicketStatus status) => switch (status) {
        TicketStatus.open => (color: AppColors.info, icon: Icons.adjust_rounded),
        TicketStatus.inProgress => (color: AppColors.violet, icon: Icons.autorenew_rounded),
        TicketStatus.waitingForCustomer => (color: AppColors.warning, icon: Icons.hourglass_top_rounded),
        TicketStatus.resolved => (color: AppColors.success, icon: Icons.check_circle_rounded),
        TicketStatus.closed => (color: const Color(0xFF64748B), icon: Icons.lock_rounded),
      };

  static Color priority(PriorityLevel level) => switch (level) {
        PriorityLevel.low => AppColors.teal,
        PriorityLevel.medium => AppColors.info,
        PriorityLevel.high => AppColors.orange,
        PriorityLevel.urgent => AppColors.danger,
        PriorityLevel.unknown => AppColors.muted,
      };

  static IconData categoryIcon(String? name) => switch (name?.toLowerCase()) {
        'technical' => Icons.memory_rounded,
        'billing' => Icons.receipt_long_rounded,
        'account' => Icons.manage_accounts_rounded,
        'general' => Icons.forum_rounded,
        _ => Icons.label_rounded,
      };

  static Color categoryColor(String? name) => switch (name?.toLowerCase()) {
        'technical' => const Color(0xFF6366F1),
        'billing' => AppColors.teal,
        'account' => AppColors.pink,
        'general' => AppColors.orange,
        _ => AppColors.violet,
      };

  static ThemeData light() {
    const radius = BorderRadius.all(Radius.circular(16));
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.danger,
    );
    const font = 'Poppins';
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.2),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.25),
        titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.ink),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
        bodyLarge: TextStyle(fontSize: 15, color: AppColors.ink, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5),
        bodySmall: TextStyle(fontSize: 12.5, color: AppColors.muted),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppColors.line)),
        focusedBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppColors.primary, width: 1.6)),
        errorBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppColors.danger)),
        focusedErrorBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppColors.danger, width: 1.6)),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: AppColors.line, width: 1.4),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w600)),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.line),
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle: const TextStyle(fontFamily: font, fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkSoft),
        showCheckmark: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.line,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(fontFamily: font, color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.inkSoft),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
      ),
      datePickerTheme: const DatePickerThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    );
  }
}
