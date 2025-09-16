import 'package:get/get.dart';
import 'package:sawt/app/modules/report_missing_fixed.dart';
import '../routes/app_routes.dart';
import '../modules/shell/shell_binding.dart';
import '../modules/shell/shell_view.dart';
import '../modules/home/home_binding.dart';
import '../modules/home/home_view.dart';
import '../modules/auth/auth_binding.dart';
import '../modules/auth/auth_view.dart';
import '../modules/report_found_fixed.dart';
import '../modules/matches/matches_binding.dart';
import '../modules/matches/matches_view.dart';
import '../modules/messages/messages_binding.dart';
import '../modules/messages/messages_view.dart';
import '../modules/profile/profile_binding.dart';
import '../modules/profile/profile_view.dart';
import '../modules/no_match/no_match_found_view.dart';

class AppPages {
  static final List<GetPage> pages = [
    GetPage(
      name: AppRoutes.REPORT_MISSING,
      page: () => ReportMissingPage(),
    ),
    GetPage(
      name: AppRoutes.SHELL,
      page: () => ShellView(),
      binding: ShellBinding(),
    ),
    GetPage(
      name: AppRoutes.HOME,
      page: () => HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.REPORT_FOUND,
      page: () => ReportFoundPage(),
    ),
    GetPage(
      name: AppRoutes.MATCHES,
      page: () => MatchesView(),
      binding: MatchesBinding(),
    ),
    GetPage(
      name: AppRoutes.MESSAGES,
      page: () => MessagesView(),
      binding: MessagesBinding(),
    ),
    GetPage(
      name: AppRoutes.PROFILE,
      page: () => ProfileView(),
      binding: ProfileBinding(),
    ),
    GetPage(
        name: AppRoutes.NO_MATCH,
        page: () => const NoMatchFoundView()
    ),
    GetPage(
      name: AppRoutes.AUTH,
      page: () => const AuthView(),
      binding: AuthBinding(),
    ),

  ];
}
