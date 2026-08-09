import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/models.dart';
import '../../models/risk_style.dart';
import '../../theme/app_colors.dart';

/// Full-screen in-app browser (Chromium/WebKit via webview_flutter).
class InAppBrowserScreen extends StatefulWidget {
  const InAppBrowserScreen({
    super.key,
    required this.url,
    required this.risk,
  });

  final String url;
  final RiskLevel risk;

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _progress = 0;
  String _title = 'Safe Browser';
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress;
              _loading = progress < 100;
            });
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _currentUrl = url;
              _loading = true;
            });
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            final title = await _controller.getTitle();
            setState(() {
              _currentUrl = url;
              _loading = false;
              if (title != null && title.trim().isNotEmpty) {
                _title = title;
              }
            });
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = RiskStyle.color(widget.risk);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.googleSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            Text(
              _currentUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.googleSans(
                fontSize: 11,
                color: AppColors.slate,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Back',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: RiskStyle.soft(widget.risk),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(RiskStyle.icon(widget.risk), size: 14, color: riskColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.risk == RiskLevel.safe
                            ? 'Browsing inside SafeLink'
                            : widget.risk == RiskLevel.caution
                                ? 'Caution — stay alert while browsing'
                                : 'Dangerous link — browsing not recommended',
                        style: GoogleFonts.googleSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: riskColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  minHeight: 2,
                  color: AppColors.accent,
                  backgroundColor: AppColors.accentSoft,
                )
              else
                const SizedBox(height: 2),
            ],
          ),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
