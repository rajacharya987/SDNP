import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/models.dart';
import '../../models/risk_style.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../browser/in_app_browser_screen.dart';

class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key, required this.result});

  final ScanResult result;

  String get _plainStatus {
    if (!result.siteAvailable) return 'This site is not available';
    return switch (result.risk) {
      RiskLevel.safe => 'Looks safe to open',
      RiskLevel.caution => 'Be careful with this link',
      RiskLevel.danger => 'Do not open — likely a scam',
    };
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: result.url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied')),
      );
    }
  }

  Future<void> _openInAppBrowser(BuildContext context) async {
    if (!result.siteAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.availabilityMessage ?? 'This site is not available',
          ),
        ),
      );
      return;
    }

    if (result.risk == RiskLevel.danger) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Dangerous link',
            style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This link looks like a scam. Opening it is not recommended.',
            style: GoogleFonts.googleSans(),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Go back',
                style: GoogleFonts.googleSans(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Open anyway',
                style: GoogleFonts.googleSans(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (go != true || !context.mounted) return;
    } else if (result.risk == RiskLevel.caution) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Open carefully?',
            style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This link looks suspicious or checks were incomplete. Continue only if you trust it.',
            style: GoogleFonts.googleSans(),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.googleSans(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Open in app',
                style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (go != true || !context.mounted) return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppBrowserScreen(
          url: result.url,
          risk: result.risk,
        ),
      ),
    );
  }

  Future<void> _report(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks — scam report submitted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final risk = result.risk;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final providers = result.providers;

    return Scaffold(
      backgroundColor: AppColors.mist,
      appBar: AppBar(
        title: Text(
          'Scan Result',
          style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Copy link',
            onPressed: () => _copy(context),
            icon: const Icon(AppIcons.copy),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 140 + bottom),
        children: [
          // Big clear verdict — one glance
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
            decoration: BoxDecoration(
              gradient: RiskStyle.gradient(risk),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: RiskStyle.color(risk).withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(RiskStyle.icon(risk), color: Colors.white, size: 64),
                const SizedBox(height: 14),
                Text(
                  risk.label.toUpperCase(),
                  style: GoogleFonts.googleSans(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _plainStatus,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.googleSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    height: 1.2,
                  ),
                ),
                if (result.riskScore != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Risk score ${result.riskScore}/100',
                    style: GoogleFonts.googleSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    result.url,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.googleSans(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Simple facts — no clutter
          _FactRow(
            icon: result.siteAvailable ? AppIcons.success : AppIcons.warning,
            color: result.siteAvailable ? AppColors.safe : AppColors.caution,
            title: result.siteAvailable
                ? 'Website is online'
                : 'Website is not available',
            subtitle: result.availabilityMessage,
          ),
          _FactRow(
            icon: result.sslValid ? AppIcons.lock : AppIcons.unlock,
            color: result.sslValid ? AppColors.safe : AppColors.danger,
            title: result.sslValid ? 'Secure HTTPS' : 'Not secure (HTTP)',
          ),
          _FactRow(
            icon: result.checksComplete ? AppIcons.verify : AppIcons.info,
            color: result.checksComplete ? AppColors.safe : AppColors.caution,
            title: result.checksComplete
                ? 'Security checks finished'
                : 'Some checks incomplete',
          ),

          if (result.analystSummary != null &&
              result.analystSummary!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Scan summary',
              style: GoogleFonts.googleSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.analystSummary!,
              style: GoogleFonts.googleSans(
                fontSize: 14,
                height: 1.4,
                color: AppColors.ink,
              ),
            ),
          ],

          if (result.threatDetails.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Why this result',
              style: GoogleFonts.googleSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            for (final detail in result.threatDetails.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppIcons.warning,
                      size: 18,
                      color: RiskStyle.color(risk),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail,
                        style: GoogleFonts.googleSans(
                          fontSize: 13,
                          color: AppColors.ink,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          if (providers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: false,
                title: Text(
                  'See full check details',
                  style: GoogleFonts.googleSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.slate,
                  ),
                ),
                children: [
                  for (final check in providers)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        check.isClean
                            ? AppIcons.success
                            : check.isFlagged
                                ? AppIcons.danger
                                : AppIcons.warning,
                        color: check.isClean
                            ? AppColors.safe
                            : check.isFlagged
                                ? AppColors.danger
                                : AppColors.caution,
                        size: 20,
                      ),
                      title: Text(
                        check.name,
                        style: GoogleFonts.googleSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        check.message?.isNotEmpty == true
                            ? '${check.statusLabel}: ${check.message}'
                            : check.statusLabel,
                        style: GoogleFonts.googleSans(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Material(
        elevation: 12,
        color: AppColors.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: risk == RiskLevel.danger
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 360;
                      final reportBtn = OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(
                            stacked ? double.infinity : 0,
                            52,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: AppColors.danger),
                          foregroundColor: AppColors.danger,
                        ),
                        onPressed: () => _report(context),
                        child: Text(
                          'Report scam',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.googleSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      );
                      final openBtn = ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          minimumSize: Size(
                            stacked ? double.infinity : 0,
                            52,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _openInAppBrowser(context),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize:
                              stacked ? MainAxisSize.max : MainAxisSize.min,
                          children: [
                            const Icon(AppIcons.openBrowser, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Open anyway',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.googleSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (stacked) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            openBtn,
                            const SizedBox(height: 10),
                            reportBtn,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: reportBtn),
                          const SizedBox(width: 10),
                          Expanded(flex: 1, child: openBtn),
                        ],
                      );
                    },
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: result.siteAvailable
                          ? AppColors.ink
                          : AppColors.slate,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _openInAppBrowser(context),
                    icon: Icon(
                      result.siteAvailable
                          ? AppIcons.openBrowser
                          : AppIcons.warning,
                      size: 20,
                    ),
                    label: Text(
                      result.siteAvailable
                          ? 'Open in Safe Browser'
                          : 'Site not available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.googleSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.googleSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: GoogleFonts.googleSans(
                      fontSize: 12,
                      color: AppColors.slate,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
