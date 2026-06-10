import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';

/// Reusable "Continue with Google" button matching the auth glass shell.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({required this.onPressed, this.isLoading = false, super.key});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Semantics(
        label: 'qa.auth.google_signin',
        identifier: 'qa.auth.google_signin',
        child: OutlinedButton(
          key: const ValueKey('qa.auth.google_signin'),
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppDesign.overlayLight.withValues(alpha: 0.92),
            foregroundColor: const Color(0xFF1F1F1F),
            side: BorderSide(color: AppDesign.overlayLight.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF1F1F1F)),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleGlyph(),
                    const SizedBox(width: 12),
                    Text(
                      'continue_with_google'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Minimal multi-color "G" glyph drawn without an asset dependency.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF4285F4)),
      ),
    );
  }
}
