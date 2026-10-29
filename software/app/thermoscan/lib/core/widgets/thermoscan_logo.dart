import 'package:flutter/material.dart';
import 'package:thermoscan/core/theme/app_colors.dart';
import 'package:thermoscan/core/theme/app_typography.dart';

class ThermoScanLogoIcon extends StatelessWidget {
  const ThermoScanLogoIcon({
    super.key,
    this.size = 32,
    this.strokeColor = AppColors.primary,
    this.backgroundColor,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
  });

  final double size;
  final Color strokeColor;
  final Color? backgroundColor;
  final double? borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(size),
      painter: _ThermoScanLogoPainter(strokeColor: strokeColor),
    );

    if (backgroundColor == null) {
      return icon;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius ?? size * 0.225),
      ),
      child: icon,
    );
  }
}

class _ThermoScanLogoPainter extends CustomPainter {
  const _ThermoScanLogoPainter({required this.strokeColor});

  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 64.0;
    final scaleY = size.height / 64.0;
    final scale = (scaleX + scaleY) / 2.0;

    final gridPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Outer solar module frame: rect x="6" y="13" width="52" height="38" rx="6"
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6 * scaleX, 13 * scaleY, 52 * scaleX, 38 * scaleY),
      Radius.circular(6 * scale),
    );
    canvas.drawRRect(panelRect, gridPaint);

    // Internal cell grid lines: M23 13v38 M41 13v38 M6 32h52
    canvas.drawLine(
      Offset(23 * scaleX, 13 * scaleY),
      Offset(23 * scaleX, 51 * scaleY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(41 * scaleX, 13 * scaleY),
      Offset(41 * scaleX, 51 * scaleY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(6 * scaleX, 32 * scaleY),
      Offset(58 * scaleX, 32 * scaleY),
      gridPaint,
    );

    // Thermal hotspot circle: cx="49.5" cy="22.5" r="6.5"
    final hotspotCenter = Offset(49.5 * scaleX, 22.5 * scaleY);
    final hotspotRadius = 7.2 * scale;
    final hotspotPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          AppColors.thermalMid,
          AppColors.thermalWarm,
          AppColors.thermalHot,
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: hotspotCenter, radius: hotspotRadius),
      );

    canvas.drawCircle(hotspotCenter, hotspotRadius, hotspotPaint);
  }

  @override
  bool shouldRepaint(covariant _ThermoScanLogoPainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor;
  }
}

class ThermoScanBrandMark extends StatelessWidget {
  const ThermoScanBrandMark({
    super.key,
    this.iconSize = 26,
    this.fontSize = 20,
    this.color = AppColors.primary,
  });

  final double iconSize;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThermoScanLogoIcon(size: iconSize, strokeColor: color),
        const SizedBox(width: 8),
        Text(
          'ThermoScan',
          style: AppTypography.h2.copyWith(
            fontSize: fontSize,
            color: color,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class RadiometricSpectrumBar extends StatelessWidget {
  const RadiometricSpectrumBar({
    super.key,
    this.width = 192,
    this.height = 6,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        width: width,
        height: height,
        child: Row(
          children: AppColors.thermalSpectrum
              .map(
                (color) => Expanded(
                  child: Container(color: color),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
