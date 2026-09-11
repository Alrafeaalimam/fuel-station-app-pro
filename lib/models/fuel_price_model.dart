import 'package:equatable/equatable.dart';

class FuelPriceModel extends Equatable {
  final int? id;
  final String fuelType; // 'بنزين' | 'جازولين'
  final double pricePerLiter;
  final String effectiveFrom; // ISO 8601 string
  final String? effectiveTo; // ISO 8601 string or null if currently active
  final int? setByUserId;

  const FuelPriceModel({
    this.id,
    required this.fuelType,
    required this.pricePerLiter,
    required this.effectiveFrom,
    this.effectiveTo,
    this.setByUserId,
  });

  bool get isActive => effectiveTo == null;

  FuelPriceModel copyWith({
    int? id,
    String? fuelType,
    double? pricePerLiter,
    String? effectiveFrom,
    String? effectiveTo,
    int? setByUserId,
  }) {
    return FuelPriceModel(
      id: id ?? this.id,
      fuelType: fuelType ?? this.fuelType,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      setByUserId: setByUserId ?? this.setByUserId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'fuel_type': fuelType,
      'price_per_liter': pricePerLiter,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
      'set_by_user_id': setByUserId,
    };
  }

  factory FuelPriceModel.fromMap(Map<String, dynamic> map) {
    return FuelPriceModel(
      id: map['id'] as int?,
      fuelType: map['fuel_type'] as String? ?? 'بنزين',
      pricePerLiter: (map['price_per_liter'] as num?)?.toDouble() ?? 0.0,
      effectiveFrom: map['effective_from'] as String? ?? DateTime.now().toIso8601String(),
      effectiveTo: map['effective_to'] as String?,
      setByUserId: map['set_by_user_id'] as int?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fuelType,
        pricePerLiter,
        effectiveFrom,
        effectiveTo,
        setByUserId,
      ];
}
