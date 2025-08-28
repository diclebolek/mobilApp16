class Customer {
  final int? customerId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;
  final DateTime? birthDate;
  final String? gender;
  final DateTime createdAt;
  final bool isActive;

  Customer({
    this.customerId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone = '',
    this.address = '',
    this.birthDate,
    this.gender,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'address': address,
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerId: json['customerId'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      gender: json['gender'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'] ?? true,
    );
  }

  String get fullName => '$firstName $lastName';
}
