import 'package:equatable/equatable.dart';

class TankModel extends Equatable {
  final int? id;
  final String name;
  final String fuelType; // 'بنزين' | 'جازولين'
  final double capacityLiters;
  final double currentDipLiters;

  const TankModel({
    this.id,
    required this.name,
    required this.fuelType,
    required this.capacityLiters,
    required this.currentDipLiters,
  });

  bool get hasCapacity => capacityLiters > 0;

  double get fillPercentage => hasCapacity
      ? ((currentDipLiters / capacityLiters) * 100)
      : 0.0;

  TankModel copyWith({
    int? id,
    String? name,
    String? fuelType,
    double? capacityLiters,
    double? currentDipLiters,
  }) {
    return TankModel(
      id: id ?? this.id,
      name: name ?? this.name,
      fuelType: fuelType ?? this.fuelType,
      capacityLiters: capacityLiters ?? this.capacityLiters,
      currentDipLiters: currentDipLiters ?? this.currentDipLiters,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'fuel_type': fuelType,
      'capacity_liters': capacityLiters,
      'current_dip_liters': currentDipLiters,
    };
  }

  factory TankModel.fromMap(Map<String, dynamic> map) {
    return TankModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      fuelType: map['fuel_type'] as String? ?? 'بنزين',
      capacityLiters: (map['capacity_liters'] as num?)?.toDouble() ?? 0.0,
      currentDipLiters: (map['current_dip_liters'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [id, name, fuelType, capacityLiters, currentDipLiters];
}
