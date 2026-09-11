import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/expense_repository.dart';
import 'expense_event.dart';
import 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseRepository expenseRepository;

  ExpenseBloc({required this.expenseRepository}) : super(ExpenseInitial()) {
    on<LoadExpenses>(_onLoadExpenses);
    on<AddExpenseRequested>(_onAddExpenseRequested);
  }

  Future<void> _onLoadExpenses(
    LoadExpenses event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(ExpenseLoading());
    try {
      final expenses = await expenseRepository.getExpenses(date: event.date);
      final categorySummary = await expenseRepository.getExpensesByCategory();
      double total = 0.0;
      for (final e in expenses) {
        total += e.amount;
      }
      emit(ExpenseLoaded(
        expenses: expenses,
        totalExpenses: total,
        categorySummary: categorySummary,
      ));
    } catch (e) {
      emit(ExpenseError('خطأ في تحميل المصروفات: $e'));
    }
  }

  Future<void> _onAddExpenseRequested(
    AddExpenseRequested event,
    Emitter<ExpenseState> emit,
  ) async {
    try {
      await expenseRepository.addExpense(event.expense);
      emit(const ExpenseActionSuccess('تم تسجيل المصروف وخصمه من الخزنة بنجاح'));
      add(LoadExpenses());
    } catch (e) {
      emit(ExpenseError('خطأ أثناء إضافة المصروف: $e'));
    }
  }
}
