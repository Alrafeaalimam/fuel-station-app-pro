import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class FuelPriceState extends Equatable {
  const FuelPriceState();

  @override
  List<Object?> get props => [];
}

class FuelPriceInitial extends FuelPriceState {}

class FuelPriceLoading extends FuelPriceState {}

class FuelPriceLoaded extends FuelPriceState {
  final Map<String, FuelPriceModel> activePrices;
  final List<FuelPriceModel> priceHistory;

  const FuelPriceLoaded({
    required this.activePrices,
    required this.priceHistory,
  });

  @override
  List<Object?> get props => [activePrices, priceHistory];
}

class FuelPriceError extends FuelPriceState {
  final String message;

  const FuelPriceError(this.message);

  @override
  List<Object?> get props => [message];
}

class FuelPriceUpdateSuccess extends FuelPriceState {
  final String message;

  const FuelPriceUpdateSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
