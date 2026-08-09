enum RiskLevel { safe, caution, danger }

extension RiskLevelX on RiskLevel {
  String get label => switch (this) {
        RiskLevel.safe => 'Safe',
        RiskLevel.caution => 'Caution',
        RiskLevel.danger => 'Dangerous',
      };

  String get verdictTitle => switch (this) {
        RiskLevel.safe => 'Safe Link',
        RiskLevel.caution => 'Suspicious Link',
        RiskLevel.danger => 'Dangerous Phishing Site',
      };
}

RiskLevel riskFromVerdict(String? verdict) {
  final v = (verdict ?? '').toUpperCase();
  if (v.contains('DANGER') || v.contains('HIGH_RISK')) {
    return RiskLevel.danger;
  }
  if (v.contains('SUSPICIOUS') ||
      v.contains('MEDIUM') ||
      v.contains('INCOMPLETE') ||
      v.contains('UNVERIFIED') ||
      v.contains('UNAVAILABLE')) {
    return RiskLevel.caution;
  }
  return RiskLevel.safe;
}

DateTime? _parseDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

enum HistoryKind { link, breach, text }

class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.url,
    required this.risk,
    required this.scannedAt,
    this.kind = HistoryKind.link,
    this.detail,
  });

  final String id;
  final String url;
  final RiskLevel risk;
  final DateTime scannedAt;
  final HistoryKind kind;
  final String? detail;

  factory ScanRecord.fromScanApi(Map<String, dynamic> json) {
    return ScanRecord(
      id: '${json['id'] ?? json['url']}',
      url: (json['url'] as String?) ?? '',
      risk: riskFromVerdict(json['verdict'] as String?),
      scannedAt: _parseDate(json['created_at'] ?? json['scanned_at']) ??
          DateTime.now(),
      kind: HistoryKind.link,
      detail: json['verdict'] as String?,
    );
  }

  factory ScanRecord.fromBreachApi(Map<String, dynamic> json) {
    final count = (json['breach_count'] as num?)?.toInt() ?? 0;
    final breached = json['is_breached'] == true || count > 0;
    return ScanRecord(
      id: 'breach-${json['id'] ?? json['identifier']}',
      url: (json['identifier'] as String?) ?? '',
      risk: breached ? RiskLevel.caution : RiskLevel.safe,
      scannedAt: _parseDate(json['created_at']) ?? DateTime.now(),
      kind: HistoryKind.breach,
      detail: breached ? '$count breaches found' : 'No breaches',
    );
  }

  factory ScanRecord.fromScanResult(ScanResult result) {
    return ScanRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: result.url,
      risk: result.risk,
      scannedAt: DateTime.now(),
      detail: result.summary,
    );
  }
}

class ProviderCheck {
  const ProviderCheck({
    required this.name,
    required this.status,
    this.message,
  });

  final String name;
  final String status;
  final String? message;

  bool get isClean => status == 'clean';
  bool get isFlagged => status == 'flagged';
  bool get isFailed => status == 'error';
  bool get isUntested => status == 'untested';

  String get statusLabel {
    if (isClean) return 'Clean';
    if (isFlagged) return 'Flagged';
    if (isFailed) return 'Check failed';
    if (isUntested) return 'Not configured';
    return status;
  }

  factory ProviderCheck.fromBreakdown(String name, Map<String, dynamic>? raw) {
    raw ??= const {};
    return ProviderCheck(
      name: name,
      status: (raw['status'] as String?) ?? 'error',
      message: raw['message'] as String?,
    );
  }
}

class ScanResult {
  const ScanResult({
    required this.url,
    required this.risk,
    required this.safeBrowsingOk,
    required this.sslValid,
    required this.redirects,
    this.domainAgeDays,
    this.summary,
    this.analystSummary,
    this.riskScore,
    this.threatDetails = const [],
    this.checksComplete = false,
    this.siteAvailable = true,
    this.availabilityMessage,
    this.providers = const [],
  });

  final String url;
  final RiskLevel risk;
  final bool safeBrowsingOk;
  final int? domainAgeDays;
  final bool sslValid;
  final List<String> redirects;
  final String? summary;
  final String? analystSummary;
  final int? riskScore;
  final List<String> threatDetails;
  final bool checksComplete;
  final bool siteAvailable;
  final String? availabilityMessage;
  final List<ProviderCheck> providers;

