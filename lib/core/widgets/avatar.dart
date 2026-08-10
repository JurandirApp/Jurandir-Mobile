import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Avatar circular âmbar com iniciais em ink (Bricolage 800).
class Avatar extends StatelessWidget {
  final String initials;
  final double size;

  const Avatar(this.initials, {super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.amber,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: AppText.display(size: size * 0.36, color: AppColors.ink),
      ),
    );
  }
}
