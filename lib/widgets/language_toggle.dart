// lib/widgets/language_toggle.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

/// Always-visible segmented control — EN / አማ / OM — no hidden menu.
/// Reads/writes LanguageService via Provider.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = context.watch<LanguageService>();

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: LanguageService.supportedLanguages.map((lang) {
          final isActive = lang['code'] == languageService.languageCode;
          return GestureDetector(
            onTap: () => context.read<LanguageService>().setLanguage(lang['code']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isActive
                    ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 3)]
                    : null,
              ),
              child: Text(
                lang['short']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
