class Referral {
  final int? id;
  final int patientId;
  final String referredTo;
  final String referralDate;
  final String referralNotes;
  final int? referringAdminId;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final String? patientName;
  final String? adminName;

  Referral({
    this.id,
    required this.patientId,
    required this.referredTo,
    required this.referralDate,
    required this.referralNotes,
    this.referringAdminId,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.patientName,
    this.adminName,
  });

  // Factory constructor to create a Referral from JSON
  factory Referral.fromJson(Map<String, dynamic> json) {
    return Referral(
      id: json['id'] as int?,
      patientId: json['patient_id'] as int,
      referredTo: json['referred_to'] as String? ?? '',
      referralDate: json['referral_date'] as String? ?? '',
      referralNotes: json['referral_notes'] as String? ?? '',
      referringAdminId: json['referring_admin_id'] as int?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      patientName: json['patientName'] as String?,
      adminName: json['admin_name'] as String?,
    );
  }

  // Method to convert Referral to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'referred_to': referredTo,
      'referral_date': referralDate,
      'referral_notes': referralNotes,
      'referring_admin_id': referringAdminId,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // Create a copy with updated values
  Referral copyWith({
    int? id,
    int? patientId,
    String? referredTo,
    String? referralDate,
    String? referralNotes,
    int? referringAdminId,
    String? status,
    String? createdAt,
    String? updatedAt,
    String? patientName,
    String? adminName,
  }) {
    return Referral(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      referredTo: referredTo ?? this.referredTo,
      referralDate: referralDate ?? this.referralDate,
      referralNotes: referralNotes ?? this.referralNotes,
      referringAdminId: referringAdminId ?? this.referringAdminId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      patientName: patientName ?? this.patientName,
      adminName: adminName ?? this.adminName,
    );
  }

  @override
  String toString() {
    return 'Referral{id: $id, patientId: $patientId, referredTo: $referredTo, referralDate: $referralDate, status: $status}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Referral &&
        other.id == id &&
        other.patientId == patientId &&
        other.referredTo == referredTo &&
        other.referralDate == referralDate &&
        other.referralNotes == referralNotes &&
        other.referringAdminId == referringAdminId &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        patientId.hashCode ^
        referredTo.hashCode ^
        referralDate.hashCode ^
        referralNotes.hashCode ^
        referringAdminId.hashCode ^
        status.hashCode;
  }
}
