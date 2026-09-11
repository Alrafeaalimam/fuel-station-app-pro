import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class DeliveryEvent extends Equatable {
  const DeliveryEvent();

  @override
  List<Object?> get props => [];
}

class LoadDeliveriesAndSuppliers extends DeliveryEvent {}

class AddSupplierRequested extends DeliveryEvent {
  final SupplierModel supplier;
  final UserModel? user;

  const AddSupplierRequested(this.supplier, {this.user});

  @override
  List<Object?> get props => [supplier, user];
}

class RecordDeliveryRequested extends DeliveryEvent {
  final DeliveryModel delivery;

  const RecordDeliveryRequested(this.delivery);

  @override
  List<Object?> get props => [delivery];
}
