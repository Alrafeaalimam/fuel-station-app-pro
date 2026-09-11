import 'package:equatable/equatable.dart';

class DeliveryModel extends Equatable {
  final int? id;
  final int supplierId;
  final int tankId;
  final double liters;
  final double costPerLiter;
  final double totalCost;
  final String deliveredAt;
  final int recordedByUserId;

  const DeliveryModel({
    this.id,
    required this.supplierId,
    required this.tankId,
    required this.liters,
    required this.costPerLiter,
    required this.totalCost,
    required this.deliveredAt,
    required this.recordedByUserId,
  });

  DeliveryModel copyWith({
    int? id,
    int? supplierId,
    int? tankId,
    double? liters,
    double? costPerLiter,
    double? totalCost,
    String? deliveredAt,
    int? recordedByUserId,
  }) {
    return DeliveryModel(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      tankId: tankId ?? this.tankId,
      liters: liters ?? this.liters,
      costPerLiter: costPerLiter ?? this.costPerLiter,
      totalCost: totalCost ?? this.totalCost,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      recordedByUserId: recordedByUserId ?? this.recordedByUserId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'supplier_id': supplierId,
      'tank_id': tankId,
      'liters': liters,
      'cost_per_liter': costPerLiter,
      'total_cost': totalCost,
      'delivered_at': deliveredAt,
      'recorded_by_user_id': recordedByUserId,
    };
  }

  factory DeliveryModel.fromMap(Map<String, dynamic> map) {
    return DeliveryModel(
      id: map['id'] as int?,
      supplierId: map['supplier_id'] as int? ?? 0,
      tankId: map['tank_id'] as int? ?? 0,
      liters: (map['liters'] as num?)?.toDouble() ?? 0.0,
      costPerLiter: (map['cost_per_liter'] as num?)?.toDouble() ?? 0.0,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      deliveredAt: map['delivered_at'] as String? ?? DateTime.now().toIso8601String(),
      recordedByUserId: map['recorded_by_user_id'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [
        id,
        supplierId,
        tankId,
        liters,
        costPerLiter,
        totalCost,
        deliveredAt,
        recordedByUserId,
      ];
}
