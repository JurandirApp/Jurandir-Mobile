import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Campo de formulário (contexto claro): rótulo opcional + input radius 12.
class LabeledInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;

  const LabeledInput({
    super.key,
    this.label,
    this.hint,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!.toUpperCase(),
              style: AppText.body(size: 11, weight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.inkA(0.5))),
          const SizedBox(height: 5),
        ],
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: AppText.body(size: 13, weight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.4)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.inkA(0.15), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.ink, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
