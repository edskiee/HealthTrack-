class HealthRecord {
  final int? id;
  final int userId;
  final String recordType;
  final String title;
  final String? description;
  final String? values;
  final String? unit;
  final String dateRecorded;
  final String? doctorName;
  final String? clinicHospital;
  final String? attachments;
  final String? createdAt;

  HealthRecord({
    this.id,
    required this.userId,
    required this.recordType,
    required this.title,
    this.description,
    this.values,
    this.unit,
    required this.dateRecorded,
    this.doctorName,
    this.clinicHospital,
    this.attachments,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'record_type': recordType,
      'title': title,
      'description': description,
      'record_values': values,  // Updated to match database column name
      'unit': unit,
      'date_recorded': dateRecorded,
      'doctor_name': doctorName,
      'clinic_hospital': clinicHospital,
      'attachments': attachments,
      'created_at': createdAt,
    };
  }

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'],
      userId: map['user_id'],
      recordType: map['record_type'],
      title: map['title'],
      description: map['description'],
      values: map['record_values'],  // Updated to match database column name
      unit: map['unit'],
      dateRecorded: map['date_recorded'],
      doctorName: map['doctor_name'],
      clinicHospital: map['clinic_hospital'],
      attachments: map['attachments'],
      createdAt: map['created_at'],
    );
  }

  HealthRecord copyWith({
    int? id,
    int? userId,
    String? recordType,
    String? title,
    String? description,
    String? values,
    String? unit,
    String? dateRecorded,
    String? doctorName,
    String? clinicHospital,
    String? attachments,
    String? createdAt,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recordType: recordType ?? this.recordType,
      title: title ?? this.title,
      description: description ?? this.description,
      values: values ?? this.values,
      unit: unit ?? this.unit,
      dateRecorded: dateRecorded ?? this.dateRecorded,
      doctorName: doctorName ?? this.doctorName,
      clinicHospital: clinicHospital ?? this.clinicHospital,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}