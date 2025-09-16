import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpFeedbackView extends StatefulWidget {
  const HelpFeedbackView({super.key});

  @override
  State<HelpFeedbackView> createState() => _HelpFeedbackViewState();
}

class _HelpFeedbackViewState extends State<HelpFeedbackView> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  static const _supportEmail = 'rabahmanar7@gmail.com';

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw 'Could not launch email client';
      Get.snackbar(
        'Opening email',
        'Creating a draft message…',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(
        text: 'To: $_supportEmail\nSubject: $subject\n\n$body',
      ));
      Get.snackbar(
        'Email app not available',
        'Details copied to clipboard. Paste into your email app.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Feedback')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Enter a short title…',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter a subject';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Describe your issue or feedback…',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter a message';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
