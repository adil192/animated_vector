import 'dart:io';
import 'dart:math' as math;

import 'package:animated_vector/src/animation.dart';
import 'package:animated_vector/src/path.dart';
import 'package:animated_vector/src/shapeshifter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

typedef VectorElements = List<VectorElement>;

class AnimatedVectorData {
  final RootVectorElement root;
  final Duration duration;
  final Size viewportSize;

  const AnimatedVectorData({
    required this.root,
    required this.duration,
    required this.viewportSize,
  });

  static Future<AnimatedVectorData> loadFromFile(File file) async {
    return ShapeShifterConverter.toAVD(await file.readAsString());
  }

  static Future<AnimatedVectorData> loadFromAsset(
    String assetName, {
    AssetBundle? bundle,
    String? package,
  }) {
    final assetKey =
        package != null ? "packages/$package/$assetName" : assetName;

    return (bundle ?? rootBundle).loadStructuredData(
      assetKey,
      (value) async => ShapeShifterConverter.toAVD(value),
    );
  }

  @override
  int get hashCode => Object.hash(root, duration, viewportSize);

  @override
  bool operator ==(Object other) {
    if (other is AnimatedVectorData) {
      return root == other.root &&
          duration == other.duration &&
          viewportSize == other.viewportSize;
    }

    return false;
  }

  Map<String, dynamic> toJson(String name) {
    return ShapeShifterConverter.toJson(this, name);
  }
}

abstract class VectorElement {
  const VectorElement();

  VectorElement evaluate(double progress, Duration animationDuration);

  void paint(
    Canvas canvas,
    Size size,
    double progress,
    Duration animationDuration,
  );
}

class RootVectorElement extends VectorElement {
  final double alpha;
  final RootVectorAnimationProperties properties;
  final VectorElements elements;

  const RootVectorElement({
    this.alpha = 1.0,
    this.properties = const RootVectorAnimationProperties(),
    this.elements = const [],
  });

  @override
  RootVectorElement evaluate(double progress, Duration animationDuration) {
    final evaluated = properties.evaluate(
      progress,
      animationDuration,
      defaultAlpha: alpha,
    );

    return RootVectorElement(
      alpha: evaluated.alpha!,
      elements: elements,
    );
  }

  @override
  void paint(Canvas canvas, Size size, double progress, Duration duration) {
    final RootVectorElement evaluated = evaluate(progress, duration);

    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..colorFilter = ColorFilter.mode(
          const Color(0xFFFFFFFF).withOpacity(evaluated.alpha),
          BlendMode.modulate,
        ),
    );
    for (final VectorElement element in evaluated.elements) {
      element.paint(canvas, size, progress, duration);
    }
    canvas.restore();
  }

  @override
  int get hashCode => Object.hash(alpha, elements, properties);

  @override
  bool operator ==(Object other) {
    if (other is RootVectorElement) {
      return alpha == other.alpha &&
          listEquals(elements, other.elements) &&
          properties == other.properties;
    }

    return false;
  }
}

class GroupElement extends VectorElement {
  final double translateX;
  final double translateY;
  final double scaleX;
  final double scaleY;
  final double pivotX;
  final double pivotY;
  final double rotation;
  final GroupAnimationProperties properties;
  final VectorElements elements;

  const GroupElement({
    this.translateX = 0.0,
    this.translateY = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.pivotX = 0.0,
    this.pivotY = 0.0,
    this.rotation = 0.0,
    this.properties = const GroupAnimationProperties(),
    this.elements = const [],
  });

  @override
  GroupElement evaluate(double progress, Duration animationDuration) {
    final evaluated = properties.evaluate(
      progress,
      animationDuration,
      defaultTranslateX: translateX,
      defaultTranslateY: translateY,
      defaultScaleX: scaleX,
      defaultScaleY: scaleY,
      defaultPivotX: pivotX,
      defaultPivotY: pivotY,
      defaultRotation: rotation,
    );

    return GroupElement(
      translateX: evaluated.translateX!,
      translateY: evaluated.translateY!,
      scaleX: evaluated.scaleX!,
      scaleY: evaluated.scaleY!,
      pivotX: evaluated.pivotX!,
      pivotY: evaluated.pivotY!,
      rotation: evaluated.rotation!,
      elements: elements,
    );
  }

  @override
  void paint(Canvas canvas, Size size, double progress, Duration duration) {
    final GroupElement evaluated = evaluate(progress, duration);

    final transformMatrix = Matrix4.identity()
      ..translate(evaluated.pivotX, evaluated.pivotY)
      ..translate(evaluated.translateX, evaluated.translateY)
      ..rotateZ(evaluated.rotation * math.pi / 180)
      ..scale(evaluated.scaleX, evaluated.scaleY)
      ..translate(-evaluated.pivotX, -evaluated.pivotY);

    canvas.save();
    canvas.transform(transformMatrix.storage);
    for (final VectorElement element in evaluated.elements) {
      element.paint(canvas, size, progress, duration);
    }
    canvas.restore();
  }

  @override
  int get hashCode => Object.hash(
        translateX,
        translateY,
        scaleX,
        scaleY,
        pivotX,
        pivotY,
        rotation,
        elements,
        properties,
      );

  @override
  bool operator ==(Object other) {
    if (other is GroupElement) {
      return translateX == other.translateX &&
          translateY == other.translateY &&
          scaleX == other.scaleX &&
          scaleY == other.scaleY &&
          pivotX == other.pivotX &&
          pivotY == other.pivotY &&
          rotation == other.rotation &&
          listEquals(elements, other.elements) &&
          properties == other.properties;
    }

    return false;
  }
}

