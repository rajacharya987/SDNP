import '../models/models.dart';
import '../services/widget_sync_service.dart';
import 'api_client.dart';

/// App data store backed by the SafeLink / SentinelX API.
class AppStore {
  AppStore._({ApiClient? client}) : api = client ?? ApiClient();
  static final AppStore instance = AppStore._();

  final ApiClient api;

  final List<ScanRecord> history = [];
  var historyLoaded = false;

  List<ScanRecord> get recentLinks =>
      history.where((e) => e.kind == HistoryKind.link).take(8).toList();

  List<ScanRecord> get linkLogs =>
      history.where((e) => e.kind == HistoryKind.link).toList();

  List<ScanRecord> get otherLogs => history
      .where((e) => e.kind == HistoryKind.breach || e.kind == HistoryKind.text)
      .toList();

  Future<void> refreshHistory() async {
    final scans = await api.scanHistory();
    final breaches = await api.breachHistory();
    final merged = [...scans, ...breaches]
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    // Keep any local-only SMS checks that are not on the server.
    final localText = history.where((e) => e.kind == HistoryKind.text).toList();
    history
      ..clear()
      ..addAll(merged)
      ..addAll(localText);
    history.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    historyLoaded = true;
  }

  Future<ScanResult> analyzeUrl(String raw) async {
    final url = raw.trim();
    final result = await api.scanUrl(url);
    history.insert(0, ScanRecord.fromScanResult(result));
    // ignore: unawaited_futures
    WidgetSyncService.updateFromScan(result);
    return result;
  }

  Future<BreachCheckResult> checkBreach(String identifier) async {
    final result = await api.checkBreach(identifier.trim());
    history.insert(
      0,
      ScanRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: result.account.isEmpty ? identifier : result.account,
        risk: result.breached ? RiskLevel.caution : RiskLevel.safe,
        scannedAt: DateTime.now(),
        kind: HistoryKind.breach,
        detail: result.breached
            ? '${result.breachCount} breaches found'
            : 'No breaches',
      ),
    );
    return result;
  }

  Future<SmsAnalysisResult> analyzeSms(String message) async {
    final result = await api.analyzeSms(message.trim());
    final preview =
        message.length > 48 ? '${message.substring(0, 48)}…' : message;
    history.insert(
      0,
      ScanRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: preview,
        risk: result.risk,
        scannedAt: DateTime.now(),
        kind: HistoryKind.text,
        detail: result.verdictTitle,
      ),
    );
    // ignore: unawaited_futures
    WidgetSyncService.updateFromSms(result);
    return result;
  }

  Future<String> generateTempMail() => api.generateTempMail();

  Future<List<TempMailMessage>> tempMailInbox(String address) =>
      api.tempMailInbox(address);

  Future<bool> ping() => api.health();

  void clearHistory() => history.clear();

  void remove(String id) => history.removeWhere((e) => e.id == id);
}
