import 'package:equatable/equatable.dart';
import '../../data/repositories/report_repository.dart';

abstract class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsSummaryLoaded extends ReportsState {
  final FinancialSummary summary;
  final String? fromDate;
  final String? toDate;

  const ReportsSummaryLoaded({
    required this.summary,
    this.fromDate,
    this.toDate,
  });

  @override
  List<Object?> get props => [summary, fromDate, toDate];
}

class ReportsError extends ReportsState {
  final String message;

  const ReportsError(this.message);

  @override
  List<Object?> get props => [message];
}
