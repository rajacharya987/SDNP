import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../models/risk_style.dart';
import '../../theme/app_colors.dart';
import '../scan/scan_result_screen.dart';

class MessageAnalyzerScreen extends StatefulWidget {
  const MessageAnalyzerScreen({
    super.key,
    this.initialText,
  });

  final String? initialText;

  @override
  State<MessageAnalyzerScreen> createState() => _MessageAnalyzerScreenState();
}

class _MessageAnalyzerScreenState extends State<MessageAnalyzerScreen> {
  late final TextEditingController _controller;
  var _loading = false;
  List<FlaggedKeyword>? _flags;
  RiskLevel? _risk;
  String? _title;
  String? _recommendation;
  String? _summary;
  List<String> _extractedUrls = const [];
  var _isNepali = false;
  String? _guideNe;
  List<String> _stepsNe = const [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    if ((widget.initialText ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _flags = null;
      _risk = null;
      _title = null;
      _recommendation = null;
      _summary = null;
      _extractedUrls = const [];
      _isNepali = false;
      _guideNe = null;
      _stepsNe = const [];
    });

    try {
      final result = await AppStore.instance.analyzeSms(text);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _flags = result.flags;
        _risk = result.risk;
        _title = result.verdictTitle;
        _recommendation = result.recommendation;
        _summary = result.summary;
        _extractedUrls = result.extractedUrls;
        _isNepali = result.isNepali;
        _guideNe = result.guideNe;
        _stepsNe = result.stepsNe;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _scanUrl(String url) async {
    try {
      final result = await AppStore.instance.analyzeUrl(url);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ScanResultScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      appBar: AppBar(
        title: Text(
          'SMS Analyzer',
          style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'नेपाली वा अंग्रेजी सन्देश टाँस्नुहोस्। शंकास्पद भए SafeLink ले सजिलो भाषामा सल्लाह दिन्छ।\n'
            'Tip: Share from Messages → SafeLink to check automatically.',
            style: GoogleFonts.googleSans(
              fontSize: 13,
              color: AppColors.slate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Paste suspicious SMS / नेपाली सन्देश यहाँ…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _analyze,
            child: Text(_loading ? 'Analyzing…' : 'Analyze Text'),
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: AppColors.crimson),
          ],
          if (_flags != null && _risk != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: RiskStyle.soft(_risk!),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(RiskStyle.icon(_risk!), color: RiskStyle.color(_risk!)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _title ??
                              (_flags!.isEmpty
                                  ? 'No scam keywords flagged'
                                  : '${_flags!.length} flagged signals'),
                          style: GoogleFonts.googleSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: RiskStyle.color(_risk!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_summary != null && _summary!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _summary!,
                      style: GoogleFonts.googleSans(
                        color: AppColors.ink,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (_guideNe != null && _guideNe!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isNepali ? 'के गर्ने? (सजिलो सल्लाह)' : 'Guide / सल्लाह',
                            style: GoogleFonts.googleSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _guideNe!,
                            style: GoogleFonts.googleSans(
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: RiskStyle.color(_risk!),
                            ),
                          ),
                          if (_stepsNe.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ..._stepsNe.map(
                              (step) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: GoogleFonts.googleSans(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        step,
                                        style: GoogleFonts.googleSans(
                                          fontSize: 14,
                                          height: 1.35,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (_recommendation != null &&
                      _recommendation!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _recommendation!,
                      style: GoogleFonts.googleSans(
                        color: AppColors.slate,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (_flags!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Detected signals',
                      style: GoogleFonts.googleSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._flags!.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '"${f.word}"',
                              style: GoogleFonts.googleSans(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              f.reason,
                              style: GoogleFonts.googleSans(
                                color: AppColors.slate,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_extractedUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Links found — tap to scan / लिङ्क जाँच गर्नुहोस्',
                style: GoogleFonts.googleSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ..._extractedUrls.map(
                (url) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.googleSans(fontSize: 13),
                    ),
                    trailing: TextButton(
                      onPressed: () => _scanUrl(url),
                      child: const Text('Scan this link'),
                    ),
                    onTap: () => _scanUrl(url),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
