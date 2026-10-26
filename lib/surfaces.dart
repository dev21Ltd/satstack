import 'package:flutter/material.dart';

/// Panels for the look. A flat grey fill reads as an empty box, so cards
/// lighten toward the top and the main windows carry a little warmth.
BoxDecoration satCard(bool isDark, {bool hero = false}) {
  const radius = BorderRadius.all(Radius.circular(22));
  if (!isDark) {
    return BoxDecoration(
      borderRadius: radius,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFCF8), Color(0xFFF4F0EA)],
      ),
      border: Border.all(color: const Color(0x14000000)),
    );
  }
  if (hero) {
    return BoxDecoration(
      borderRadius: radius,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF322C26), Color(0xFF1E1B19), Color(0xFF121214)],
        stops: [0.0, 0.42, 1.0],
      ),
      border: Border.all(color: const Color(0x2EF7931A)),
    );
  }
  return BoxDecoration(
    borderRadius: radius,
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF29292F), Color(0xFF17171A)],
    ),
    border: Border.all(color: const Color(0x14FFFFFF)),
  );
}

Color satHairline(bool isDark) =>
    isDark ? const Color(0x14FFFFFF) : const Color(0x14000000);

Color satDialogFill(bool isDark) =>
    isDark ? const Color(0xFF241F1C) : const Color(0xFFF7F4EF);

ShapeBorder satDialogShape(bool isDark) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(
        color: isDark ? const Color(0x2EF7931A) : const Color(0x1A000000),
      ),
    );
