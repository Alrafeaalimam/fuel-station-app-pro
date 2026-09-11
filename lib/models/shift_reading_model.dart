import 'package:equatable/equatable.dart';

class ShiftReadingModel extends Equatable {
  final int? id;
  final int shiftId;
  final int pumpId;
  final double previousMeter;
  final double currentMeter;
  final double litersSold;
  final double previousDip;
  final double currentDip;
  final double deliveredLitersDuringShift;
  final double surplusDeficit;
  final double pricePerLiter;
  final double totalAmount;

  const ShiftReadingModel({
    this.id,
    required this.shiftId,
    required this.pumpId,
    required this.previousMeter,
    required this.currentMeter,
    required this.litersSold,
    required this.previousDip,
    required this.currentDip,
    this.deliveredLitersDuringShift = 0.0,
    required this.surplusDeficit,
    required this.pricePerLiter,
    required this.totalAmount,
  });

  ShiftReadingModel copyWith({
    int? id,
    int? shiftId,
    int? pumpId,
    double? previousMeter,
    double? currentMeter,
    double? litersSold,
    double? previousDip,
    double? currentDip,
    double? deliveredLitersDuringShift,
    double? surplusDeficit,
    double? pricePerLiter,
    double? totalAmount,
  }) {
    return ShiftReadingModel(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      pumpId: pumpId ?? this.pumpId,
      previousMeter: previousMeter ?? this.previousMeter,
      currentMeter: currentMeter ?? this.currentMeter,
      litersSold: litersSold ?? this.litersSold,
      previousDip: previousDip ?? this.previousDip,
      currentDip: currentDip ?? this.currentDip,
      deliveredLitersDuringShift:
          deliveredLitersDuringShift ?? this.deliveredLitersDuringShift,
      surplusDeficit: surplusDeficit ?? this.surplusDeficit,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'shift_id': shiftId,
      'pump_id': pumpId,
      'previous_meter': previousMeter,
      'current_meter': currentMeter,
      'liters_sold': litersSold,
      'previous_dip': previousDip,
      'current_dip': currentDip,
      'delivered_liters_during_shift': deliveredLitersDuringShift,
      'surplus_deficit': surplusDeficit,
      'price_per_liter': pricePerLiter,
      'total_amount': totalAmount,
    };
  }

  factory ShiftReadingModel.fromMap(Map<String, dynamic> map) {
    return ShiftReadingModel(
      id: map['id'] as int?,
      shiftId: map['shift_id'] as int? ?? 0,
      pumpId: map['pump_id'] as int? ?? 0,
      previousMeter: (map['previous_meter'] as num?)?.toDouble() ?? 0.0,
      currentMeter: (map['current_meter'] as num?)?.toDouble() ?? 0.0,
      litersSold: (map['liters_sold'] as num?)?.toDouble() ?? 0.0,
      previousDip: (map['previous_dip'] as num?)?.toDouble() ?? 0.0,
      currentDip: (map['current_dip'] as num?)?.toDouble() ?? 0.0,
      deliveredLitersDuringShift:
          (map['delivered_liters_during_shift'] as num?)?.toDouble() ?? 0.0,
      surplusDeficit: (map['surplus_deficit'] as num?)?.toDouble() ?? 0.0,
      pricePerLiter: (map['price_per_liter'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        shiftId,
        pumpId,
        previousMeter,
        currentMeter,
        litersSold,
        previousDip,
        currentDip,
        deliveredLitersDuringShift,
        surplusDeficit,
        pricePerLiter,
        totalAmount,
      ];
}
