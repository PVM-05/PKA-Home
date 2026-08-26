class UserModel {
  final String id;
  final String hoTen;
  final String vaiTro; // 'cudan' or 'banquanly'
  final String? idCanHo;

  UserModel({
    required this.id,
    required this.hoTen,
    required this.vaiTro,
    this.idCanHo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      hoTen: json['ho_ten'] as String,
      vaiTro: json['vai_tro'] as String,
      idCanHo: json['id_can_ho'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ho_ten': hoTen,
      'vai_tro': vaiTro,
      'id_can_ho': idCanHo,
    };
  }
}
