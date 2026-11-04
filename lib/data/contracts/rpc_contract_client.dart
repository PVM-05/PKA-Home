import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ngoại lệ chuẩn hóa khi tương tác với PostgreSQL RPC
class RpcContractException implements Exception {
  final String rpcName;
  final String message;
  final Object? underlyingError;
  final StackTrace? stackTrace;

  const RpcContractException({
    required this.rpcName,
    required this.message,
    this.underlyingError,
    this.stackTrace,
  });

  @override
  String toString() => 'RpcContractException [$rpcName]: $message';
}

/// Lớp client bao bọc các lời gọi RPC đảm bảo tính toàn vẹn kiểu dữ liệu
class RpcContractClient {
  final SupabaseClient _client;

  RpcContractClient(this._client);

  SupabaseClient get client => _client;

  /// Thực thi một lời gọi RPC với Request DTO và Response DTO xác định
  Future<TResponse> execute<TRequest, TResponse>({
    required String rpcName,
    required TRequest request,
    required Map<String, dynamic> Function(TRequest req) toParams,
    required TResponse Function(dynamic raw) fromResponse,
  }) async {
    try {
      final params = toParams(request);
      final rawResult = await _client.rpc(rpcName, params: params);
      return fromResponse(rawResult);
    } catch (e, stack) {
      debugPrint('[RpcContractClient] Lỗi thực thi RPC $rpcName: $e');
      if (e is RpcContractException) {
        rethrow;
      }
      throw RpcContractException(
        rpcName: rpcName,
        message: 'Thực thi hàm $rpcName không thành công: ${e.toString()}',
        underlyingError: e,
        stackTrace: stack,
      );
    }
  }
}
