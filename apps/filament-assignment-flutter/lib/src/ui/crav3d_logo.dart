import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Crav3dLogo extends StatelessWidget {
  const Crav3dLogo({super.key, required this.width, this.color = Colors.white});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/CRAV3D.svg',
      width: width,
      fit: BoxFit.contain,
      semanticsLabel: 'CRAV3D logo',
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
