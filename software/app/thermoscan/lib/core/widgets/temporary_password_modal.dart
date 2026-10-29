import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thermoscan/core/theme/app_colors.dart';
import 'package:thermoscan/core/theme/app_typography.dart';
import 'package:thermoscan/core/widgets/app_buttons.dart';

Future<void> showTemporaryPasswordModal({
  required BuildContext context,
  required String title,
  required String userName,
  required String userEmail,
  required String temporaryPassword,
  String? subtitle,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _TemporaryPasswordDialog(
      title: title,
      userName: userName,
      userEmail: userEmail,
      temporaryPassword: temporaryPassword,
      subtitle: subtitle,
    ),
  );
}

class _TemporaryPasswordDialog extends StatefulWidget {
  const _TemporaryPasswordDialog({
    required this.title,
    required this.userName,
    required this.userEmail,
    required this.temporaryPassword,
    this.subtitle,
  });

  final String title;
  final String userName;
  final String userEmail;
  final String temporaryPassword;
  final String? subtitle;

  @override
  State<_TemporaryPasswordDialog> createState() =>
      _TemporaryPasswordDialogState();
}

class _TemporaryPasswordDialogState extends State<_TemporaryPasswordDialog> {
  bool _copied = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.temporaryPassword));
    if (!mounted) return;
    setState(() {
      _copied = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.vpn_key_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: AppTypography.h3,
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle ??
                  'Share this temporary password with ${widget.userName} (${widget.userEmail}). It is shown only once and must be changed on first login.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                widget.temporaryPassword,
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoMono(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            if (_copied) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Temporary password copied to clipboard',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SecondaryButton(
              label: _copied ? 'Copy Again' : 'Copy Password',
              icon: Icons.content_copy_outlined,
              onPressed: _copyToClipboard,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
