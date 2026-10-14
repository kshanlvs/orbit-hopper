import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class StardustBadge extends StatelessWidget {
  const StardustBadge({super.key, required this.amount, this.prefix = ''});

  final int amount;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.fade(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.fade(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Text(
            '$prefix$amount',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
