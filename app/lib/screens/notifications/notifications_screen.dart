import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../models/risk_style.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../widgets/app_header.dart';
import '../scan/scan_result_screen.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.risk,
    this.record,
    this.isTip = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime time;
  final RiskLevel risk;
  final ScanRecord? record;
  final bool isTip;
}

/// Safety alerts from recent scans + simple tips for parents.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _store = AppStore.instance;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _store.refreshHistory();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<AppNotification> get _alerts {
    final alerts = <AppNotification>[];
    for (final record in _store.history) {
      if (record.risk == RiskLevel.safe) continue;
      final isDanger = record.risk == RiskLevel.danger;
      alerts.add(
        AppNotification(
          id: 'scan-${record.id}',
          title: isDanger ? 'Dangerous link found' : 'Be careful with this link',
          body: record.detail?.isNotEmpty == true
              ? '${record.detail}\n${record.url}'
              : record.url,
          time: record.scannedAt,
          risk: record.risk,
          record: record.kind == HistoryKind.link ? record : null,
        ),
      );
    }
    alerts.sort((a, b) => b.time.compareTo(a.time));
    return alerts.take(30).toList();
  }

  List<AppNotification> get _tips => [
        AppNotification(
          id: 'tip-share',
          title: 'Share links to SafeLink',
          body:
              'In WhatsApp, Messages, or email, tap Share → SafeLink to check a link before opening it.',
          time: DateTime.now(),
          risk: RiskLevel.safe,
          isTip: true,
        ),
        AppNotification(
          id: 'tip-widget',
          title: 'Add the home widget',
          body:
              'Long-press your home screen → Widgets → SafeLink → Paste & Check for quick scans.',
          time: DateTime.now().subtract(const Duration(minutes: 1)),
          risk: RiskLevel.safe,
          isTip: true,
        ),
        AppNotification(
          id: 'tip-qr',
          title: 'Scan QR codes first',
          body:
              'Use QR Scanner in SafeLink before opening any code from posters or messages.',
          time: DateTime.now().subtract(const Duration(minutes: 2)),
          risk: RiskLevel.safe,
          isTip: true,
        ),
      ];

  String _timeLabel(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  Future<void> _openRecord(ScanRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          result: ScanResult(
            url: record.url,
            risk: record.risk,
            safeBrowsingOk: record.risk == RiskLevel.safe,
            domainAgeDays: null,
            sslValid: record.url.toLowerCase().startsWith('https://'),
            redirects: [record.url],
            summary: record.detail,
            checksComplete: record.risk == RiskLevel.safe,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        text,
        style: GoogleFonts.googleSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }

  Widget _card(AppNotification item) {
    final color =
        item.isTip ? AppColors.accent : RiskStyle.color(item.risk);
    final soft = item.isTip ? AppColors.accentSoft : RiskStyle.soft(item.risk);
    final icon = item.isTip ? AppIcons.info : RiskStyle.icon(item.risk);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: item.record == null ? null : () => _openRecord(item.record!),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.googleSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (!item.isTip)
                            Text(
                              _timeLabel(item.time),
                              style: GoogleFonts.googleSans(
                                fontSize: 11,
                                color: AppColors.slate,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: GoogleFonts.googleSans(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.slate,
                        ),
                      ),
                      if (item.record != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tap to view scan result',
                          style: GoogleFonts.googleSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentDeep,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _alerts;
    final tips = _tips;

    return AppPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Notifications',
            style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : RefreshIndicator(
                color: AppColors.accent,
                onRefresh: () async {
                  setState(() => _loading = true);
                  await _load();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.brand,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              AppIcons.notification,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alerts.isEmpty
                                      ? 'All clear'
                                      : '${alerts.length} safety alert${alerts.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.googleSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  alerts.isEmpty
                                      ? 'No scam warnings from your recent checks.'
                                      : 'From your recent SafeLink scans.',
                                  style: GoogleFonts.googleSans(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (alerts.isNotEmpty) ...[
                      _sectionTitle('Alerts'),
                      ...alerts.map(_card),
                      const SizedBox(height: 8),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.safeSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              AppIcons.shield,
                              color: AppColors.safe,
                              size: 36,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No alerts yet',
                              style: GoogleFonts.googleSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.safe,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'When SafeLink finds a risky link or message, it will show up here.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.googleSans(
                                fontSize: 13,
                                color: AppColors.slate,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _sectionTitle('Safety tips'),
                    ...tips.map(_card),
                  ],
                ),
              ),
      ),
    );
  }
}

void openNotifications(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
  );
}
