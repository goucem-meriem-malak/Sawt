import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import 'profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    controller.showEditProfileDialog();
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Obx(() {
                          final url = controller.avatarSignedUrl.value;
                          return GestureDetector(
                            onTap: () {
                              if (url.isEmpty) {
                                Get.snackbar('No Image',
                                    'Set a profile photo first.',
                                    snackPosition: SnackPosition.BOTTOM);
                                return;
                              }
                              Get.to(() => AvatarViewer(url: url),
                                  transition: Transition.fadeIn);
                            },
                            child: Hero(
                              tag: 'avatar-hero',
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.6),
                                backgroundImage:
                                url.isNotEmpty ? NetworkImage(url) : null,
                                child: url.isNotEmpty
                                    ? null
                                    : const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        Obx(
                              () => Text(
                            controller.userName.value,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Obx(
                              () => Text(
                            controller.userEmail.value,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Statistics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                              () => _buildStatCard(
                            context,
                            'Missing Reports',
                            controller.missingReports.value.toString(),
                            Icons.person_search,
                            AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Obx(
                              () => _buildStatCard(
                            context,
                            'Found Reports',
                            controller.foundReports.value.toString(),
                            Icons.person_pin_circle,
                            AppTheme.secondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                              () => _buildStatCard(
                            context,
                            'Successful Matches',
                            controller.reunited.value.toString(),
                            Icons.check_circle,
                            AppTheme.secondaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Obx(
                              () => _buildStatCard(
                            context,
                            'Active Cases',
                            (controller.missingReports.value +
                                controller.foundReports.value -
                                controller.reunited.value)
                                .toString(),
                            Icons.pending,
                            AppTheme.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildActionTile(
                    context,
                    'View Missing Reports',
                    'See all your missing person reports',
                    Icons.person_search,
                    controller.viewMissingReports,
                  ),
                  _buildActionTile(
                    context,
                    'View Found Reports',
                    'See all your found person reports',
                    Icons.person_pin_circle,
                    controller.viewFoundReports,
                  ),
                  _buildActionTile(
                    context,
                    'Report History',
                    'View your complete reporting history',
                    Icons.history,
                    controller.viewHistory,
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildActionTile(
                    context,
                    'Notifications',
                    'Manage your notification preferences',
                    Icons.notifications_outlined,
                    controller.openNotificationSettings,
                  ),
                  _buildActionTile(
                    context,
                    'Privacy & Security',
                    'Control your privacy settings',
                    Icons.privacy_tip_outlined,
                    controller.openPrivacySettings,
                  ),
                  _buildActionTile(
                    context,
                    'Help & Feedback',
                    'Ask support or share feedback',
                    Icons.help_outline,
                    controller.openHelp,
                  ),
                  _buildActionTile(
                    context,
                    'About',
                    'App information and version',
                    Icons.info_outline,
                    controller.openAbout,
                  ),

                  const SizedBox(height: 32),

                  Center(
                    child: OutlinedButton.icon(
                      onPressed: controller.logout,
                      icon: const Icon(Icons.logout, color: AppTheme.dangerColor),
                      label: const Text(
                        'Logout',
                        style: TextStyle(color: AppTheme.dangerColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.dangerColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context,
      String title,
      String count,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
      BuildContext context,
      String title,
      String subtitle,
      IconData icon,
      VoidCallback onTap,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.textSecondary),
        ),
        trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

class AvatarViewer extends StatelessWidget {
  final String url;
  const AvatarViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile photo'),
      ),
      body: Center(
        child: Hero(
          tag: 'avatar-hero',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.white70,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
