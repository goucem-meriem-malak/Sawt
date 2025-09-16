import 'package:get/get.dart';
import 'matches_controller.dart';

class MatchesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MatchesController>(() => MatchesController());
  }
}