class PathElement extends VectorElement {
  final PathData pathData;
  final Color? fillColor;
  final double fillAlpha;
  final Color? strokeColor;
  final double strokeAlpha;
  final double strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
  final double strokeMiterLimit;
  final double trimStart;
  final double trimEnd;
  final double trimOffset;
  final PathAnimationProperties properties;

  const PathElement({
    required this.pathData,
    this.fillColor,
    this.fillAlpha = 1.0,
    this.strokeColor,
    this.strokeAlpha = 1.0,
    this.strokeWidth = 1.0,
    this.strokeCap = StrokeCap.butt,
    this.strokeJoin = StrokeJoin.miter,
    this.strokeMiterLimit = 4.0,
    this.trimStart = 0.0,
    this.trimEnd = 1.0,
    this.trimOffset = 0.0,
    this.properties = const PathAnimationProperties(),
  })  : assert(trimStart >= 0 && trimStart <= 1),
        assert(trimEnd >= 0 && trimEnd <= 1),
        assert(trimOffset >= 0 && trimOffset <= 1);

  @override
  PathElement evaluate(double progress, Duration animationDuration) {
    final evaluated = properties.evaluate(
      progress,
      animationDuration,
      defaultPathData: pathData,
      defaultFillColor: fillColor,
      defaultFillAlpha: fillAlpha,
      defaultStrokeColor: strokeColor,
      defaultStrokeAlpha: strokeAlpha,
      defaultStrokeWidth: strokeWidth,
      defaultTrimStart: trimStart,
      defaultTrimEnd: trimEnd,
      defaultTrimOffset: trimOffset,
    );

    return PathElement(
      pathData: evaluated.pathData!,
      fillColor: evaluated.fillColor,
      fillAlpha: evaluated.fillAlpha!,
      strokeColor: evaluated.strokeColor,
      strokeAlpha: evaluated.strokeAlpha!,
      strokeWidth: evaluated.strokeWidth!,
      strokeCap: strokeCap,
      strokeJoin: strokeJoin,
      strokeMiterLimit: strokeMiterLimit,
      trimStart: evaluated.trimStart!,
      trimEnd: evaluated.trimEnd!,
      trimOffset: evaluated.trimOffset!,
    );
  }

  @override
  void paint(Canvas canvas, Size size, double progress, Duration duration) {
    final PathElement evaluated = evaluate(progress, duration);

    final Color fillColor = evaluated.fillColor ?? const Color(0x00000000);
    final Color strokeColor = evaluated.strokeColor ?? const Color(0x00000000);

    if (evaluated.strokeWidth > 0 && evaluated.strokeColor != null) {
      canvas.drawPath(
        evaluated.pathData.toPath(
          trimStart: evaluated.trimStart,
          trimEnd: evaluated.trimEnd,
          trimOffset: evaluated.trimOffset,
        ),
        Paint()
          ..color = strokeColor
              .withOpacity(strokeColor.opacity * evaluated.strokeAlpha)
          ..strokeWidth = evaluated.strokeWidth
          ..strokeCap = evaluated.strokeCap
          ..strokeJoin = evaluated.strokeJoin
          ..strokeMiterLimit = evaluated.strokeMiterLimit
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawPath(
      evaluated.pathData.toPath(),
      Paint()
        ..color =
            fillColor.withOpacity(fillColor.opacity * evaluated.fillAlpha),
    );
  }

  @override
  int get hashCode => Object.hash(
        pathData,
        fillColor,
        fillAlpha,
        strokeColor,
        strokeAlpha,
        strokeWidth,
        strokeCap,
        strokeJoin,
        strokeMiterLimit,
        trimStart,
        trimEnd,
        trimOffset,
        properties,
      );

  @override
  bool operator ==(Object other) {
    if (other is PathElement) {
      return pathData == other.pathData &&
          fillColor == other.fillColor &&
          fillAlpha == other.fillAlpha &&
          strokeColor == other.strokeColor &&
          strokeAlpha == other.strokeAlpha &&
          strokeWidth == other.strokeWidth &&
          strokeCap == other.strokeCap &&
          strokeJoin == other.strokeJoin &&
          strokeMiterLimit == other.strokeMiterLimit &&
          trimStart == other.trimStart &&
          trimEnd == other.trimEnd &&
          trimOffset == other.trimOffset &&
          properties == other.properties;
    }

    return false;
  }
}

class ClipPathElement extends VectorElement {
  final PathData pathData;
  final ClipPathAnimationProperties properties;

  const ClipPathElement({
    required this.pathData,
    this.properties = const ClipPathAnimationProperties(),
  });

  @override
  ClipPathElement evaluate(double progress, Duration animationDuration) {
    final evaluated = properties.evaluate(
      progress,
      animationDuration,
      defaultPathData: pathData,
    );

    return ClipPathElement(pathData: evaluated.pathData!);
  }

  @override
  void paint(Canvas canvas, Size size, double progress, Duration duration) {
    final ClipPathElement evaluated = evaluate(progress, duration);

    canvas.clipPath(evaluated.pathData.toPath());
  }

  @override
  int get hashCode => Object.hash(pathData, properties);

  @override
  bool operator ==(Object other) {
    if (other is ClipPathElement) {
      return pathData == other.pathData && properties == other.properties;
    }

    return false;
  }
}
