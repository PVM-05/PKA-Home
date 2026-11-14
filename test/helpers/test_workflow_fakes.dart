import 'package:pka_home/data/models/poll_model.dart';
import 'package:pka_home/data/models/poll_result_model.dart';
import 'package:pka_home/data/models/petition_model.dart';
import 'package:pka_home/data/models/parking_slot_model.dart';
import 'package:pka_home/data/models/parking_capacity_stats_model.dart';
import 'package:pka_home/data/models/visitor_parking_ticket_model.dart';
import 'package:pka_home/data/models/visitor_pass_model.dart';
import 'package:pka_home/data/models/parcel_model.dart';
import 'package:pka_home/data/models/front_desk_stats_model.dart';
import 'package:pka_home/data/repositories/community_repository.dart';
import 'package:pka_home/data/repositories/parking_repository.dart';
import 'package:pka_home/data/repositories/front_desk_repository.dart';

/// Fake repository phục vụ các integration workflow tests độc lập
class FakeCommunityWorkflowRepository extends CommunityRepository {
  final List<PollModel> _polls = [];
  final Map<String, Set<String>> _votedApartments = {};
  final List<PetitionModel> _petitions = [];
  final Map<String, Set<String>> _endorsedApartments = {};

  @override
  Future<List<PollModel>> fetchPolls({String? status, String? apartmentId}) async {
    var result = List<PollModel>.from(_polls);
    if (status != null && status.isNotEmpty) {
      result = result.where((p) => p.status == status).toList();
    }
    if (apartmentId != null && apartmentId.isNotEmpty) {
      result = result.map((p) {
        final votedSet = _votedApartments[p.id] ?? {};
        return p.copyWith(hasVoted: votedSet.contains(apartmentId));
      }).toList();
    }
    return result;
  }

  @override
  Future<PollModel> createPoll({
    required String title,
    String? description,
    String category = 'general',
    String voteWeightType = 'per_apartment',
    String choiceType = 'single_choice',
    double minParticipationRate = 50.0,
    double requiredApprovalRate = 50.0,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> options,
    required String createdBy,
    String? buildingId,
  }) async {
    final id = 'poll-${DateTime.now().millisecondsSinceEpoch}';
    final code = 'POLL-202611-${(_polls.length + 1).toString().padLeft(5, '0')}';
    final parsedOptions = options.asMap().entries.map(
      (e) => PollOptionModel(
        id: 'opt-$id-${e.key}',
        pollId: id,
        optionText: e.value,
        optionOrder: e.key + 1,
      ),
    ).toList();

    final poll = PollModel(
      id: id,
      pollCode: code,
      title: title,
      description: description,
      category: category,
      voteWeightType: voteWeightType,
      choiceType: choiceType,
      minParticipationRate: minParticipationRate,
      requiredApprovalRate: requiredApprovalRate,
      startTime: startTime,
      endTime: endTime,
      status: 'active',
      createdBy: createdBy,
      createdAt: DateTime.now(),
      options: parsedOptions,
    );
    _polls.insert(0, poll);
    return poll;
  }

  @override
  Future<Map<String, dynamic>> submitPollVote({
    required String pollId,
    required String apartmentId,
    String? voterUserId,
    required List<String> selectedOptionIds,
  }) async {
    final votedSet = _votedApartments.putIfAbsent(pollId, () => <String>{});
    if (votedSet.contains(apartmentId)) {
      return {'success': false, 'message': 'Căn hộ này đã tham gia biểu quyết rồi'};
    }
    votedSet.add(apartmentId);
    return {'success': true, 'message': 'Gửi phiếu thành công'};
  }

