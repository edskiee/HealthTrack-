class User {
  final int? id;
  final String username;
  final String email;
  final String password;
  final String fullName;
  final String? phone;
  final String? dateOfBirth;
  final String? gender;
  final String? address;
  final String? emergencyContact;
  final String? bloodType;
  final String? allergies;
  final String? createdAt;
  final String? updatedAt;

  User({
    this.id,
    required this.username,
    required this.email,
    required this.password,
    required this.fullName,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.emergencyContact,
    this.bloodType,
    this.allergies,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'full_name': fullName,
      'phone': phone,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'address': address,
      'emergency_contact': emergencyContact,
      'blood_type': bloodType,
      'allergies': allergies,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      password: map['password'],
      fullName: map['full_name'],
      phone: map['phone'],
      dateOfBirth: map['date_of_birth'],
      gender: map['gender'],
      address: map['address'],
      emergencyContact: map['emergency_contact'],
      bloodType: map['blood_type'],
      allergies: map['allergies'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? password,
    String? fullName,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? address,
    String? emergencyContact,
    String? bloodType,
    String? allergies,
    String? createdAt,
    String? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}