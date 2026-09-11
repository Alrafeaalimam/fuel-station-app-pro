import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/tank_repository.dart';
import '../../utils/permission_guard.dart';
import 'tank_event.dart';
import 'tank_state.dart';

class TankBloc extends Bloc<TankEvent, TankState> {
  final TankRepository tankRepository;

  TankBloc({required this.tankRepository}) : super(TankInitial()) {
    on<LoadTanksAndPumps>(_onLoadTanksAndPumps);
    on<UpdateTankDipManually>(_onUpdateTankDipManually);
    on<UpdateTankCapacityRequested>(_onUpdateTankCapacityRequested);
  }

  Future<void> _onLoadTanksAndPumps(
    LoadTanksAndPumps event,
    Emitter<TankState> emit,
  ) async {
    emit(TankLoading());
    try {
      final tanks = await tankRepository.getTanks();
      final pumps = await tankRepository.getPumps();
      emit(TankLoaded(tanks: tanks, pumps: pumps));
    } catch (e) {
      emit(TankError('خطأ في تحميل بيانات الخزانات: $e'));
    }
  }

  Future<void> _onUpdateTankDipManually(
    UpdateTankDipManually event,
    Emitter<TankState> emit,
  ) async {
    try {
      await tankRepository.updateTankDip(event.tankId, event.newDip);
      add(LoadTanksAndPumps());
    } catch (e) {
      emit(TankError('خطأ في تحديث المسطرة: $e'));
    }
  }

  Future<void> _onUpdateTankCapacityRequested(
    UpdateTankCapacityRequested event,
    Emitter<TankState> emit,
  ) async {
    try {
      await tankRepository.updateTankCapacity(
        event.tankId,
        event.capacityLiters,
        user: event.user,
      );
      emit(TankActionSuccess(
        'تم تحديد سعة الخزان بنجاح: ${event.capacityLiters.toStringAsFixed(0)} لتر',
      ));
      add(LoadTanksAndPumps());
    } catch (e) {
      final msg = e is UnauthorizedException
          ? e.message
          : 'خطأ في تحديث سعة الخزان: $e';
      emit(TankError(msg));
    }
  }
}
