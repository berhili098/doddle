import 'package:doddle/domain/models/draw_controller.dart';
import 'package:doddle/domain/models/point.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'dart:math' as math;

import 'shapes.dart';

const pi = math.pi;

class Sketcher extends CustomPainter {
  final List<Point?> points;
  final Size screenSize;
  final double symmetryLines;
  final Color color;
  final PenTool penTool;
  final double penSize;
  final bool mirrorSymmetry;
  final bool showGuidelines;

  Sketcher(
    this.points,
    this.screenSize,
    this.symmetryLines,
    this.color,
    this.penTool,
    this.penSize, {
    this.mirrorSymmetry = false,
    this.showGuidelines = true,
  });

  @override
  bool shouldRepaint(Sketcher oldDelegate) {
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);

    if (showGuidelines) {
      _drawGuidelines(canvas, size);
    }

    Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = penSize;

    Path path = Path();
    _drawPoints(canvas, path, paint);
    
    for (var i = 0; i < symmetryLines; i++) {
      canvas.save();
      _drawPathWithEffect(canvas, path, paint);
      canvas.restore();
      canvas.rotate(2 * pi / symmetryLines);
    }

    canvas.restore();
  }

  void _drawGuidelines(Canvas canvas, Size size) {
    final guidelinePaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final radius = math.min(size.width, size.height) / 2 - penSize;

    canvas.drawCircle(Offset.zero, radius, guidelinePaint);

    for (int i = 0; i < symmetryLines; i++) {
      final angle = i * 2 * pi / symmetryLines;
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;
      canvas.drawLine(Offset.zero, Offset(x, y), guidelinePaint);
    }
  }

  List<Offset> _getSymmetryPoints(Offset point) {
    final relX = point.dx;
    final relY = point.dy;
    final dist = math.sqrt(relX * relX + relY * relY);
    final angle = math.atan2(relX, relY);
    
    List<Offset> result = [];
    for (int i = 0; i < symmetryLines; i++) {
      final theta = angle + 2 * pi * i / symmetryLines;
      final x = math.sin(theta) * dist;
      final y = math.cos(theta) * dist;
      result.add(Offset(x, y));
      
      if (mirrorSymmetry) {
        result.add(Offset(-x, y));
      }
    }
    return result;
  }

  void _drawPoints(Canvas canvas, Path path, Paint paint) {
    for (var j = 0; j < points.length - 1; j++) {
      if (points[j + 1] == null) {
        j++;
        continue;
      }

      final currentPoint = points[j]?.offset;
      final nextPoint = points[j + 1]?.offset;
      
      if (currentPoint != null && nextPoint != null) {
        if (penTool == PenTool.customPen) {
          for (var offset in points[j]!.randomOffset!) {
            final symmetryOffsets = _getSymmetryPoints(offset);
            for (var symOffset in symmetryOffsets) {
              canvas.drawRect(symOffset & const Size(1.0, 1.0), paint);
            }
          }
        } else {
          path.moveTo(currentPoint.dx, currentPoint.dy);
          path.lineTo(nextPoint.dx, nextPoint.dy);
        }
      }
    }
  }

  void _applyPenEffects(Canvas canvas, Path path, Paint paint) {
    if (penTool == PenTool.eraserPen) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..strokeWidth = penSize,
      );
      return;
    }

    _drawPathWithEffect(canvas, path, paint);
  }

  void _drawPathWithEffect(Canvas canvas, Path path, Paint paint) {
    switch (penTool) {
      case PenTool.glowPen:
        _drawGlowPath(canvas, path, paint);
        break;
      case PenTool.normalPen:
        _drawNormalPath(canvas, path);
        break;
      case PenTool.normalWithShaderPen:
        _drawShaderPath(canvas, path);
        break;
      case PenTool.glowWithDotsPen:
        _drawGlowDotsPath(canvas, path, paint);
        break;
      default:
        break;
    }
  }

  void _drawGlowPath(Canvas canvas, Path path, Paint paint) {
    canvas.drawPath(
      path,
      paint
        ..color = color.withOpacity(0.2)
        ..strokeWidth = penSize * 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawPath(
      path,
      paint
        ..color = color.withOpacity(0.4)
        ..strokeWidth = penSize * 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawPath(
      path,
      paint
        ..color = color
        ..strokeWidth = penSize
        ..maskFilter = null,
    );
  }

  void _drawNormalPath(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = penSize,
    );
  }

  void _drawShaderPath(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..shader = sweepShader
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = penSize,
    );
  }

  void _drawGlowDotsPath(Canvas canvas, Path path, Paint paint) {
    _drawGlowPath(canvas, path, paint);

    for (var i = 0.0; i <= 1.0; i += 0.1) {
      final metric = path.computeMetrics().first;
      final tangent = metric.getTangentForOffset(metric.length * i);
      
      if (tangent != null) {
        final position = tangent.position;
        canvas.drawCircle(
          position,
          penSize / 4,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      }
    }
  }
}

const SweepGradient colorWheelGradient =
    SweepGradient(center: Alignment.bottomRight, colors: [
  Color.fromARGB(255, 255, 0, 0),
  Color.fromARGB(255, 255, 255, 0),
  Color.fromARGB(255, 0, 255, 0),
  Color.fromARGB(255, 0, 255, 255),
  Color.fromARGB(255, 0, 0, 255),
  Color.fromARGB(255, 255, 0, 255),
  Color.fromARGB(255, 255, 0, 0),
]);
// If we create a shader from the above SweepGraident, we get
// a crash on web, but only on web.
final Shader sweepShader =
    colorWheelGradient.createShader(const Rect.fromLTWH(0, 0, 100, 10));
