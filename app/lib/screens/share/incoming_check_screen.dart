import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../models/risk_style.dart';
import '../../services/incoming_share_service.dart';
import '../../services/widget_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../utils/link_extractor.dart';
import '../browser/in_app_browser_screen.dart';

/// Large-type parent-friendly checking / result screen for shared content.
class IncomingCheckScreen extends StatefulWidget {
  const IncomingCheckScreen({
    super.key,
    required this.payload,
    this.onClose,
  });

  final IncomingPayload payload;

  /// When set (share cold-start), close returns to Home instead of popping a route.
  final VoidCallback? onClose;

  @override
  State<IncomingCheckScreen> createState() => _IncomingCheckScreenState();
}

class _IncomingCheckScreenState extends State<IncomingCheckScreen> {
  var _loading = true;
  String? _error;
  ScanResult? _scan;
  SmsAnalysisResult? _sms;
  String? _emptyClipboard;

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final payload = widget.payload;

    if (payload.kind == IncomingKind.pasteCheck) {
      if (payload.raw.isEmpty) {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text?.trim() ?? '';
        if (text.isEmpty) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _emptyClipboard =
                'Nothing to check yet. Copy a link from a chat, SMS, or email, then tap Paste & Check again.';
          });
          return;
        }
        final url = LinkExtractor.firstUrl(text);
        if (url != null && text.replaceAll(url, '').trim().length < 12) {
          await _scanUrl(url);
        } else {
          await _analyzeMessage(text);
        }
        return;
      }
    }

    if (payload.kind == IncomingKind.url && payload.url != null) {
      await _scanUrl(payload.url!);
      return;
    }

    await _analyzeMessage(payload.raw);
  }

  Future<void> _scanUrl(String url) async {
    setState(() {
      _loading = true;
      _error = null;
      _scan = null;
      _sms = null;
    });
    try {
      final result = await AppStore.instance.analyzeUrl(url);
      await WidgetSyncService.updateFromScan(result);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _scan = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _analyzeMessage(String text) async {
    setState(() {
      _loading = true;
      _error = null;
      _scan = null;
      _sms = null;
    });
    try {
      final result = await AppStore.instance.analyzeSms(text);
      await WidgetSyncService.updateFromSms(result);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sms = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String get _headline {
    if (_emptyClipboard != null) return 'Copy a link first';
    if (_loading) return 'Checking…';
    if (_error != null) return 'Could not check';
    if (_scan != null) {
      if (!_scan!.siteAvailable) return 'Site not available';
      return switch (_scan!.risk) {
        RiskLevel.safe => 'Looks safe',
        RiskLevel.caution => 'Be careful',
        RiskLevel.danger => 'Dangerous — do not open',
      };
    }
    if (_sms != null) {
      if (_sms!.isNepali) {
        return switch (_sms!.risk) {
          RiskLevel.safe => 'ठूलो खतरा देखिएन',
          RiskLevel.caution => 'सावधान — शंकास्पद',
          RiskLevel.danger => 'ठगी जस्तो — नखोल्नुहोस्',
        };
      }
      return switch (_sms!.risk) {
        RiskLevel.safe => 'Message looks okay',
        RiskLevel.caution => 'Be careful with this message',
        RiskLevel.danger => 'This looks like a scam',
      };
    }
    return 'SafeLink';
  }

  String get _body {
    if (_emptyClipboard != null) return _emptyClipboard!;
    if (_loading) {
      return 'SafeLink is checking this for scams. Please wait a moment.\n\nजाँच हुँदैछ… केही बेर पर्खनुहोस्।';
    }
    if (_error != null) return _error!;
    if (_scan != null) {
      final parts = <String>[];
      if (_scan!.analystSummary != null && _scan!.analystSummary!.isNotEmpty) {
        parts.add(_scan!.analystSummary!);
      } else if (_scan!.summary != null) {
        parts.add(_scan!.summary!);
      } else {
        parts.add(switch (_scan!.risk) {
          RiskLevel.safe => 'No major warning signs were found for this link.',
          RiskLevel.caution =>
            'Something about this link looks unusual. Ask someone you trust before opening it.',
          RiskLevel.danger =>
            'This link looks like a scam. Do not tap it or enter any passwords.',
        });
      }
      parts.add(_scan!.url);
      return parts.join('\n\n');
    }
    if (_sms != null) {
      final parts = <String>[];
      if (_sms!.summary != null && _sms!.summary!.isNotEmpty) {
        parts.add(_sms!.summary!);
      } else {
        parts.add(_sms!.verdictTitle);
      }
      final guide = _sms!.guideNe?.trim();
      if (guide != null && guide.isNotEmpty) {
        parts.add('के गर्ने?\n$guide');
      } else if (_sms!.recommendation.isNotEmpty) {
        parts.add(_sms!.recommendation);
      }
      if (_sms!.stepsNe.isNotEmpty) {
        parts.add(_sms!.stepsNe.map((s) => '• $s').join('\n'));
      }
      return parts.join('\n\n');
    }
    return '';
  }

  Color get _bannerColor {
    if (_loading || _emptyClipboard != null || _error != null) {
      return AppColors.accent;
    }
    final risk = _scan?.risk ?? _sms?.risk ?? RiskLevel.safe;
    return RiskStyle.color(risk);
  }

  Future<void> _openSafely() async {
    final result = _scan;
    if (result == null || !result.siteAvailable) return;
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Open anyway',
                style: GoogleFonts.googleSans(color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppBrowserScreen(
          url: result.url,
          risk: result.risk,
        ),
      ),
    );
  }

  Future<void> _scanExtracted(String url) => _scanUrl(url);

  @override
  Widget build(BuildContext context) {
    final risk = _scan?.risk ?? _sms?.risk;
    final showOpen = _scan != null &&
        _scan!.siteAvailable &&
        !_loading &&
        _error == null;

    return Scaffold(
      backgroundColor: AppColors.mist,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                  label: Text(
                    'Close',
                    style: GoogleFonts.googleSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: risk != null
                        ? RiskStyle.soft(risk)
                        : AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _loading
                            ? Icons.hourglass_top_rounded
                            : (risk != null
                                ? RiskStyle.icon(risk)
                                : AppIcons.shield),
                        size: 56,
                        color: _bannerColor,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _headline,
                        style: GoogleFonts.googleSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _bannerColor,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_loading)
                        const LinearProgressIndicator(color: AppColors.accent)
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _body,
                              style: GoogleFonts.googleSans(
                                fontSize: 18,
                                height: 1.4,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      if (_sms != null &&
                          _sms!.extractedUrls.isNotEmpty &&
                          _scan == null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Links found in this message',
                          style: GoogleFonts.googleSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._sms!.extractedUrls.map(
                          (url) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ElevatedButton(
                              onPressed: _loading
                                  ? null
                                  : () => _scanExtracted(url),
                              child: Text(
                                'Scan this link',
                                style: GoogleFonts.googleSans(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (showOpen) ...[
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _openSafely,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      textStyle: GoogleFonts.googleSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Open safely'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: _close,
                  style: OutlinedButton.styleFrom(
                    textStyle: GoogleFonts.googleSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    showOpen || _sms?.risk == RiskLevel.danger
                        ? 'Don’t open — go back'
                        : 'Done',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
