class EmployeePerformance {
  final String employeeName;
  final double dailyEarnings;
  final double totalEarnings; // Tüm zamanlardan toplam kazanç
  final double efficiency;
  final DateTime date;
  final int appointmentsCompleted;
  final double averageRating;
  final int pendingAppointments; // Bekleyen randevu sayısı (bugün)

  EmployeePerformance({
    required this.employeeName,
    required this.dailyEarnings,
    required this.totalEarnings,
    required this.efficiency,
    required this.date,
    required this.appointmentsCompleted,
    required this.averageRating,
    this.pendingAppointments = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeName': employeeName,
      'dailyEarnings': dailyEarnings,
      'totalEarnings': totalEarnings,
      'efficiency': efficiency,
      'date': date.toIso8601String(),
      'appointmentsCompleted': appointmentsCompleted,
      'averageRating': averageRating,
      'pendingAppointments': pendingAppointments,
    };
  }

  factory EmployeePerformance.fromJson(Map<String, dynamic> json) {
    return EmployeePerformance(
      employeeName: json['employeeName'],
      dailyEarnings: (json['dailyEarnings'] as num).toDouble(),
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      efficiency: (json['efficiency'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      appointmentsCompleted: json['appointmentsCompleted'],
      averageRating: (json['averageRating'] as num).toDouble(),
      pendingAppointments: (json['pendingAppointments'] as num?)?.toInt() ?? 0,
    );
  }
}
