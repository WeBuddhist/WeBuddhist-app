import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class GroupChatSkeleton extends StatelessWidget {
  const GroupChatSkeleton({super.key});

  static const _widths = <double>[0.60, 0.50, 0.45, 0.68, 0.55];

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        children: [
          for (var i = 0; i < _widths.length; i++) ...[
            _row(isSelf: i.isOdd, widthFactor: _widths[i]),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _row({required bool isSelf, required double widthFactor}) {
    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Row(
          children: [
            if (!isSelf) ...const [Bone.circle(size: 32), SizedBox(width: 8)],
            const Expanded(
              child: Bone(
                height: 36,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            if (isSelf) ...const [SizedBox(width: 8), Bone.circle(size: 32)],
          ],
        ),
      ),
    );
  }
}
