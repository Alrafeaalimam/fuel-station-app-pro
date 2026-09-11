import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/cash_box_repository.dart';
import 'cash_box_event.dart';
import 'cash_box_state.dart';
import '../../utils/permission_guard.dart';

class CashBoxBloc extends Bloc<CashBoxEvent, CashBoxState> {
  final CashBoxRepository cashBoxRepository;

  CashBoxBloc({required this.cashBoxRepository}) : super(CashBoxInitial()) {
    on<LoadCashBox>(_onLoadCashBox);
    on<UpdateCashBoxManualRequested>(_onUpdateCashBoxManualRequested);
  }

  Future<void> _onLoadCashBox(
    LoadCashBox event,
    Emitter<CashBoxState> emit,
  ) async {
    emit(CashBoxLoading());
    try {
      final today = await cashBoxRepository.getOrCreateTodayCashBox();
      final history = await cashBoxRepository.getCashBoxHistory();
      emit(CashBoxLoaded(todayBox: today, history: history));
    } catch (e) {
      emit(CashBoxError('خطأ في تحميل بيانات الخزنة: $e'));
    }
  }

  Future<void> _onUpdateCashBoxManualRequested(
    UpdateCashBoxManualRequested event,
    Emitter<CashBoxState> emit,
  ) async {
    try {
      await cashBoxRepository.updateTodayCashBox(
        cashInDelta: event.cashInDelta,
        cashOutDelta: event.cashOutDelta,
        notes: event.notes,
        user: event.user,
      );
      emit(const CashBoxActionSuccess('تم تحديث حركة الخزنة بنجاح'));
      add(LoadCashBox());
    } catch (e) {
      final msg = e is UnauthorizedException ? e.message : 'خطأ أثناء تحديث الخزنة: $e';
      emit(CashBoxError(msg));
    }
  }
}
