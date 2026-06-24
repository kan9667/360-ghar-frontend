import 'package:get/get.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

class VisitsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<VisitsController>()) {
      Get.lazyPut<VisitsController>(() => VisitsController());
    }
  }
}
