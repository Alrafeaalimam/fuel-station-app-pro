import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();

  @override
  List<Object?> get props => [];
}

class LoadExpenses extends ExpenseEvent {
  final String? date;

  const LoadExpenses({this.date});

  @override
  List<Object?> get props => [date];
}

class AddExpenseRequested extends ExpenseEvent {
  final ExpenseModel expense;

  const AddExpenseRequested(this.expense);

  @override
  List<Object?> get props => [expense];
}
