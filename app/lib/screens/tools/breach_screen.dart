import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

class BreachScreen extends StatefulWidget {
  const BreachScreen({super.key});

  @override
  State<BreachScreen> createState() => _BreachScreenState();
}

class _BreachScreenState extends State<BreachScreen> {
  final _controller = TextEditingController();
  var _loading = false;
  List<BreachHit>? _hits;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _hits = null;
      _message = null;
    });

    try {
      final result = await AppStore.instance.checkBreach(query);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hits = result.hits;
        _message = result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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
          'Breach Checker',
          style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email or phone number',
              prefixIcon: Icon(AppIcons.emailAt),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _check,
            child: Text(_loading ? 'Checking…' : 'Check Breaches'),
          ),
          if (_loading) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(color: AppColors.crimson),
          ],
          if (_hits != null) ...[
            const SizedBox(height: 24),
            if (_hits!.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.safeSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      AppIcons.shield,
                      size: 56,
                      color: AppColors.safe,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Looking good',
                      style: GoogleFonts.googleSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppColors.safe,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _message ??
                          'No known breaches found for this identity.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.googleSans(color: AppColors.slate),
                    ),
                  ],
                ),
              )
            else
              ..._hits!.map(
                (hit) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.caution.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          AppIcons.warning,
                          color: AppColors.caution,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hit.service,
                                style: GoogleFonts.googleSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              if (hit.year > 0)
                                Text(
                                  'Breached in ${hit.year}',
                                  style: GoogleFonts.googleSans(
                                    color: AppColors.slate,
                                    fontSize: 13,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                hit.dataTypes,
                                style: GoogleFonts.googleSans(
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
