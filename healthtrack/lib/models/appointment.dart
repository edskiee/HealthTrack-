class Appointment {
  final int? id;
  final int userId;
  final String doctorName;
  final String clinicHospital;
  final String appointmentDate;
  final String appointmentTime;
  final String appointmentType;
  final String status;
  final String? completedAt;
  final String? missedAt;
  final String? notes;
  final bool reminderSet;
  final String? createdAt;
  final String? updatedAt;

  Appointment({
    this.id,
    required this.userId,
    required this.doctorName,
    required this.clinicHospital,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.appointmentType,
    this.status = 'pending',
    this.completedAt,
    this.missedAt,
    this.notes,
    this.reminderSet = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'doctor_name': doctorName,
      'clinic_hospital': clinicHospital,
      'appointment_date': appointmentDate,
      'appointment_time': appointmentTime,
      'appointment_type': appointmentType,
      'status': status,
      'completed_at': completedAt,
      'missed_at': missedAt,
      'notes': notes,
      'reminder_set': reminderSet ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'],
      userId: map['user_id'],
      doctorName: map['doctor_name'],
      clinicHospital: map['clinic_hospital'],
      appointmentDate: map['appointment_date'],
      appointmentTime: map['appointment_time'],
      appointmentType: map['appointment_type'],
      status: map['status'] ?? 'pending',
      completedAt: map['completed_at']?.toString(),
      missedAt: map['missed_at']?.toString(),
      notes: map['notes'],
      reminderSet: map['reminder_set'] == 1,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Appointment copyWith({
    int? id,
    int? userId,
    String? doctorName,
    String? clinicHospital,
    String? appointmentDate,
    String? appointmentTime,
    String? appointmentType,
    String? status,
    String? completedAt,
    String? missedAt,
    String? notes,
    bool? reminderSet,
    String? createdAt,
    String? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      doctorName: doctorName ?? this.doctorName,
      clinicHospital: clinicHospital ?? this.clinicHospital,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      appointmentType: appointmentType ?? this.appointmentType,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      missedAt: missedAt ?? this.missedAt,
      notes: notes ?? this.notes,
      reminderSet: reminderSet ?? this.reminderSet,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}