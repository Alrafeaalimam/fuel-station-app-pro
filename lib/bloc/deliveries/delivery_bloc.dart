import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/repositories/tank_repository.dart';
import 'delivery_event.dart';
import 'delivery_state.dart';
import '../../utils/permission_guard.dart';

class DeliveryBloc extends Bloc<DeliveryEvent, DeliveryState> {
  final DeliveryRepository deliveryRepository;
  final TankRepository tankRepository;

  DeliveryBloc({
    required this.deliveryRepository,
    required this.tankRepository,
  }) : super(DeliveryInitial()) {
    on<LoadDeliveriesAndSuppliers>(_onLoadDeliveriesAndSuppliers);
    on<AddSupplierRequested>(_onAddSupplierRequested);
    on<RecordDeliveryRequested>(_onRecordDeliveryRequested);
  }

  Future<void> _onLoadDeliveriesAndSuppliers(
    LoadDeliveriesAndSuppliers event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(DeliveryLoading());
    try {
      final deliveries = await deliveryRepository.getDeliveries();
      final suppliers = await deliveryRepository.getSuppliers();
      final tanks = await tankRepository.getTanks();
      emit(DeliveryLoaded(
        deliveries: deliveries,
        suppliers: suppliers,
        tanks: tanks,
      ));
    } catch (e) {
      emit(DeliveryError('خطأ في تحميل بيانات التوريد: $e'));
    }
  }

  Future<void> _onAddSupplierRequested(
    AddSupplierRequested event,
    Emitter<DeliveryState> emit,
  ) async {
    try {
      await deliveryRepository.addSupplier(event.supplier, user: event.user);
      emit(const DeliveryActionSuccess('تمت إضافة المورد بنجاح'));
      add(LoadDeliveriesAndSuppliers());
    } catch (e) {
      final msg = e is UnauthorizedException ? e.message : 'خطأ أثناء إضافة المورد: $e';
      emit(DeliveryError(msg));
    }
  }

  Future<void> _onRecordDeliveryRequested(
    RecordDeliveryRequested event,
    Emitter<DeliveryState> emit,
  ) async {
    try {
      await deliveryRepository.recordDelivery(event.delivery);
      emit(const DeliveryActionSuccess('تم تسجيل الشحنة وتحديث منسوب الخزان بنجاح'));
      add(LoadDeliveriesAndSuppliers());
    } catch (e) {
      emit(DeliveryError('خطأ أثناء تسجيل الشحنة: $e'));
    }
  }
}
