class IssueSlaStatsModel {
  final int totalIssues;
  final int onTimeCount;
  final int warningCount;
  final int breachedCount;
  final double complianceRate;

  const IssueSlaStatsModel({
    required this.totalIssues,
    required this.onTimeCount,
    required this.warningCount,
    required this.breachedCount,
    required this.complianceRate,
  });

  String get complianceRateFormatted => '${complianceRate.toStringAsFixed(1)}%';

  factory IssueSlaStatsModel.fromJson(Map<String, dynamic> json) {
    return IssueSlaStatsModel(
      totalIssues: (json['total_issues'] as num?)?.toInt() ?? 0,
      onTimeCount: (json['on_time_count'] as num?)?.toInt() ?? 0,
      warningCount: (json['warning_count'] as num?)?.toInt() ?? 0,
      breachedCount: (json['breached_count'] as num?)?.toInt() ?? 0,
      complianceRate: (json['compliance_rate'] as num?)?.toDouble() ?? 100.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_issues': totalIssues,
      'on_time_count': onTimeCount,
      'warning_count': warningCount,
      'breached_count': breachedCount,
      'compliance_rate': complianceRate,
    };
  }
}

