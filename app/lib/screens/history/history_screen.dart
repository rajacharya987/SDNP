import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../models/risk_style.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../widgets/app_header.dart';
import '../notifications/notifications_screen.dart';
import '../scan/scan_result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _store = AppStore.instance;
  var _tab = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear history?',
          style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This clears scan logs shown on this device. Server logs are unchanged.',
          style: GoogleFonts.googleSans(color: AppColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) setState(_store.clearHistory);
  }

  Future<void> _refresh() async {
    try {
      await _store.refreshHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
    if (mounted) setState(() {});
  }

  List<ScanRecord> get _items =>
      _tab == 0 ? _store.linkLogs : _store.otherLogs;

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return AppPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                onNotificationTap: () => openNotifications(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'History',
                        style: GoogleFonts.googleSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (_store.history.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear history',
                        onPressed: _clearAll,
                        icon: const Icon(AppIcons.trash, size: 20),
                        color: AppColors.slate,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: _HistoryTabs(
                  index: _tab,
                  linkCount: _store.linkLogs.length,
                  otherCount: _store.otherLogs.length,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _refresh,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.35,
                              child: _EmptyHistory(isLinks: _tab == 0),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return _HistoryTile(
                              record: item,
                              onOpen: _tab == 0
                                  ? () => _openResult(item)
                                  : null,
                              onDeleted: () {
                                _store.remove(item.id);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Removed from history'),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () {
                                        // Simple undo: re-insert at top
                                        _store.history.insert(0, item);
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openResult(ScanRecord item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          result: ScanResult(
            url: item.url,
            risk: item.risk,
            safeBrowsingOk: item.risk == RiskLevel.safe,
            domainAgeDays: null,
            sslValid: item.url.toLowerCase().startsWith('https://'),
            redirects: [item.url],
            summary: item.detail,
            checksComplete: item.risk == RiskLevel.safe,
          ),
        ),
      ),
    );
  }
}

class _HistoryTabs extends StatelessWidget {
  const _HistoryTabs({
    required this.index,
    required this.linkCount,
    required this.otherCount,
    required this.onChanged,
  });

  final int index;
  final int linkCount;
  final int otherCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Links',
              count: linkCount,
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _TabChip(
              label: 'Breach / Text',
              count: otherCount,
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.googleSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? AppColors.white : AppColors.slate,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.white.withValues(alpha: 0.18)
                    : AppColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.googleSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.white : AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.isLinks});

  final bool isLinks;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            isLinks ? AppIcons.link : AppIcons.security,
            color: AppColors.accent,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isLinks ? 'No link scans yet' : 'No breach or text checks yet',
          style: GoogleFonts.googleSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isLinks
              ? 'Scan a link from Home to see it here.'
              : 'Run a breach or SMS check to build this log.',
          textAlign: TextAlign.center,
          style: GoogleFonts.googleSans(
            fontSize: 13,
            color: AppColors.slate,
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.record,
    required this.onDeleted,
    this.onOpen,
  });

  final ScanRecord record;
  final VoidCallback onDeleted;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final host = _hostLabel(record.url);
    final kindLabel = switch (record.kind) {
      HistoryKind.link => 'Link',
      HistoryKind.breach => 'Breach',
      HistoryKind.text => 'Text',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Dismissible(
        key: ValueKey(record.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(AppIcons.trash, color: AppColors.danger),
        ),
        onDismissed: (_) => onDeleted(),
        child: Material(
          color: AppColors.accentSoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      RiskStyle.icon(record.risk),
                      size: 18,
                      color: RiskStyle.color(record.risk),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.googleSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record.detail ?? record.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.googleSans(
                            fontSize: 12,
                            color: AppColors.slate,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$kindLabel · ${_format(record.scannedAt)}',
                          style: GoogleFonts.googleSans(
                            fontSize: 11,
                            color: AppColors.slate.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RiskChip(risk: record.risk),
                      if (onOpen != null) ...[
                        const SizedBox(height: 6),
                        Icon(
                          AppIcons.chevronRight,
                          size: 14,
                          color: AppColors.ink.withValues(alpha: 0.4),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _hostLabel(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    final cleaned = url.replaceFirst(RegExp(r'^https?://'), '');
    final first = cleaned.split('/').first;
    return first.isEmpty ? url : first;
  }

  String _format(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