  factory ScanResult.fromApi(Map<String, dynamic> data) {
    final url = (data['url'] as String?) ?? '';
    final risk = riskFromVerdict(data['verdict'] as String?);
    final breakdown = data['breakdown'] as Map<String, dynamic>? ?? {};
    final gsb =
        breakdown['google_safe_browsing'] as Map<String, dynamic>? ?? {};
    final availability =
        breakdown['availability'] as Map<String, dynamic>? ?? {};
    final threats = (data['threat_details'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    final gsbStatus = (gsb['status'] as String?) ?? 'error';
    final siteAvailable = data['site_available'] == true ||
        availability['available'] == true;
    final providers = <ProviderCheck>[
      ProviderCheck.fromBreakdown(
        'Site availability',
        {
          'status': siteAvailable ? 'clean' : 'flagged',
          'message': availability['message'] ??
              (siteAvailable
                  ? 'Site is reachable'
                  : 'This site is not available'),
        },
      ),
      ProviderCheck.fromBreakdown(
        'Google Safe Browsing',
        breakdown['google_safe_browsing'] as Map<String, dynamic>?,
      ),
      ProviderCheck.fromBreakdown(
        'VirusTotal',
        breakdown['virustotal'] as Map<String, dynamic>?,
      ),
      ProviderCheck.fromBreakdown(
        'OpenPhish',
        breakdown['openphish'] as Map<String, dynamic>?,
      ),
      ProviderCheck.fromBreakdown(
        'PhishTank',
        breakdown['phishtank'] as Map<String, dynamic>?,
      ),
      ProviderCheck.fromBreakdown(
        'URLhaus',
        breakdown['urlhaus'] as Map<String, dynamic>?,
      ),
      ProviderCheck.fromBreakdown(
        'Deep pattern analysis',
        breakdown['deep_analysis'] as Map<String, dynamic>?,
      ),
    ];

    final deep =
        breakdown['deep_analysis'] as Map<String, dynamic>? ?? {};
    final analyst = (data['analyst_summary'] as String?) ??
        (deep['summary'] as String?);

    return ScanResult(
      url: url,
      risk: risk,
      safeBrowsingOk: gsbStatus == 'clean',
      domainAgeDays: null,
      sslValid: url.toLowerCase().startsWith('https://'),
      redirects: [url],
      summary: data['verdict_title'] as String?,
      analystSummary: analyst,
      riskScore: (data['risk_score'] as num?)?.toInt(),
      threatDetails: threats,
      checksComplete: data['checks_complete'] == true,
      siteAvailable: siteAvailable,
      availabilityMessage: availability['message'] as String? ??
          (siteAvailable ? null : 'This site is not available'),
      providers: providers,
    );
  }
}

class BreachHit {
  const BreachHit({
    required this.service,
    required this.year,
    required this.dataTypes,
  });

  final String service;
  final int year;
  final String dataTypes;
}

class BreachCheckResult {
  const BreachCheckResult({
    required this.account,
    required this.breached,
    required this.breachCount,
    required this.hits,
    required this.message,
  });

  final String account;
  final bool breached;
  final int breachCount;
  final List<BreachHit> hits;
  final String message;

  factory BreachCheckResult.fromApi(Map<String, dynamic> data) {
    final breaches = data['breaches'];
    final hits = <BreachHit>[];
    if (breaches is List) {
      for (final item in breaches.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        hits.add(
          BreachHit(
            service: (map['title'] as String?) ??
                (map['name'] as String?) ??
                'Unknown',
            year: DateTime.tryParse(map['breach_date']?.toString() ?? '')
                    ?.year ??
                0,
            dataTypes: (map['description'] as String?) ??
                'Exposed account details',
          ),
        );
      }
    }

    return BreachCheckResult(
      account: (data['account'] as String?) ?? '',
      breached: data['breached'] == true,
      breachCount: (data['breach_count'] as num?)?.toInt() ?? hits.length,
      hits: hits,
      message: (data['message'] as String?) ?? '',
    );
  }
}

class TempMailMessage {
  const TempMailMessage({
    required this.id,
    required this.from,
    required this.subject,
    required this.preview,
    required this.receivedAt,
  });

  final String id;
  final String from;
  final String subject;
  final String preview;
  final DateTime receivedAt;

  factory TempMailMessage.fromApi(Map<String, dynamic> json) {
    final body = (json['body'] as String?) ?? '';
    return TempMailMessage(
      id: '${json['id'] ?? ''}',
      from: (json['sender'] as String?) ?? (json['from'] as String?) ?? '',
      subject: (json['subject'] as String?) ?? '(no subject)',
      preview: body.isNotEmpty
          ? body
          : ((json['preview'] as String?) ?? ''),
      receivedAt: _parseDate(json['received_at']) ?? DateTime.now(),
    );
  }
}

class FlaggedKeyword {
  const FlaggedKeyword({required this.word, required this.reason});

  final String word;
  final String reason;
}

class SmsAnalysisResult {
  const SmsAnalysisResult({
    required this.risk,
    required this.verdictTitle,
    required this.flags,
    required this.recommendation,
    this.riskScore,
    this.summary,
    this.extractedUrls = const [],
    this.isNepali = false,
    this.guideNe,
    this.guideEn,
    this.stepsNe = const [],
  });

  final RiskLevel risk;
  final String verdictTitle;
  final List<FlaggedKeyword> flags;
  final String recommendation;
  final int? riskScore;
  final String? summary;
  final List<String> extractedUrls;
  final bool isNepali;
  final String? guideNe;
  final String? guideEn;
  final List<String> stepsNe;

  factory SmsAnalysisResult.fromApi(Map<String, dynamic> data) {
    final flagsRaw = data['flags_detected'] as List? ?? const [];
    final flags = flagsRaw
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .map((e) {
          final parts = e.split(':');
          if (parts.length >= 2) {
            return FlaggedKeyword(
              word: parts.first.trim(),
              reason: parts.sublist(1).join(':').trim(),
            );
          }
          return FlaggedKeyword(word: e, reason: 'Detected scam signal');
        })
        .toList();

    final urls = (data['extracted_urls'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    final steps = (data['steps_ne'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    return SmsAnalysisResult(
      risk: riskFromVerdict(data['verdict'] as String?),
      verdictTitle: (data['verdict_title'] as String?) ?? 'Analysis complete',
      flags: flags,
      recommendation: (data['recommendation'] as String?) ?? '',
      riskScore: (data['risk_score'] as num?)?.toInt(),
      summary: data['summary'] as String?,
      extractedUrls: urls,
      isNepali: data['is_nepali'] == true || data['language'] == 'ne',
      guideNe: data['guide_ne'] as String?,
      guideEn: data['guide_en'] as String?,
      stepsNe: steps,
    );
  }
}
