import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Four ascending bars, filled according to RSSI.
class SignalBars extends StatelessWidget {
  const SignalBars({required this.rssi, super.key});

  final int rssi;

  int get _strength {
    if (rssi >= -55) return 4;
    if (rssi >= -67) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Container(
            width: 3,
            height: 4.0 * i,
            decoration: BoxDecoration(
              color: i <= _strength
                  ? AppColors.active
                  : AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (i < 4) const SizedBox(width: 2),
        ],
      ],
    );
  }
}