  @override
  Future<PollResultModel> getPollResults(String pollId) async {
    final poll = _polls.firstWhere((p) => p.id == pollId);
    final votedCount = (_votedApartments[poll.id] ?? {}).length + 35;
    const totalApts = 50;
    final rate = (votedCount / totalApts) * 100;

    final optResults = poll.options.asMap().entries.map((e) {
      final cnt = e.key == 0 ? 25 : 10;
      final pct = votedCount > 0 ? (cnt / votedCount) * 100 : 0.0;
      return PollOptionResultModel(
        optionId: e.value.id,
        optionText: e.value.optionText,
        voteCount: cnt,
        voteWeightSum: cnt * 75.0,
        percentOfVotes: double.parse(pct.toStringAsFixed(1)),
      );
    }).toList();

    return PollResultModel(
      pollId: poll.id,
      pollCode: poll.pollCode,
      title: poll.title,
      status: poll.status,
      voteWeightType: poll.voteWeightType,
      totalApartments: totalApts,
      votedApartments: votedCount,
      totalArea: totalApts * 75.0,
      votedArea: votedCount * 75.0,
      participationRate: double.parse(rate.toStringAsFixed(1)),
      isQuorumMet: rate >= poll.minParticipationRate,
      options: optResults,
    );
  }

  @override
  Future<List<PetitionModel>> fetchPetitions({String? status, String? category, String? apartmentId}) async {
    var result = List<PetitionModel>.from(_petitions);
    if (status != null && status.isNotEmpty) {
      result = result.where((p) => p.status == status).toList();
    }
    if (category != null && category.isNotEmpty) {
      result = result.where((p) => p.category == category).toList();
    }
    if (apartmentId != null && apartmentId.isNotEmpty) {
      result = result.map((p) {
        final endorsedSet = _endorsedApartments[p.id] ?? {};
        return p.copyWith(isEndorsedByMe: endorsedSet.contains(apartmentId));
      }).toList();
    }
    return result;
  }

