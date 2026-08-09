import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../models/risk_style.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../widgets/app_header.dart';
import '../notifications/notifications_screen.dart';
import '../scan/scan_result_screen.dart';
import '../settings/settings_screen.dart';
import '../tools/breach_screen.dart';
import '../tools/message_analyzer_screen.dart';
import '../tools/qr_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _linkController = TextEditingController();
  final _store = AppStore.instance;
  var _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      await _store.refreshHistory();
      if (mounted) setState(() {});
    } catch (_) {
      // Keep any local history if the API is unreachable.
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() => _linkController.text = text);
    }
  }

  Future<void> _scan() async {
    final url = _linkController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a link to scan')),
      );
      return;
    }
    if (_scanning) return;

    setState(() => _scanning = true);
    try {
      final result = await _store.analyzeUrl(url);
      if (!mounted) return;
      setState(() {});
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ScanResultScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _refresh() async {
    try {
      await _store.refreshHistory();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final recent = _store.recentLinks;

    return AppPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: AppHeader(
                    onProfileTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    onNotificationTap: () => openNotifications(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'Home',
                        style: GoogleFonts.googleSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _ShareTipCard(),
                      const SizedBox(height: 18),
                      _ScanBox(
                        controller: _linkController,
                        onPaste: _pasteFromClipboard,
                        onScan: _scan,
                        scanning: _scanning,
                      ),
                      const SizedBox(height: 12),
                      const SectionHeader(title: 'Quick tools'),
                      const SizedBox(height: 8),
                      _FeatureGrid(
                        onOpen: (tool) {
                          final page = switch (tool) {
                            _QuickTool.qr => const QrScannerScreen(),
                            _QuickTool.breach => const BreachScreen(),
                            _QuickTool.message => const MessageAnalyzerScreen(),
                          };
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => page),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      SectionHeader(
                        title: 'Recent scans',
                        actionLabel: recent.isEmpty ? null : 'See all',
                        onAction: recent.isEmpty
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Open History from the bottom bar',
                                    ),
                                  ),
                                );
                              },
                      ),
                      if (recent.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'No scans yet. Paste a link above to get started.',
                            style: GoogleFonts.googleSans(
                              color: AppColors.slate,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ...recent.take(5).map(
                          (item) => _RecentScanTile(
                            record: item,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ScanResultScreen(
                                    result: ScanResult(
                                      url: item.url,
                                      risk: item.risk,
                                      safeBrowsingOk:
                                          item.risk == RiskLevel.safe,
                                      domainAgeDays: null,
                                      sslValid:
                                          item.url.toLowerCase().startsWith(
                                                'https://',
                                              ),
                                      redirects: [item.url],
                                      summary: item.detail,
                                      checksComplete:
                                          item.risk == RiskLevel.safe,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareTipCard extends StatelessWidget {
  const _ShareTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.ios_share_rounded, color: AppColors.accentDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Got a link in a chat, SMS, or email?\nTap Share → SafeLink. We’ll check it for you.',
              style: GoogleFonts.googleSans(
                fontSize: 14,
                height: 1.35,
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanBox extends StatefulWidget {
  const _ScanBox({
    required this.controller,
    required this.onPaste,
    required this.onScan,
    required this.scanning,
  });

  final TextEditingController controller;
  final VoidCallback onPaste;
  final VoidCallback onScan;
  final bool scanning;

  @override
  State<_ScanBox> createState() => _ScanBoxState();
}

class _ScanBoxState extends State<_ScanBox> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _ScanBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDeep.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick link scan',
            style: GoogleFonts.googleSans(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.url,
                  style: GoogleFonts.googleSans(
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste a suspicious link…',
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    prefixIcon: const Icon(
                      AppIcons.link,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    suffixIcon: hasText
                        ? IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              widget.controller.clear();
                            },
                            icon: Icon(
                              AppIcons.danger,
                              size: 18,
                              color: AppColors.slate.withValues(alpha: 0.55),
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.4,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.75),
                        width: 1.4,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: widget.onPaste,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(
                      AppIcons.paste,
                      color: AppColors.ink,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: widget.scanning ? null : widget.onScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.55),
                elevation: 0,
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.googleSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: widget.scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(AppIcons.scanShield, size: 20),
              label: Text(widget.scanning ? 'Scanning…' : 'Scan Link'),
            ),
          ),
        ],
      ),
    );
  }
}


enum _QuickTool { qr, breach, message }

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.onOpen});

  final ValueChanged<_QuickTool> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        tool: _QuickTool.qr,
        icon: AppIcons.qr,
        label: 'QR Scanner',
        subtitle: 'Scan QR codes instantly',
        tint: const Color(0xFF3B82F6),
        soft: const Color(0xFFE8F1FF),
      ),
      (
        tool: _QuickTool.breach,
        icon: AppIcons.lock,
        label: 'Breach Checker',
        subtitle: 'Check if your data has been leaked',
        tint: const Color(0xFF8B5CF6),
        soft: const Color(0xFFF3E8FF),
      ),
      (
        tool: _QuickTool.message,
        icon: AppIcons.message,
        label: 'SMS Analyzer',
        subtitle: 'Analyze suspicious messages',
        tint: const Color(0xFFF97316),
        soft: const Color(0xFFFFF0E6),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        for (final item in items)
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onOpen(item.tool),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.soft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon, color: item.tint, size: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.googleSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.ink,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.googleSans(
                              fontWeight: FontWeight.w400,
                              fontSize: 10.5,
                              height: 1.2,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight,
                      size: 14,
                      color: AppColors.ink.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}


class _RecentScanTile extends StatelessWidget {
  const _RecentScanTile({required this.record, required this.onTap});

  final ScanRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final host = _hostLabel(record.url);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: AppColors.accentSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                        record.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.googleSans(
                          fontSize: 12,
                          color: AppColors.slate,
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
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(record.scannedAt),
                      style: GoogleFonts.googleSans(
                        fontSize: 11,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ],
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
    return cleaned.split('/').first;
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
