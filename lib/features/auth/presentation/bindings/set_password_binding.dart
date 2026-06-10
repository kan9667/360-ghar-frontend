// lib/features/auth/presentation/bindings/set_password_binding.dart

import 'package:get/get.dart';

import 'package:ghar360/features/auth/presentation/controllers/set_password_controller.dart';

class SetPasswordBinding extends Bindings {
  @override
  void dependencies() {
    // AuthController and AuthRepository are registered globally in InitialBinding.
    Get.lazyPut<SetPasswordController>(() => SetPasswordController());
  }
}
