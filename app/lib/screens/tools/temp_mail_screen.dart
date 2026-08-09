import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

class TempMailScreen extends StatefulWidget {
  const TempMailScreen({super.key});

  @override
  State<TempMailScreen> createState() => _TempMailScreenState();
}

class _TempMailScreenState extends State<TempMailScreen> {
  String? _address;
  var _messages = <TempMailMessage>[];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = await AppStore.instance.generateTempMail();
      final inbox = email.isEmpty
          ? <TempMailMessage>[]
          : await AppStore.instance.tempMailInbox(email);
      if (!mounted) return;
      setState(() {
        _address = email;
        _messages = inbox;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    final address = _address;
    if (address == null || address.isEmpty) {
      await _bootstrap();
      return;
    }
    try {
      final inbox = await AppStore.instance.tempMailInbox(address);
      if (!mounted) return;
      setState(() => _messages = inbox);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _copy() async {
    final address = _address;
    if (address == null || address.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Temp email copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      appBar: AppBar(
        title: Text(
          'Temp Mail',
          style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'New address',
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(AppIcons.mail),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.googleSans(color: AppColors.slate),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _bootstrap,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(AppIcons.mail, color: AppColors.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _address ?? '',
                                style: GoogleFonts.googleSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy',
                              onPressed: _copy,
                              icon: const Icon(AppIcons.copy),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.crimson,
                        onRefresh: _refresh,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                          itemCount: _messages.isEmpty ? 1 : _messages.length,
                          itemBuilder: (context, i) {
                            if (_messages.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Text(
                                  'Inbox is empty. Pull to refresh.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.googleSans(
                                    color: AppColors.slate,
                                  ),
                                ),
                              );
                            }
                            final mail = _messages[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mail.subject,
                                    style: GoogleFonts.googleSans(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mail.from,
                                    style: GoogleFonts.googleSans(
                                      color: AppColors.crimson,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    mail.preview,
                                    style: GoogleFonts.googleSans(
                                      color: AppColors.slate,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
