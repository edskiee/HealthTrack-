class Patient {
  final int? id;
  final int? userId;
  final String patientId;
  final String? medicalRecordNumber;
  final String? insuranceInfo;
  final String? doctorAssigned;
  final String status;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  Patient({
    this.id,
    this.userId,
    required this.patientId,
    this.medicalRecordNumber,
    this.insuranceInfo,
    this.doctorAssigned,
    this.status = 'active',
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'patient_id': patientId,
      'medical_record_number': medicalRecordNumber,
      'insurance_info': insuranceInfo,
      'doctor_assigned': doctorAssigned,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'],
      userId: map['user_id'],
      patientId: map['patient_id'],
      medicalRecordNumber: map['medical_record_number'],
      insuranceInfo: map['insurance_info'],
      doctorAssigned: map['doctor_assigned'],
      status: map['status'] ?? 'active',
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Patient copyWith({
    int? id,
    int? userId,
    String? patientId,
    String? medicalRecordNumber,
    String? insuranceInfo,
    String? doctorAssigned,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      patientId: patientId ?? this.patientId,
      medicalRecordNumber: medicalRecordNumber ?? this.medicalRecordNumber,
      insuranceInfo: insuranceInfo ?? this.insuranceInfo,
      doctorAssigned: doctorAssigned ?? this.doctorAssigned,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}