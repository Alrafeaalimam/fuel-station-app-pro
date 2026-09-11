import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => [];
}

class LoadCustomers extends CustomerEvent {}

class AddCustomerRequested extends CustomerEvent {
  final CustomerModel customer;
  final UserModel? user;

  const AddCustomerRequested(this.customer, {this.user});

  @override
  List<Object?> get props => [customer, user];
}

class UpdateCustomerRequested extends CustomerEvent {
  final CustomerModel customer;
  final UserModel? user;

  const UpdateCustomerRequested(this.customer, {this.user});

  @override
  List<Object?> get props => [customer, user];
}

class RecordCustomerPaymentRequested extends CustomerEvent {
  final int customerId;
  final double amount;
  final String? notes;

  const RecordCustomerPaymentRequested({
    required this.customerId,
    required this.amount,
    this.notes,
  });

  @override
  List<Object?> get props => [customerId, amount, notes];
}

class LoadCustomerStatementRequested extends CustomerEvent {
  final int customerId;
  final String? fromDate;
  final String? toDate;

  const LoadCustomerStatementRequested({
    required this.customerId,
    this.fromDate,
    this.toDate,
  });

  @override
  List<Object?> get props => [customerId, fromDate, toDate];
}
