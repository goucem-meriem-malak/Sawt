import 'package:get/get.dart';
import 'all_reports_controller.dart';

class AllReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AllReportsController());
  }
}
