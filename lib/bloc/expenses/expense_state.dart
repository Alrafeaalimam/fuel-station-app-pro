import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class ExpenseState extends Equatable {
  const ExpenseState();

  @override
  List<Object?> get props => [];
}

class ExpenseInitial extends ExpenseState {}

class ExpenseLoading extends ExpenseState {}

class ExpenseLoaded extends ExpenseState {
  final List<ExpenseModel> expenses;
  final double totalExpenses;
  final Map<String, double> categorySummary;

  const ExpenseLoaded({
    required this.expenses,
    required this.totalExpenses,
    required this.categorySummary,
  });

  @override
  List<Object?> get props => [expenses, totalExpenses, categorySummary];
}

class ExpenseActionSuccess extends ExpenseState {
  final String message;

  const ExpenseActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ExpenseError extends ExpenseState {
  final String message;

  const ExpenseError(this.message);

  @override
  List<Object?> get props => [message];
}
