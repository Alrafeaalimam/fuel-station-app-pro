import 'package:equatable/equatable.dart';

abstract class FuelPriceEvent extends Equatable {
  const FuelPriceEvent();

  @override
  List<Object?> get props => [];
}

class LoadFuelPrices extends FuelPriceEvent {}

class UpdateFuelPriceRequested extends FuelPriceEvent {
  final String fuelType;
  final double newPrice;
  final int? userId;

  const UpdateFuelPriceRequested({
    required this.fuelType,
    required this.newPrice,
    this.userId,
  });

  @override
  List<Object?> get props => [fuelType, newPrice, userId];
}
