class OrganizationModel {
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? contactPhone;
  final String? contactEmail;
  final String status;
  final Map<String, dynamic> settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrganizationModel({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.contactPhone,
    this.contactEmail,
    this.status = 'active',
    this.settings = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      logoUrl: json['logo_url'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      status: json['status'] as String? ?? 'active',
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'logo_url': logoUrl,
    'contact_phone': contactPhone,
    'contact_email': contactEmail,
    'status': status,
    'settings': settings,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
