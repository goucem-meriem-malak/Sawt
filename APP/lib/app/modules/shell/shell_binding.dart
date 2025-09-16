import 'package:get/get.dart';
import 'shell_view.dart';
import '../matches/matches_controller.dart';
import '../messages/messages_controller.dart';
import '../profile/profile_controller.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShellController>(() => ShellController());
    Get.lazyPut<MatchesController>(() => MatchesController());
    Get.lazyPut<MessagesController>(() => MessagesController());
    Get.lazyPut<ProfileController>(() => ProfileController());
  }
}
