import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/report_repository.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final ReportRepository reportRepository;

  ReportsBloc({required this.reportRepository}) : super(ReportsInitial()) {
    on<LoadFinancialSummaryReport>(_onLoadFinancialSummaryReport);
  }

  Future<void> _onLoadFinancialSummaryReport(
    LoadFinancialSummaryReport event,
    Emitter<ReportsState> emit,
  ) async {
    emit(ReportsLoading());
    try {
      final summary = await reportRepository.getFinancialSummary(
        fromDate: event.fromDate,
        toDate: event.toDate,
      );
      emit(ReportsSummaryLoaded(
        summary: summary,
        fromDate: event.fromDate,
        toDate: event.toDate,
      ));
    } catch (e) {
      emit(ReportsError('خطأ في إعداد التقرير المالي: $e'));
    }
  }
}
