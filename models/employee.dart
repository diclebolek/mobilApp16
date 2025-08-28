class Employee {
  final int? id;
  final String firstName;
  final String lastName;
  final String expertise;
  final String skills;
  final double? prolificacy;
  final int? dailyEarnings;
  final int? serviceId;
  final String? email;
  final String? phone;
  final bool? isActive;
  final DateTime? hireDate;
  final String? profileImage;

  Employee({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.expertise,
    required this.skills,
    this.prolificacy,
    this.dailyEarnings,
    this.serviceId,
    this.email,
    this.phone,
    this.isActive,
    this.hireDate,
    this.profileImage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'expertise': expertise,
      'skills': skills,
      'prolificacy': prolificacy,
      'dailyEarnings': dailyEarnings,
      'serviceId': serviceId,
      'email': email,
      'phone': phone,
      'isActive': isActive,
      'hireDate': hireDate?.toIso8601String(),
      'profileImage': profileImage,
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()),
      firstName: json['ad'] ?? '',
      lastName: json['soyad'] ?? '',
      expertise: json['uzmanlik'] ?? 'Genel',
      skills: json['beceriler'] ?? '',
      prolificacy: json['prolificacy']?.toDouble(),
      dailyEarnings: json['daily_earnings'] is int
          ? json['daily_earnings']
          : int.tryParse(json['daily_earnings']?.toString() ?? '0'),
      serviceId: json['service_id'] is int
          ? json['service_id']
          : int.tryParse(json['service_id']?.toString() ?? '0'),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isActive: json['aktif'] as bool? ?? true,
      hireDate: json['ise_baslama_tarihi'] != null
          ? DateTime.tryParse(json['ise_baslama_tarihi'].toString())
          : null,
      profileImage: json['profil_resmi'] as String?,
    );
  }

  String get fullName => '$firstName $lastName';
}
