import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class DeliveryState extends Equatable {
  const DeliveryState();

  @override
  List<Object?> get props => [];
}

class DeliveryInitial extends DeliveryState {}

class DeliveryLoading extends DeliveryState {}

class DeliveryLoaded extends DeliveryState {
  final List<DeliveryModel> deliveries;
  final List<SupplierModel> suppliers;
  final List<TankModel> tanks;

  const DeliveryLoaded({
    required this.deliveries,
    required this.suppliers,
    required this.tanks,
  });

  @override
  List<Object?> get props => [deliveries, suppliers, tanks];
}

class DeliveryActionSuccess extends DeliveryState {
  final String message;

  const DeliveryActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class DeliveryError extends DeliveryState {
  final String message;

  const DeliveryError(this.message);

  @override
  List<Object?> get props => [message];
}
