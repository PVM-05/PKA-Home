import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fee_tier_policy_model.dart';
import '../models/tiered_calculation_result_model.dart';
import '../repositories/fee_policy_repository.dart';

/// Provider cung cấp thể hiện của [FeePolicyRepository]
final feePolicyRepositoryProvider = Provider<FeePolicyRepository>((ref) {
  return FeePolicyRepository();
});

/// Provider truy xuất danh sách chính sách biểu giá phí theo mã tòa nhà [buildingId]
final feePoliciesProvider =
    FutureProvider.family<List<FeeTierPolicyModel>, String?>((ref, buildingId) async {
  final repo = ref.watch(feePolicyRepositoryProvider);
  return repo.fetchPolicies(buildingId: buildingId);
});

/// Alias tiện ích tương đương [feePoliciesProvider]
final buildingFeePoliciesProvider = feePoliciesProvider;

/// Provider tính toán lãi phạt trễ hạn cho hóa đơn [invoiceId]
final calculatedLatePenaltyProvider =
    FutureProvider.family<LatePenaltyResultModel, String>((ref, invoiceId) async {
  final repo = ref.watch(feePolicyRepositoryProvider);
  return repo.calculateLatePaymentPenalty(invoiceId: invoiceId);
});
