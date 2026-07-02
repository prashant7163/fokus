import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a recovery SVG illustration from `assets/recovery/`. Decorative —
/// excluded from semantics (the surrounding copy carries meaning).
class RecoveryIllustration extends StatelessWidget {
  const RecoveryIllustration({super.key, required this.asset, this.size = 200});

  /// File name without extension, e.g. `recovery_stretch`.
  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/recovery/$asset.svg',
        width: size,
        height: size,
      ),
    );
  }
}
