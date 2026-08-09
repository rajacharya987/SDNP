import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_store.dart';
import '../../services/clipboard_monitor_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../widgets/app_header.dart';
import '../notifications/notifications_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _clipboardMonitor = true;
  var _themeMode = 'System';
  final _clipboard = ClipboardMonitorService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _clipboard.init();
    if (mounted) {
      setState(() => _clipboardMonitor = _clipboard.enabled);
    }
  }

  Future<void> _pickTheme() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          'Theme',
          style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
        ),
        children: [
          for (final mode in ['System', 'Light', 'Dark'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, mode),
              child: Text(mode, style: GoogleFonts.googleSans()),
            ),
        ],
      ),
    );
    if (selected != null) setState(() => _themeMode = selected);
  }

  Future<void> _onClipboardToggle(bool value) async {
    setState(() => _clipboardMonitor = value);
    await _clipboard.setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final isRootTab = ModalRoute.of(context)?.isFirst ?? false;

    return AppPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isRootTab)
                AppHeader(
                  onNotificationTap: () => openNotifications(context),
                )
              else
                AppBar(
                  title: Text(
                    'Settings',
                    style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: Colors.transparent,
                ),
              if (isRootTab)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Text(
                    'Settings',
                    style: GoogleFonts.googleSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    _SectionLabel('Protection'),
                    _SettingsCard(
                      child: SwitchListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          'Clipboard auto-monitor',
                          style: GoogleFonts.googleSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'While SafeLink is open, ask to check new copied links',
                          style: GoogleFonts.googleSans(
                            fontSize: 13,
                            color: AppColors.slate,
                          ),
                        ),
                        activeThumbColor: AppColors.white,
                        activeTrackColor: AppColors.accent,
                        value: _clipboardMonitor,
                        onChanged: _onClipboardToggle,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('Appearance'),
                    _SettingsCard(
                      child: ListTile(
                        title: Text(
                          'Theme',
                          style: GoogleFonts.googleSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(_themeMode),
                        trailing: const Icon(AppIcons.chevronRight, size: 18),
                        onTap: _pickTheme,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('About'),
                    _SettingsCard(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              'How to check a chat link',
                              style: GoogleFonts.googleSans(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'In WhatsApp, SMS, Instagram, TikTok, or email: Share → SafeLink',
                              style: GoogleFonts.googleSans(
                                fontSize: 13,
                                color: AppColors.slate,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: Text(
                              'Home screen widget',
                              style: GoogleFonts.googleSans(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Long-press home screen → Widgets → SafeLink → Paste & Check',
                              style: GoogleFonts.googleSans(
                                fontSize: 13,
                                color: AppColors.slate,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: Text(
                              'Version',
                              style: GoogleFonts.googleSans(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '1.0.0',
                              style: GoogleFonts.googleSans(
                                fontSize: 13,
                                color: AppColors.slate,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsCard(
                      child: ListTile(
                        title: Text(
                          'Clear local history',
                          style: GoogleFonts.googleSans(
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                        onTap: () {
                          AppStore.instance.clearHistory();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('History cleared')),
                          );
                        },
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: GoogleFonts.googleSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: child,
    );
  }
}
