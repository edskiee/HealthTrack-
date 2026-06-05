class ServiceModel {
  final int? id;
  final String serviceName;
  final String? serviceDescription;
  final String serviceType;
  final bool? isEnabled;
  final List<String>? requiredFields;
  final List<String>? availableDays;
  final int? maxAppointmentsPerDay;

  ServiceModel({
    this.id,
    required this.serviceName,
    this.serviceDescription,
    required this.serviceType,
    this.isEnabled,
    this.requiredFields,
    this.availableDays,
    this.maxAppointmentsPerDay,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    // Handle is_enabled field that might come as int from MySQL
    // Also fall back to is_active if is_enabled is absent
    bool? enabledValue;
    final isEnabledField = json['is_enabled'] ?? json['isEnabled'] ?? json['is_active'];
    if (isEnabledField != null) {
      if (isEnabledField is bool) {
        enabledValue = isEnabledField;
      } else if (isEnabledField is int) {
        enabledValue = isEnabledField == 1;
      }
    }

    return ServiceModel(
      id: json['id'],
      serviceName: json['service_name'] ?? json['serviceName'] ?? '',
      serviceDescription: json['service_description'] ?? json['serviceDescription'],
      serviceType: json['service_type'] ?? json['serviceType'] ?? 'immunization',
      isEnabled: enabledValue ?? true,
      requiredFields: json['required_fields'] != null
          ? List<String>.from(json['required_fields'])
          : [],
      availableDays: json['available_days'] != null
          ? List<String>.from(json['available_days'])
          : [],
      maxAppointmentsPerDay: json['max_appointments_per_day'] ??
          json['maxAppointmentsPerDay'] ??
          50,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (id != null) data['id'] = id;
    data['service_name'] = serviceName;
    if (serviceDescription != null) data['service_description'] = serviceDescription;
    data['service_type'] = serviceType;
    if (isEnabled != null) data['is_enabled'] = isEnabled;
    if (requiredFields != null) data['required_fields'] = requiredFields;
    if (availableDays != null) data['available_days'] = availableDays;
    if (maxAppointmentsPerDay != null) data['max_appointments_per_day'] = maxAppointmentsPerDay;
    return data;
  }
}