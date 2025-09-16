import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController extends GetxController {
  final SupabaseClient _sp = Supabase.instance.client;

  final isLoading = false.obs;
  final isLoginTab = true.obs;
  final obscurePwd = true.obs;

  final emailCtrl = TextEditingController();
  final pwdCtrl   = TextEditingController();
  final nameCtrl  = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    if (_sp.auth.currentUser != null) {
      _goHome();
    }
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    pwdCtrl.dispose();
    nameCtrl.dispose();
    super.onClose();
  }

  void switchTab(bool loginTab) => isLoginTab.value = loginTab;

  Future<void> signIn() async {
    final email = emailCtrl.text.trim();
    final pwd   = pwdCtrl.text;

    if (!_validateEmail(email) || pwd.length < 6) {
      Get.snackbar("Alert", "Check the email and password (≥ 6 chars)");
      return;
    }

    try {
      isLoading.value = true;
      await _sp.auth.signInWithPassword(email: email, password: pwd);

      await _ensureProfileRow();

      _goHome();
    } on AuthException catch (e) {
      Get.snackbar("Sign-in failed", e.message);
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signUp() async {
    final email = emailCtrl.text.trim();
    final pwd   = pwdCtrl.text;
    final name  = nameCtrl.text.trim();

    if (!_validateEmail(email) || pwd.length < 6) {
      Get.snackbar("Alert", "Check the email and password (≥ 6 chars)");
      return;
    }

    try {
      isLoading.value = true;
      final res = await _sp.auth.signUp(
        email: email,
        password: pwd,
        data: {'full_name': name},
      );

      if (res.user != null) {
        await _ensureProfileRow(fullNameOverride: name);
      }

      Get.snackbar("Done", "Account created.");
      _goHome();
    } on AuthException catch (e) {
      Get.snackbar("Sign-up failed", e.message);
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _ensureProfileRow({String? fullNameOverride}) async {
    final user = _sp.auth.currentUser;
    if (user == null) return;

    final fullName = (fullNameOverride?.trim().isNotEmpty == true)
        ? fullNameOverride!.trim()
        : (user.userMetadata?['full_name'] ?? '').toString();

    final email = user.email ?? '';

    await _sp.from('profiles').upsert({
      'id': user.id,
      'full_name': fullName,
      'email': email,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'id');
  }

  void _goHome() => Get.offAllNamed('/');

  bool _validateEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}