// Gerekli paketleri import ediyoruz.

// Randevular için veri modeli (Appointment)
class Appointment {
  final int? appointmentId;
  final String customerName;
  final String employeeName;
  final String serviceName;
  final String process;
  final double totalPrice;
  final DateTime appointmentDateTime;
  String approvalStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final String? customerPhone;
  final String? customerEmail;

  Appointment({
    this.appointmentId,
    required this.customerName,
    required this.employeeName,
    required this.serviceName,
    required this.process,
    required this.totalPrice,
    required this.appointmentDateTime,
    required this.approvalStatus,
    this.createdAt,
    this.updatedAt,
    this.notes,
    this.customerPhone,
    this.customerEmail,
  });

  Map<String, dynamic> toJson() {
    return {
      'appointmentId': appointmentId,
      'customerName': customerName,
      'employeeName': employeeName,
      'serviceName': serviceName,
      'process': process,
      'totalPrice': totalPrice,
      'appointmentDateTime': appointmentDateTime.toIso8601String(),
      'approvalStatus': approvalStatus,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notes': notes,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      appointmentId: json['appointmentId'],
      customerName: json['customerName'],
      employeeName: json['employeeName'],
      serviceName: json['serviceName'],
      process: json['process'],
      totalPrice: (json['totalPrice'] as num).toDouble(),
      appointmentDateTime: DateTime.parse(json['appointmentDateTime']),
      approvalStatus: json['approvalStatus'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      notes: json['notes'],
      customerPhone: json['customerPhone'],
      customerEmail: json['customerEmail'],
    );
  }

  Appointment copyWith({
    int? appointmentId,
    String? customerName,
    String? employeeName,
    String? serviceName,
    String? process,
    double? totalPrice,
    DateTime? appointmentDateTime,
    String? approvalStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? customerPhone,
    String? customerEmail,
  }) {
    return Appointment(
      appointmentId: appointmentId ?? this.appointmentId,
      customerName: customerName ?? this.customerName,
      employeeName: employeeName ?? this.employeeName,
      serviceName: serviceName ?? this.serviceName,
      process: process ?? this.process,
      totalPrice: totalPrice ?? this.totalPrice,
      appointmentDateTime: appointmentDateTime ?? this.appointmentDateTime,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
    );
  }
}
