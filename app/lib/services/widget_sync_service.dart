import 'package:home_widget/home_widget.dart';

import '../models/models.dart';

/// Keeps the Android home-screen widget in sync with the latest scan.
abstract final class WidgetSyncService {
  static const androidName = 'SafeLinkWidgetProvider';
  static const qualifiedAndroidName =
      'com.scamlink.scamlink.SafeLinkWidgetProvider';

  static Future<void> updateFromRisk({
    required RiskLevel risk,
    String? detail,
    bool siteAvailable = true,
  }) async {
    final label = !siteAvailable
        ? 'Last check: site not available'
        : switch (risk) {
            RiskLevel.safe => 'Last check: Looks safe',
            RiskLevel.caution => 'Last check: Be careful',
            RiskLevel.danger => 'Last check: Likely a scam',
          };

    try {
      await HomeWidget.saveWidgetData<String>('verdict_label', label);
      if (detail != null && detail.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('verdict_detail', detail);
      }
      await HomeWidget.updateWidget(
        name: androidName,
        androidName: androidName,
        qualifiedAndroidName: qualifiedAndroidName,
      );
    } catch (_) {
      // Widget may not be installed yet.
    }
  }

  static Future<void> updateFromScan(ScanResult result) {
    return updateFromRisk(
      risk: result.risk,
      detail: result.summary,
      siteAvailable: result.siteAvailable,
    );
  }

  static Future<void> updateFromSms(SmsAnalysisResult result) {
    return updateFromRisk(risk: result.risk, detail: result.verdictTitle);
  }
}
