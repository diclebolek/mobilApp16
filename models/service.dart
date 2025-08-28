class Service {
  final int? serviceId;
  final String serviceName;
  final int serviceDuration;
  final double servicePrice;
  final String description;
  final String imageUrl;
  final String category;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Service({
    this.serviceId,
    required this.serviceName,
    required this.serviceDuration,
    required this.servicePrice,
    required this.description,
    required this.imageUrl,
    required this.category,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'serviceId': serviceId,
      'serviceName': serviceName,
      'serviceDuration': serviceDuration,
      'servicePrice': servicePrice,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      serviceId: json['serviceId'],
      serviceName: json['serviceName'],
      serviceDuration: json['serviceDuration'],
      servicePrice: (json['servicePrice'] as num).toDouble(),
      description: json['description'],
      imageUrl: json['imageUrl'],
      category: json['category'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}
