import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/main_layout.dart';
import 'screens/share/incoming_check_screen.dart';
import 'screens/splash_screen.dart';
import 'services/clipboard_monitor_service.dart';
import 'services/incoming_share_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const _onboardingDoneKey = 'onboarding_done';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScamLinkApp());
}

class ScamLinkApp extends StatelessWidget {
  const ScamLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: appNavigatorKey,
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  var _ready = false;
  var _showSplash = true;
  IncomingPayload? _activeShare;
  final _clipboard = ClipboardMonitorService.instance;
  final _shares = IncomingShareService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool(_onboardingDoneKey) ?? false;

    await _clipboard.init();
    await _shares.start(handler: _onIncoming);

    // Prefer showing the check screen immediately for Share → SafeLink.
    final launch = _shares.takeLaunchPayload();
    final skipSplash =
        seenOnboarding || launch != null || _shares.hadLaunchPayload;

    if (!mounted) return;
    setState(() {
      _activeShare = launch;
      _showSplash = !skipSplash && launch == null;
      _ready = true;
    });

    _clipboard.onUrlDetected = _onClipboardUrl;
    _clipboard.start();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipboard.stop();
    _shares.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clipboard.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _clipboard.stop();
    }
  }

  void _onIncoming(IncomingPayload payload) {
    if (!mounted) return;
    // Warm share while app is already open: show check as full screen root.
    setState(() {
      _showSplash = false;
      _activeShare = payload;
      _ready = true;
    });
  }

  Future<void> _onClipboardUrl(String url) async {
    final nav = appNavigatorKey.currentState;
    final ctx = nav?.overlay?.context ?? context;
    if (!ctx.mounted) return;

    final check = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Check this link?'),
        content: Text(
          'SafeLink found a link on your clipboard:\n\n$url',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Check'),
          ),
        ],
      ),
    );

    await _clipboard.markHandled(url);
    if (check == true && mounted) {
      setState(() {
        _activeShare = IncomingPayload(
          kind: IncomingKind.url,
          raw: url,
          url: url,
        );
      });
    }
  }

  void _closeShare() {
    if (!mounted) return;
    setState(() => _activeShare = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.mist,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    // Share / widget / open-with: go straight to the big check screen.
    if (_activeShare != null) {
      return IncomingCheckScreen(
        key: ValueKey(
          '${_activeShare!.kind}:${_activeShare!.raw}',
        ),
        payload: _activeShare!,
        onClose: _closeShare,
      );
    }

    if (_showSplash) {
      return SplashScreen(onGetStarted: _finishOnboarding);
    }
    return const MainLayout();
  }
}
