import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class CustomerState extends Equatable {
  const CustomerState();

  @override
  List<Object?> get props => [];
}

class CustomerInitial extends CustomerState {}

class CustomerLoading extends CustomerState {}

class CustomerLoaded extends CustomerState {
  final List<CustomerModel> customers;

  const CustomerLoaded(this.customers);

  @override
  List<Object?> get props => [customers];
}

class CustomerActionSuccess extends CustomerState {
  final String message;

  const CustomerActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CustomerStatementLoaded extends CustomerState {
  final CustomerModel customer;
  final List<CreditTransactionModel> transactions;
  final double totalCharges;
  final double totalPayments;

  const CustomerStatementLoaded({
    required this.customer,
    required this.transactions,
    required this.totalCharges,
    required this.totalPayments,
  });

  @override
  List<Object?> get props => [
        customer,
        transactions,
        totalCharges,
        totalPayments,
      ];
}

class CustomerError extends CustomerState {
  final String message;

  const CustomerError(this.message);

  @override
  List<Object?> get props => [message];
}
