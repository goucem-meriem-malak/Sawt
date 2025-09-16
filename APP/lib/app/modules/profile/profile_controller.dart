import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get/get.dart';
import 'package:sawt/app/modules/profile/help_feedback_view.dart' show HelpFeedbackView;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reports_pages.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';


class ProfileController extends GetxController {
  final SupabaseClient _sp = Supabase.instance.client;

  final userName  = ''.obs;
  final userEmail = ''.obs;

  final avatarSignedUrl = ''.obs;
  String _avatarUrl = '';

  final missingReports = 0.obs;
  final foundReports   = 0.obs;
  final totalMatches   = 0.obs;
  final reunited       = 0.obs;

  final isLoading = false.obs;

  final _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    loadUserProfile();
    _loadSettings();
  }

  Future<void> loadUserProfile() async {
    try {
      isLoading.value = true;

      final user = _sp.auth.currentUser;
      if (user == null) {
        Get.snackbar('Alert', 'No user is signed in.');
        return;
      }
      final uid = user.id;

      final prof = await _sp
          .from('profiles')
          .select('full_name,email,avatar_url')
          .eq('id', uid)
          .maybeSingle();

      final fallbackName =
      (user.userMetadata?['full_name'] ?? _nameFromEmail(user.email)).toString();

      userName.value   = (prof?['full_name'] ?? fallbackName).toString();
      userEmail.value  = (prof?['email'] ?? user.email ?? '').toString();
      _avatarUrl       = (prof?['avatar_url'] ?? '').toString();
      _refreshAvatarUrl();

      await _sp.from('profiles').upsert({
        'id'        : uid,
        'full_name' : userName.value,
        'email'     : userEmail.value,
        'avatar_url': _avatarUrl.isEmpty ? null : _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      final miss = await _sp.from('missing_persons').select('id').eq('user_id', uid);
      missingReports.value = (miss as List).length;

      final found = await _sp.from('found_persons').select('id').eq('user_id', uid);
      foundReports.value = (found as List).length;

      final matches = await _sp
          .from('matches')
          .select('id,status')
          .or('missing_user_id.eq.$uid,found_user_id.eq.$uid');
      final mList = matches as List;
      totalMatches.value = mList.length;
      reunited.value = mList.where((m) => (m['status'] ?? '').toString() == 'confirmed').length;

      await _sp.from('profiles').update({
        'missing_reports': missingReports.value,
        'found_reports'  : foundReports.value,
        'total_matches'  : totalMatches.value,
        'reunited'       : reunited.value,
        'updated_at'     : DateTime.now().toIso8601String(),
      }).eq('id', uid);

    } on PostgrestException catch (e) {
      Get.snackbar('DB Error', e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load profile: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  String _nameFromEmail(String? email) =>
      (email == null || !email.contains('@')) ? 'User' : email.split('@').first;

  void _refreshAvatarUrl() {
    if (_avatarUrl.isEmpty) {
      avatarSignedUrl.value = '';
    } else {
      avatarSignedUrl.value =
      '$_avatarUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> showEditProfileDialog() async {
    final nameCtrl  = TextEditingController(text: userName.value);
    final emailCtrl = TextEditingController(text: userEmail.value);
    File? picked;

    await Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit Profile'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final x = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024, imageQuality: 85,
                      );
                      if (x != null) setState(() => picked = File(x.path));
                    },
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: picked != null ? FileImage(picked!) : null,
                      child: picked == null
                          ? const Icon(Icons.camera_alt, size: 26, color: Colors.black54)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email),
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
              Obx(() => ElevatedButton(
                onPressed: isLoading.value
                    ? null
                    : () async {
                  await updateFullNameEmailAndAvatar(
                    fullName: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    avatarFile: picked,
                  );
                },
                child: isLoading.value
                    ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save'),
              )),
            ],
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  Future<void> updateFullNameEmailAndAvatar({
    required String fullName,
    required String email,
    File? avatarFile,
  }) async {
    final user = _sp.auth.currentUser;
    if (user == null) return;

    try {
      isLoading.value = true;

      if (avatarFile != null) {
        final ext  = p.extension(avatarFile.path).replaceFirst('.', '');
        final path = '${user.id}/avatar.${ext.isEmpty ? 'jpg' : ext}';

        await _sp.storage.from('avatars').upload(
          path,
          avatarFile,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/*'),
        );

        _avatarUrl = _sp.storage.from('avatars').getPublicUrl(path);
      }

      await _sp.from('profiles').update({
        'full_name' : fullName,
        'email'     : email,
        if (_avatarUrl.isNotEmpty) 'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      final meta = <String, dynamic>{'full_name': fullName};
      if (_avatarUrl.isNotEmpty) meta['avatar_url'] = _avatarUrl;

      await _sp.auth.updateUser(
        UserAttributes(
          email: (email.isNotEmpty && email != user.email) ? email : null,
          data : meta,
        ),
      );

      userName.value  = fullName;
      userEmail.value = email;
      _refreshAvatarUrl();

      Get.back();
      Get.snackbar('Saved', 'Profile updated successfully',
          snackPosition: SnackPosition.BOTTOM);
    } on StorageException catch (e) {
      Get.snackbar('Error', 'Failed to upload image: ${e.message}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red, colorText: Colors.white);
    } on PostgrestException catch (e) {
      Get.snackbar('DB Error', e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> uploadAvatarOnly(File avatarFile) async {
    final sp = Supabase.instance.client;
    final user = sp.auth.currentUser;
    if (user == null) return null;

    const bucket = 'avatars';
    final objectName = 'users/${user.id}/avatar.jpg';

    await sp.storage.from(bucket).upload(
      objectName,
      avatarFile,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );

    return sp.storage.from(bucket).getPublicUrl(objectName);
  }

  void viewMissingReports() {
    Get.to(() => const MissingReportsPage());
  }

  void viewFoundReports() {
    Get.to(() => const FoundReportsPage());
  }

  void viewHistory() {
    Get.to(() => const ReportHistoryPage());
  }

  final notifyMessages      = true.obs;
  final notifyMatches       = true.obs;
  final notifyAnnouncements = false.obs;

  final privacyPublicProfile = false.obs;
  final privacyShareContact  = false.obs;

  Future<Box> _getSettingsBox() async {
    if (!Hive.isBoxOpen('user_settings')) {
      await Hive.openBox('user_settings');
    }
    return Hive.box('user_settings');
  }

  Future<void> _loadSettings() async {
    final b = await _getSettingsBox();
    notifyMessages.value      = b.get('notify_messages',       defaultValue: true);
    notifyMatches.value       = b.get('notify_matches',        defaultValue: true);
    notifyAnnouncements.value = b.get('notify_announcements',  defaultValue: false);

    privacyPublicProfile.value = b.get('privacy_public_profile', defaultValue: false);
    privacyShareContact.value  = b.get('privacy_share_contact',  defaultValue: false);
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final b = await _getSettingsBox();
    await b.put(key, value);
  }


  void openNotificationSettings() {
    Get.bottomSheet(
      Obx(() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Get.theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notification Settings',
              style: Get.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              title: const Text('New message notifications'),
              value: notifyMessages.value,
              onChanged: (v) { notifyMessages.value = v; _saveSetting('notify_messages', v); },
            ),
            SwitchListTile.adaptive(
              title: const Text('New match notifications'),
              value: notifyMatches.value,
              onChanged: (v) { notifyMatches.value = v; _saveSetting('notify_matches', v); },
            ),
            SwitchListTile.adaptive(
              title: const Text('App announcements & updates'),
              value: notifyAnnouncements.value,
              onChanged: (v) { notifyAnnouncements.value = v; _saveSetting('notify_announcements', v); },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      )),
      isScrollControlled: true,
      ignoreSafeArea: false,
      backgroundColor: Colors.transparent,
    );
  }

  void openPrivacySettings() {
    Get.bottomSheet(
      Obx(() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Get.theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Privacy & Security',
              style: Get.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              title: const Text('Show my reports publicly (without contact info)'),
              value: privacyPublicProfile.value,
              onChanged: (v) { privacyPublicProfile.value = v; _saveSetting('privacy_public_profile', v); },
            ),
            SwitchListTile.adaptive(
              title: const Text('Allow others to contact me after a match'),
              value: privacyShareContact.value,
              onChanged: (v) { privacyShareContact.value = v; _saveSetting('privacy_share_contact', v); },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                child: const Text('Save & Close'),
              ),
            ),
          ],
        ),
      )),
      isScrollControlled: true,
      ignoreSafeArea: false,
      backgroundColor: Colors.transparent,
    );
  }

  void openHelp() {
    Get.to(() => const HelpFeedbackView());
  }

  void openAbout() {
    Get.dialog(
      AlertDialog(
        title: const Text('About SAWT'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('SAWT - Family Reconnection App', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 16),
            Text('SAWT helps reconnect families and locate missing persons during wartime or crisis situations using advanced face recognition technology.'),
            SizedBox(height: 16),
            Text('Our mission is to bring hope and reunite families when they need it most.', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [ TextButton(onPressed: () => Get.back(), child: const Text('Close')) ],
      ),
    );
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      await Supabase.instance.client.auth.signOut();

      const boxes = ['user_profile_box','reports','missing_local','found_local'];
      for (final name in boxes) {
        if (Hive.isBoxOpen(name)) await Hive.box(name).clear();
      }
      Get.offAllNamed('/auth');
    } finally {
      isLoading.value = false;
    }
  }
}