  @override
  Future<PetitionModel> createPetition({
    required String apartmentId,
    required String authorUserId,
    required String title,
    required String content,
    String category = 'general',
    List<String> imageUrls = const [],
  }) async {
    final id = 'pet-${DateTime.now().millisecondsSinceEpoch}';
    final code = 'PET-202611-${(_petitions.length + 1).toString().padLeft(5, '0')}';
    final pet = PetitionModel(
      id: id,
      petitionCode: code,
      apartmentId: apartmentId,
      apartmentCode: 'A0110',
      authorUserId: authorUserId,
      authorName: 'Cư dân',
      title: title,
      content: content,
      category: category,
      imageUrls: imageUrls,
      endorsementCount: 0,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _petitions.insert(0, pet);
    return pet;
  }

  @override
  Future<Map<String, dynamic>> endorsePetition({
    required String petitionId,
    required String apartmentId,
    String? userId,
  }) async {
    final endorsedSet = _endorsedApartments.putIfAbsent(petitionId, () => <String>{});
    if (endorsedSet.contains(apartmentId)) {
      return {'success': false, 'message': 'Căn hộ đã đồng thuận rồi'};
    }
    endorsedSet.add(apartmentId);
    final idx = _petitions.indexWhere((p) => p.id == petitionId);
    int newCount = 1;
    if (idx != -1) {
      final current = _petitions[idx];
      newCount = current.endorsementCount + 1;
      _petitions[idx] = current.copyWith(
        endorsementCount: newCount,
        isEndorsedByMe: true,
      );
    }
    return {
      'success': true,
      'message': 'Đã đồng thuận',
      'endorsement_count': newCount,
    };
  }

  @override
  Future<Map<String, dynamic>> updatePetitionResponse({
    required String petitionId,
    required String status,
    required String officialResponse,
    required String staffId,
  }) async {
    final idx = _petitions.indexWhere((p) => p.id == petitionId);
    if (idx == -1) return {'success': false, 'message': 'Không tìm thấy'};
    _petitions[idx] = _petitions[idx].copyWith(
      status: status,
      officialResponse: officialResponse,
      respondedByStaffId: staffId,
      respondedAt: DateTime.now(),
    );
    return {'success': true, 'message': 'Thành công', 'status': status};
  }
}

/// Fake repository cho parking workflow integration test
class FakeParkingWorkflowRepository extends ParkingRepository {
  final List<VisitorParkingTicketModel> _tickets = [];
  final List<ParkingSlotModel> _slots = [
    ParkingSlotModel(
      id: 'slot-b1-01',
      zone: 'B1',
      slotNumber: 'P-B1-01',
      slotType: 'car',
      status: 'available',
      createdAt: DateTime.now(),
    ),
    ParkingSlotModel(
      id: 'slot-b1-02',
      zone: 'B1',
      slotNumber: 'P-B1-02',
      slotType: 'car',
      status: 'occupied',
      licensePlate: '30A-123.45',
      apartmentCode: 'A0101',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<ParkingSlotModel>> fetchSlots({
    String? buildingId,
    String? zone,
    String? slotType,
    String? status,
  }) async {
    return List<ParkingSlotModel>.from(_slots);
  }

  @override
  Future<Map<String, dynamic>> assignSlot({
    required String slotId,
    required String vehicleId,
    required String apartmentId,
    String? slotNumber,
    String? licensePlate,
    String? apartmentCode,
  }) async {
    final idx = _slots.indexWhere((s) => s.id == slotId);
    if (idx != -1) {
      _slots[idx] = _slots[idx].copyWith(
        status: 'occupied',
        licensePlate: licensePlate,
        apartmentCode: apartmentCode,
      );
    }
    return {'success': true, 'message': 'Đã gán ô đỗ'};
  }

  @override
  Future<Map<String, dynamic>> releaseSlot(String slotId) async {
    final idx = _slots.indexWhere((s) => s.id == slotId);
    if (idx != -1) {
      _slots[idx] = _slots[idx].copyWith(
        status: 'available',
        clearAssigned: true,
      );
    }
    return {'success': true, 'message': 'Đã giải phóng ô đỗ'};
  }

  @override
  Future<ParkingCapacityStatsModel> fetchCapacityStats({String? buildingId}) async {
    final carOccupied = _slots.where((s) => s.isCar && s.isOccupied).length;
    return ParkingCapacityStatsModel(
      carTotal: _slots.length,
      carOccupied: carOccupied,
      carAvailable: _slots.length - carOccupied,
      motoTotal: 10,
      motoOccupied: 4,
      motoAvailable: 6,
      visitorCount: _tickets.where((t) => t.isInParking).length,
    );
  }

  @override
  Future<Map<String, dynamic>> createVisitorTicket({
    required String licensePlate,
    required String vehicleType,
    String? buildingId,
    String? note,
  }) async {
    final now = DateTime.now();
    final ticket = VisitorParkingTicketModel(
      id: 'tkt-${now.millisecondsSinceEpoch}',
      ticketCode: 'TKT-202611-0001',
      licensePlate: licensePlate,
      vehicleType: vehicleType,
      checkInAt: now,
      status: 'in_parking',
      hourlyRate: vehicleType == 'car' ? 25000 : 5000,
      feeAmount: vehicleType == 'car' ? 25000 : 5000,
      qrPayload: 'PKAPARKING:TKT-202611-0001:$licensePlate',
      createdAt: now,
    );
    _tickets.insert(0, ticket);
    return {'success': true, 'ticket': ticket};
  }

  @override
  Future<List<VisitorParkingTicketModel>> fetchActiveVisitorTickets({String? buildingId}) async {
    return _tickets.where((t) => t.isInParking).toList();
  }

  @override
  Future<Map<String, dynamic>> calculateVisitorFee(String ticketId) async {
    final ticket = _tickets.firstWhere((t) => t.id == ticketId);
    return {
      'success': true,
      'ticket_id': ticket.id,
      'fee_amount': ticket.isCar ? 25000.0 : 5000.0,
      'total_hours': 1.0,
    };
  }

  @override
  Future<Map<String, dynamic>> checkoutVisitorTicket({
    required String ticketId,
    String paymentMethod = 'vietqr',
  }) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      _tickets[idx] = _tickets[idx].copyWith(
        status: 'completed',
        paymentStatus: 'paid',
        paymentMethod: paymentMethod,
      );
    }
    return {
      'success': true,
      'message': 'Đã thanh toán',
      'payment_method': paymentMethod,
    };
  }
}

/// Fake repository cho front desk workflow integration test
class FakeFrontDeskWorkflowRepository extends FrontDeskRepository {
  final List<VisitorPassModel> _passes = [];
  final List<ParcelModel> _parcels = [];

  @override
  Future<List<VisitorPassModel>> fetchVisitorPasses({String? apartmentId, String? status}) async {
    var result = List<VisitorPassModel>.from(_passes);
    if (status != null && status.isNotEmpty) {
      result = result.where((p) => p.status == status).toList();
    }
    return result;
  }

