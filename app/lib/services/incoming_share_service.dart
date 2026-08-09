import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/link_extractor.dart';

enum IncomingKind { url, message, pasteCheck }

class IncomingPayload {
  const IncomingPayload({
    required this.kind,
    required this.raw,
    this.url,
  });

  final IncomingKind kind;
  final String raw;
  final String? url;
}

typedef IncomingHandler = void Function(IncomingPayload payload);

/// Listens for Share / Open-with / Process-text / widget deep links
/// via MainActivity channels.
class IncomingShareService {
  IncomingShareService._();
  static final IncomingShareService instance = IncomingShareService._();

  static const _events = EventChannel('com.scamlink/incoming_events');
  static const _methods = MethodChannel('com.scamlink/incoming_methods');

  final _seen = <String>{};

  StreamSubscription? _nativeSub;
  IncomingHandler? onIncoming;
  var _bootstrapped = false;

  /// True if a cold-start share/intent should skip the splash screen.
  var hadLaunchPayload = false;

  /// Launch payload captured during bootstrap (opened after Home is ready).
  IncomingPayload? launchPayload;

  Future<void> start({required IncomingHandler handler}) async {
    if (_bootstrapped) {
      onIncoming = handler;
      return;
    }
    _bootstrapped = true;
    onIncoming = handler;

    if (kIsWeb) return;

    // Cold-start share: peek then consume so we never lose the text.
    try {
      final initial = await _methods.invokeMethod<Map>('getInitialIncoming');
      if (initial != null) {
        final map = Map<String, dynamic>.from(initial);
        final payload = _payloadFromNative(map);
        if (payload != null) {
          hadLaunchPayload = true;
          launchPayload = payload;
          await _methods.invokeMethod('consumeInitialIncoming');
        }
      }
    } catch (_) {}

    _nativeSub = _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final payload = _payloadFromNative(Map<String, dynamic>.from(event));
        if (payload != null) {
          _deliver(payload);
        }
      }
    }, onError: (_) {});
  }

  void dispose() {
    _nativeSub?.cancel();
  }

  IncomingPayload? takeLaunchPayload() {
    final payload = launchPayload;
    launchPayload = null;
    return payload;
  }

  IncomingPayload? _payloadFromNative(Map<String, dynamic> map) {
    final text = (map['text'] as String?)?.trim();
    if (text == null || text.isEmpty) return null;
    final action = (map['action'] as String?) ?? '';
    if (action == 'view') {
      final uri = Uri.tryParse(text);
      if (uri != null) {
        if (LinkExtractor.isPasteCheckUri(uri)) {
          return IncomingPayload(
            kind: IncomingKind.pasteCheck,
            raw: uri.toString(),
          );
        }
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          return _fromText(uri.toString());
        }
      }
    }
    return _fromText(text);
  }

  IncomingPayload _fromText(String text) {
    final url = LinkExtractor.firstUrl(text);
    if (url != null &&
        (text.trim() == url || text.trim().length < url.length + 8)) {
      return IncomingPayload(kind: IncomingKind.url, raw: text, url: url);
    }
    if (url != null) {
      final withoutUrl = text.replaceAll(url, '').trim();
      if (withoutUrl.length < 12) {
        return IncomingPayload(kind: IncomingKind.url, raw: text, url: url);
      }
    }
    return IncomingPayload(
      kind: IncomingKind.message,
      raw: text,
      url: url,
    );
  }

  void _deliver(IncomingPayload payload) {
    final key = '${payload.kind}:${payload.raw}';
    if (_seen.contains(key)) return;
    _seen.add(key);
    if (_seen.length > 40) {
      _seen.remove(_seen.first);
    }
    hadLaunchPayload = true;
    onIncoming?.call(payload);
  }

  Future<void> emitClipboardPasteCheck() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _deliver(
        const IncomingPayload(
          kind: IncomingKind.pasteCheck,
          raw: '',
        ),
      );
      return;
    }
    _deliver(_fromText(text));
  }
}
