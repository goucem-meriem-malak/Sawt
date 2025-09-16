import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../home/home_view.dart';
import '../matches/matches_view.dart';
import '../messages/messages_view.dart';
import '../profile/profile_view.dart';
import '../reports/all_reports_view.dart';
import '../reports/all_reports_binding.dart';
import '../reports/all_reports_controller.dart';

class ShellController extends GetxController {
  final selectedIndex = 0.obs;
  void changeTab(int i) => selectedIndex.value = i;
}

class ShellView extends StatelessWidget {
  ShellView({super.key}) {
    // سجل Bindings للـ Reports أول مرة
    if (!Get.isRegistered<AllReportsController>()) {
      AllReportsBinding().dependencies();
    }
  }

  final ShellController controller = Get.put(ShellController());

  // ⚠️ لا تجعلها const لتجنّب أخطاء "const list"
  final List<Widget> _pages = [
    HomeView(),
    MatchesView(),
    MessagesView(),
    AllReportsView(),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
            () => IndexedStack(
          index: controller.selectedIndex.value,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Obx(
            () => NavigationBar(
          selectedIndex: controller.selectedIndex.value,
          onDestinationSelected: controller.changeTab,
          // 👇 أيقونات فقط بدون أسماء
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          // height: 64, // اختياري
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.message_outlined),
              selectedIcon: Icon(Icons.message),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}
