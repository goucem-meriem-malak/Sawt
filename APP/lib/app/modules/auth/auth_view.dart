import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class AuthView extends GetView<AuthController> {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Obx(() {
                  final isLogin = controller.isLoginTab.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'SAWT',
                        textAlign: TextAlign.center,
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isLogin ? 'Welcome back' : 'Create a new account',
                        textAlign: TextAlign.center,
                        style: tt.titleLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Sign in'),
                                    icon: Icon(Icons.login),
                                  ),
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Create account'),
                                    icon: Icon(Icons.person_add_alt_1),
                                  ),
                                ],
                                selected: {controller.isLoginTab.value},
                                onSelectionChanged: (s) =>
                                    controller.switchTab(s.first),
                                style: ButtonStyle(
                                  side: WidgetStatePropertyAll(
                                    BorderSide(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: .2),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (!isLogin) ...[
                                Text('Full name', style: tt.labelLarge),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: controller.nameCtrl,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    hintText: '',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              Text('Email', style: tt.labelLarge),
                              const SizedBox(height: 6),
                              TextField(
                                controller: controller.emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: '',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                              ),
                              const SizedBox(height: 12),

                              Text('Password', style: tt.labelLarge),
                              const SizedBox(height: 6),
                              Obx(
                                    () => TextField(
                                  controller: controller.pwdCtrl,
                                  obscureText: controller.obscurePwd.value,
                                  decoration: InputDecoration(
                                    hintText: '',
                                    prefixIcon:
                                    const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          controller.obscurePwd.toggle(),
                                      icon: Icon(
                                        controller.obscurePwd.value
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Submit
                              Obx(
                                    () => ElevatedButton.icon(
                                  onPressed: controller.isLoading.value
                                      ? null
                                      : (isLogin
                                      ? controller.signIn
                                      : controller.signUp),
                                  icon: controller.isLoading.value
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : Icon(isLogin
                                      ? Icons.login
                                      : Icons.person_add_alt_1),
                                  label: Text(isLogin ? 'Sign in' : 'Sign up'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Center(
                        child: Obx(
                              () {
                            final isLogin = controller.isLoginTab.value;
                            return Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  isLogin
                                      ? "Don't have an account?"
                                      : "Already have an account?",
                                  style: tt.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      controller.switchTab(!isLogin),
                                  child: Text(
                                    isLogin
                                        ? 'Create an account'
                                        : 'Sign in',
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'By signing in/signing up, you agree to the Terms and Privacy Policy.',
                        style: tt.bodySmall?.copyWith(
                          color: AppTheme.textSecondary
                              .withValues(alpha: .8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}