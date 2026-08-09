import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'models.dart';

abstract final class RiskStyle {
  static Color color(RiskLevel risk) => switch (risk) {
        RiskLevel.safe => AppColors.safe,
        RiskLevel.caution => AppColors.caution,
        RiskLevel.danger => AppColors.danger,
      };

  static Color soft(RiskLevel risk) => switch (risk) {
        RiskLevel.safe => AppColors.safeSoft,
        RiskLevel.caution => AppColors.cautionSoft,
        RiskLevel.danger => AppColors.dangerSoft,
      };

  static IconData icon(RiskLevel risk) => switch (risk) {
        RiskLevel.safe => AppIcons.shield,
        RiskLevel.caution => AppIcons.warning,
        RiskLevel.danger => AppIcons.danger,
      };

  static LinearGradient gradient(RiskLevel risk) => switch (risk) {
        RiskLevel.safe => const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          ),
        RiskLevel.caution => const LinearGradient(
            colors: [Color(0xFFF57F17), Color(0xFFFBC02D)],
          ),
        RiskLevel.danger => const LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
          ),
      };
}

class RiskChip extends StatelessWidget {
  const RiskChip({super.key, required this.risk});

  final RiskLevel risk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: RiskStyle.soft(risk),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        risk.label,
        style: GoogleFonts.googleSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: RiskStyle.color(risk),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.googleSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
