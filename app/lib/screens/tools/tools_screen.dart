import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../widgets/app_header.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import 'breach_screen.dart';
import 'message_analyzer_screen.dart';
import 'qr_scanner_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      (
        title: 'QR Scanner',
        subtitle: 'Scan QR codes instantly before you open them',
        icon: AppIcons.qr,
        tint: const Color(0xFF3B82F6),
        soft: const Color(0xFFE8F1FF),
        page: const QrScannerScreen(),
      ),
      (
        title: 'Breach Checker',
        subtitle: 'Check if your email or phone was leaked',
        icon: AppIcons.lock,
        tint: const Color(0xFF8B5CF6),
        soft: const Color(0xFFF3E8FF),
        page: const BreachScreen(),
      ),
      (
        title: 'SMS Analyzer',
        subtitle: 'Flag scam wording in suspicious messages',
        icon: AppIcons.message,
        tint: const Color(0xFFF97316),
        soft: const Color(0xFFFFF0E6),
        page: const MessageAnalyzerScreen(),
      ),
    ];

    return AppPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                onProfileTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                onNotificationTap: () => openNotifications(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                  children: [
                    Text(
                      'Tools',
                      style: GoogleFonts.googleSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Extra protection utilities for everyday checks.',
                      style: GoogleFonts.googleSans(
                        fontSize: 13,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: AppColors.brand,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentDeep.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              AppIcons.shield,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stay one step ahead',
                                  style: GoogleFonts.googleSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Use these tools before you tap, share, or sign up.',
                                  style: GoogleFonts.googleSans(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...tools.map(
                      (tool) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.accentSoft.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => tool.page),
                            ),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: tool.soft,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      tool.icon,
                                      color: tool.tint,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tool.title,
                                          style: GoogleFonts.googleSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          tool.subtitle,
                                          style: GoogleFonts.googleSans(
                                            color: AppColors.slate,
                                            fontSize: 12,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    AppIcons.chevronRight,
                                    size: 16,
                                    color:
                                        AppColors.ink.withValues(alpha: 0.45),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
