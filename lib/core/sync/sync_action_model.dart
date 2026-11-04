enum SyncStatus {
  pending,
  syncing,
  failed,
  completed;

  static SyncStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'syncing':
        return SyncStatus.syncing;
      case 'failed':
        return SyncStatus.failed;
      case 'completed':
        return SyncStatus.completed;
      case 'pending':
      default:
        return SyncStatus.pending;
    }
  }
}

class SyncActionModel {
  final String id;
  final String actionType;
  final String endpoint;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final SyncStatus status;
  final String? lastError;
  final String idempotencyKey;

  const SyncActionModel({
    required this.id,
    required this.actionType,
    required this.endpoint,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
    this.lastError,
    required this.idempotencyKey,
  });

  SyncActionModel copyWith({
    String? id,
    String? actionType,
    String? endpoint,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
    SyncStatus? status,
    String? lastError,
    String? idempotencyKey,
  }) {
    return SyncActionModel(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      endpoint: endpoint ?? this.endpoint,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  factory SyncActionModel.fromJson(Map<String, dynamic> json) {
    return SyncActionModel(
      id: json['id']?.toString() ?? '',
      actionType: json['action_type']?.toString() ?? '',
      endpoint: json['endpoint']?.toString() ?? '',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      status: SyncStatus.fromString(json['status']?.toString()),
      lastError: json['last_error']?.toString(),
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'action_type': actionType,
    'endpoint': endpoint,
    'payload': payload,
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
    'status': status.name,
    'last_error': lastError,
    'idempotency_key': idempotencyKey,
  };
}