  @override
  Future<VisitorPassModel> createVisitorPass({
    required String apartmentId,
    required String hostUserId,
    required String visitorName,
    String? visitorPhone,
    String? licensePlate,
    String vehicleType = 'none',
    int visitorCount = 1,
    required DateTime expectedArrival,
    DateTime? expectedDeparture,
    String purpose = 'visit',
    String? note,
  }) async {
    final pass = VisitorPassModel(
      id: 'vp-${DateTime.now().millisecondsSinceEpoch}',
      passCode: 'VP-202611-00001',
      apartmentId: apartmentId,
      apartmentCode: 'A0110',
      hostUserId: hostUserId,
      visitorName: visitorName,
      expectedArrival: expectedArrival,
      purpose: purpose,
      qrPayload: 'PKAPASS.v1.VP-202611-00001',
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _passes.insert(0, pass);
    return pass;
  }

  @override
  Future<Map<String, dynamic>> checkInVisitor({required String passCode, String? guardId, String? qrPayload}) async {
    final idx = _passes.indexWhere((p) => p.passCode == passCode);
    if (idx != -1) {
      _passes[idx] = _passes[idx].copyWith(status: 'checked_in', checkInAt: DateTime.now());
      return {'success': true, 'message': 'Check-in thành công'};
    }
    return {'success': false, 'message': 'Không tìm thấy'};
  }

  @override
  Future<Map<String, dynamic>> checkOutVisitor({required String passCode, String? guardId}) async {
    final idx = _passes.indexWhere((p) => p.passCode == passCode);
    if (idx != -1) {
      _passes[idx] = _passes[idx].copyWith(status: 'checked_out', checkOutAt: DateTime.now());
      return {'success': true, 'message': 'Check-out thành công'};
    }
    return {'success': false, 'message': 'Không tìm thấy'};
  }

  @override
  Future<List<ParcelModel>> fetchParcels({String? status, String? apartmentId}) async {
    var result = List<ParcelModel>.from(_parcels);
    if (status != null && status.isNotEmpty) {
      result = result.where((p) => p.status == status).toList();
    }
    return result;
  }

  @override
  Future<ParcelModel> receiveParcel({
    required String apartmentId,
    String? recipientName,
    String carrier = 'SPX',
    String? trackingNumber,
    String? description,
    String shelfLocation = 'Kệ chung',
    String? imageUrl,
    required String staffId,
  }) async {
    final parcel = ParcelModel(
      id: 'pcl-${DateTime.now().millisecondsSinceEpoch}',
      parcelCode: 'PCL-202611-00001',
      apartmentId: apartmentId,
      apartmentCode: 'A0110',
      recipientName: recipientName,
      carrier: carrier,
      trackingNumber: trackingNumber,
      description: description,
      shelfLocation: shelfLocation,
      pickupPin: '123456',
      status: 'arrived',
      arrivedAt: DateTime.now(),
      receivedStaffId: staffId,
      createdAt: DateTime.now(),
    );
    _parcels.insert(0, parcel);
    return parcel;
  }

  @override
  Future<Map<String, dynamic>> collectParcel({
    required String parcelId,
    required String pickupPin,
    String? staffId,
    String collectedBy = 'Cư dân',
  }) async {
    final idx = _parcels.indexWhere((p) => p.id == parcelId);
    if (idx != -1) {
      if (_parcels[idx].pickupPin == pickupPin) {
        _parcels[idx] = _parcels[idx].copyWith(
          status: 'collected',
          collectedAt: DateTime.now(),
          collectedBy: collectedBy,
        );
        return {'success': true, 'message': 'Bàn giao thành công'};
      }
      return {'success': false, 'message': 'Mã PIN lấy hàng không chính xác!'};
    }
    return {'success': false, 'message': 'Không tìm thấy'};
  }

  @override
  Future<FrontDeskStatsModel> fetchFrontDeskStats({String? buildingId}) async {
    return FrontDeskStatsModel(
      expectedVisitorsToday: _passes.length,
      visitorsInBuilding: _passes.where((p) => p.status == 'checked_in').length,
      pendingParcels: _parcels.where((p) => p.status == 'arrived').length,
      overdueParcels: 0,
    );
  }
}
