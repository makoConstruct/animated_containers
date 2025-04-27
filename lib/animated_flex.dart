// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/widgets.dart';
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:animated_containers/util.dart';
import 'package:flutter/rendering.dart';

// The ascent and descent of a baseline-aligned child.
//
// Baseline-aligned children contributes to the cross axis extent of a [RenderFlex]
// differently from children with other [CrossAxisAlignment]s.
extension type const _AscentDescent._(
    (double ascent, double descent)? ascentDescent) {
  factory _AscentDescent(
      {required double? baselineOffset, required double crossSize}) {
    return baselineOffset == null
        ? none
        : _AscentDescent._((baselineOffset, crossSize - baselineOffset));
  }
  static const _AscentDescent none = _AscentDescent._(null);

  double? get baselineOffset => ascentDescent?.$1;

  _AscentDescent operator +(_AscentDescent other) => switch ((this, other)) {
        (null, final _AscentDescent v) || (final _AscentDescent v, null) => v,
        (
          (final double xAscent, final double xDescent),
          (final double yAscent, final double yDescent)
        ) =>
          _AscentDescent._(
              (math.max(xAscent, yAscent), math.max(xDescent, yDescent))),
      };
}

typedef _ChildSizingFunction = double Function(RenderBox child, double extent);
typedef _NextChild = RenderBox? Function(RenderBox child);

class _LayoutSizes {
  _LayoutSizes({
    required this.axisSize,
    required this.baselineOffset,
    required this.mainAxisFreeSpace,
    required this.spacePerFlex,
  }) : assert(spacePerFlex?.isFinite ?? true);

  // The final constrained AxisSize of the RenderFlex.
  final AxisSize axisSize;

  // The free space along the main axis. If the value is positive, the free space
  // will be distributed according to the [MainAxisAlignment] specified. A
  // negative value indicates the RenderFlex overflows along the main axis.
  final double mainAxisFreeSpace;

  // Null if the RenderFlex is not baseline aligned, or none of its children has
  // a valid baseline of the given [TextBaseline] type.
  final double? baselineOffset;

  // The allocated space for flex children.
  final double? spacePerFlex;
}

/// How the child is inscribed into the available space.
///
/// See also:
///
///  * [AnimatedRenderFlex], the flex render object.
///  * [Column], [Row], and [AnimatedFlex], the flex widgets.
///  * [Expanded], the widget equivalent of [tight].
///  * [Flexible], the widget equivalent of [loose].

/// Parent data for use with [AnimatedRenderFlex].
class AnimatedFlexParentData extends ContainerBoxParentData<RenderBox> {
  /// The flex factor to use for this child.
  ///
  /// If null or zero, the child is inflexible and determines its own size. If
  /// non-zero, the amount of space the child's can occupy in the main axis is
  /// determined by dividing the free space (after placing the inflexible
  /// children) according to the flex factors of the flexible children.
  int? flex;

  /// How a flexible child is inscribed into the available space.
  ///
  /// If [flex] is non-zero, the [fit] determines whether the child fills the
  /// space the parent makes available during layout. If the fit is
  /// [FlexFit.tight], the child is required to fill the available space. If the
  /// fit is [FlexFit.loose], the child can be at most as large as the available
  /// space (but is allowed to be smaller).
  FlexFit? fit;

  Offset previousOffset = const Offset(double.nan, double.nan);
  Offset previousVelocity = const Offset(0, 0);

  @override
  String toString() => '${super.toString()}; flex=$flex; fit=$fit';
}

double _getChildCrossAxisOffset(
    CrossAxisAlignment alignment, double freeSpace, bool flipped) {
  // This method should not be used to position baseline-aligned children.
  return switch (alignment) {
    CrossAxisAlignment.stretch || CrossAxisAlignment.baseline => 0.0,
    CrossAxisAlignment.start => flipped ? freeSpace : 0.0,
    CrossAxisAlignment.center => freeSpace / 2,
    CrossAxisAlignment.end =>
      _getChildCrossAxisOffset(CrossAxisAlignment.start, freeSpace, !flipped),
  };
}

/// Displays its children in a one-dimensional array.
///
/// ## Layout algorithm
///
/// _This section describes how the framework causes [AnimatedRenderFlex] to position
/// its children._
/// _See [BoxConstraints] for an introduction to box layout models._
///
/// Layout for a [AnimatedRenderFlex] proceeds in six steps:
///
/// 1. Layout each child with a null or zero flex factor with unbounded main
///    axis constraints and the incoming cross axis constraints. If the
///    [crossAxisAlignment] is [CrossAxisAlignment.stretch], instead use tight
///    cross axis constraints that match the incoming max extent in the cross
///    axis.
/// 2. Divide the remaining main axis space among the children with non-zero
///    flex factors according to their flex factor. For example, a child with a
///    flex factor of 2.0 will receive twice the amount of main axis space as a
///    child with a flex factor of 1.0.
/// 3. Layout each of the remaining children with the same cross axis
///    constraints as in step 1, but instead of using unbounded main axis
///    constraints, use max axis constraints based on the amount of space
///    allocated in step 2. Children with [Flexible.fit] properties that are
///    [FlexFit.tight] are given tight constraints (i.e., forced to fill the
///    allocated space), and children with [Flexible.fit] properties that are
///    [FlexFit.loose] are given loose constraints (i.e., not forced to fill the
///    allocated space).
/// 4. The cross axis extent of the [AnimatedRenderFlex] is the maximum cross axis
///    extent of the children (which will always satisfy the incoming
///    constraints).
/// 5. The main axis extent of the [AnimatedRenderFlex] is determined by the
///    [mainAxisSize] property. If the [mainAxisSize] property is
///    [MainAxisSize.max], then the main axis extent of the [AnimatedRenderFlex] is the
///    max extent of the incoming main axis constraints. If the [mainAxisSize]
///    property is [MainAxisSize.min], then the main axis extent of the [AnimatedFlex]
///    is the sum of the main axis extents of the children (subject to the
///    incoming constraints).
/// 6. Determine the position for each child according to the
///    [mainAxisAlignment] and the [crossAxisAlignment]. For example, if the
///    [mainAxisAlignment] is [MainAxisAlignment.spaceBetween], any main axis
///    space that has not been allocated to children is divided evenly and
///    placed between the children.
///
/// See also:
///
///  * [AnimatedFlex], the widget equivalent.
///  * [Row] and [Column], direction-specific variants of [AnimatedFlex].
class AnimatedRenderFlex extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, AnimatedFlexParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, AnimatedFlexParentData>,
        DebugOverflowIndicatorMixin {
  /// Creates a flex render object.
  ///
  /// By default, the flex layout is horizontal and children are aligned to the
  /// start of the main axis and the center of the cross axis.
  AnimatedRenderFlex({
    List<RenderBox>? children,
    Axis direction = Axis.horizontal,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextDirection? textDirection,
    VerticalDirection verticalDirection = VerticalDirection.down,
    TextBaseline? textBaseline,
    Clip clipBehavior = Clip.none,
    double spacing = 0.0,
  })  : _direction = direction,
        _mainAxisAlignment = mainAxisAlignment,
        _mainAxisSize = mainAxisSize,
        _crossAxisAlignment = crossAxisAlignment,
        _textDirection = textDirection,
        _verticalDirection = verticalDirection,
        _textBaseline = textBaseline,
        _clipBehavior = clipBehavior,
        _spacing = spacing,
        assert(spacing >= 0.0) {
    addAll(children);
  }

  /// The direction to use as the main axis.
  Axis get direction => _direction;
  Axis _direction;
  set direction(Axis value) {
    if (_direction != value) {
      _direction = value;
      markNeedsLayout();
    }
  }

  /// How the children should be placed along the main axis.
  ///
  /// If the [direction] is [Axis.horizontal], and the [mainAxisAlignment] is
  /// either [MainAxisAlignment.start] or [MainAxisAlignment.end], then the
  /// [textDirection] must not be null.
  ///
  /// If the [direction] is [Axis.vertical], and the [mainAxisAlignment] is
  /// either [MainAxisAlignment.start] or [MainAxisAlignment.end], then the
  /// [verticalDirection] must not be null.
  MainAxisAlignment get mainAxisAlignment => _mainAxisAlignment;
  MainAxisAlignment _mainAxisAlignment;
  set mainAxisAlignment(MainAxisAlignment value) {
    if (_mainAxisAlignment != value) {
      _mainAxisAlignment = value;
      markNeedsLayout();
    }
  }

  /// How much space should be occupied in the main axis.
  ///
  /// After allocating space to children, there might be some remaining free
  /// space. This value controls whether to maximize or minimize the amount of
  /// free space, subject to the incoming layout constraints.
  ///
  /// If some children have a non-zero flex factors (and none have a fit of
  /// [FlexFit.loose]), they will expand to consume all the available space and
  /// there will be no remaining free space to maximize or minimize, making this
  /// value irrelevant to the final layout.
  MainAxisSize get mainAxisSize => _mainAxisSize;
  MainAxisSize _mainAxisSize;
  set mainAxisSize(MainAxisSize value) {
    if (_mainAxisSize != value) {
      _mainAxisSize = value;
      markNeedsLayout();
    }
  }

  /// How the children should be placed along the cross axis.
  ///
  /// If the [direction] is [Axis.horizontal], and the [crossAxisAlignment] is
  /// either [CrossAxisAlignment.start] or [CrossAxisAlignment.end], then the
  /// [verticalDirection] must not be null.
  ///
  /// If the [direction] is [Axis.vertical], and the [crossAxisAlignment] is
  /// either [CrossAxisAlignment.start] or [CrossAxisAlignment.end], then the
  /// [textDirection] must not be null.
  CrossAxisAlignment get crossAxisAlignment => _crossAxisAlignment;
  CrossAxisAlignment _crossAxisAlignment;
  set crossAxisAlignment(CrossAxisAlignment value) {
    if (_crossAxisAlignment != value) {
      _crossAxisAlignment = value;
      markNeedsLayout();
    }
  }

  /// Determines the order to lay children out horizontally and how to interpret
  /// `start` and `end` in the horizontal direction.
  ///
  /// If the [direction] is [Axis.horizontal], this controls the order in which
  /// children are positioned (left-to-right or right-to-left), and the meaning
  /// of the [mainAxisAlignment] property's [MainAxisAlignment.start] and
  /// [MainAxisAlignment.end] values.
  ///
  /// If the [direction] is [Axis.horizontal], and either the
  /// [mainAxisAlignment] is either [MainAxisAlignment.start] or
  /// [MainAxisAlignment.end], or there's more than one child, then the
  /// [textDirection] must not be null.
  ///
  /// If the [direction] is [Axis.vertical], this controls the meaning of the
  /// [crossAxisAlignment] property's [CrossAxisAlignment.start] and
  /// [CrossAxisAlignment.end] values.
  ///
  /// If the [direction] is [Axis.vertical], and the [crossAxisAlignment] is
  /// either [CrossAxisAlignment.start] or [CrossAxisAlignment.end], then the
  /// [textDirection] must not be null.
  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection != value) {
      _textDirection = value;
      markNeedsLayout();
    }
  }

  /// Determines the order to lay children out vertically and how to interpret
  /// `start` and `end` in the vertical direction.
  ///
  /// If the [direction] is [Axis.vertical], this controls which order children
  /// are painted in (down or up), the meaning of the [mainAxisAlignment]
  /// property's [MainAxisAlignment.start] and [MainAxisAlignment.end] values.
  ///
  /// If the [direction] is [Axis.vertical], and either the [mainAxisAlignment]
  /// is either [MainAxisAlignment.start] or [MainAxisAlignment.end], or there's
  /// more than one child, then the [verticalDirection] must not be null.
  ///
  /// If the [direction] is [Axis.horizontal], this controls the meaning of the
  /// [crossAxisAlignment] property's [CrossAxisAlignment.start] and
  /// [CrossAxisAlignment.end] values.
  ///
  /// If the [direction] is [Axis.horizontal], and the [crossAxisAlignment] is
  /// either [CrossAxisAlignment.start] or [CrossAxisAlignment.end], then the
  /// [verticalDirection] must not be null.
  VerticalDirection get verticalDirection => _verticalDirection;
  VerticalDirection _verticalDirection;
  set verticalDirection(VerticalDirection value) {
    if (_verticalDirection != value) {
      _verticalDirection = value;
      markNeedsLayout();
    }
  }

  /// If aligning items according to their baseline, which baseline to use.
  ///
  /// Must not be null if [crossAxisAlignment] is [CrossAxisAlignment.baseline].
  TextBaseline? get textBaseline => _textBaseline;
  TextBaseline? _textBaseline;
  set textBaseline(TextBaseline? value) {
    assert(_crossAxisAlignment != CrossAxisAlignment.baseline || value != null);
    if (_textBaseline != value) {
      _textBaseline = value;
      markNeedsLayout();
    }
  }

  bool get _debugHasNecessaryDirections {
    if (RenderObject.debugCheckingIntrinsics) {
      return true;
    }
    if (firstChild != null && lastChild != firstChild) {
      // i.e. there's more than one child
      switch (direction) {
        case Axis.horizontal:
          assert(textDirection != null,
              'Horizontal $runtimeType with multiple children has a null textDirection, so the layout order is undefined.');
        case Axis.vertical:
          break;
      }
    }
    if (mainAxisAlignment == MainAxisAlignment.start ||
        mainAxisAlignment == MainAxisAlignment.end) {
      switch (direction) {
        case Axis.horizontal:
          assert(textDirection != null,
              'Horizontal $runtimeType with $mainAxisAlignment has a null textDirection, so the alignment cannot be resolved.');
        case Axis.vertical:
          break;
      }
    }
    if (crossAxisAlignment == CrossAxisAlignment.start ||
        crossAxisAlignment == CrossAxisAlignment.end) {
      switch (direction) {
        case Axis.horizontal:
          break;
        case Axis.vertical:
          assert(textDirection != null,
              'Vertical $runtimeType with $crossAxisAlignment has a null textDirection, so the alignment cannot be resolved.');
      }
    }
    return true;
  }

  // Set during layout if overflow occurred on the main axis.
  double _overflow = 0;
  // Check whether any meaningful overflow is present. Values below an epsilon
  // are treated as not overflowing.
  bool get _hasOverflow => _overflow > precisionErrorTolerance;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.none].
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.none;
  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  /// {@template flutter.rendering.RenderFlex.spacing}
  /// How much space to place between children in the main axis.
  ///
  /// The spacing is only applied between children in the main axis.
  ///
  /// If the [spacing] is 10.0 and the [mainAxisAlignment] is
  /// [MainAxisAlignment.start], then the first child will be placed at the start
  /// of the main axis, and the second child will be placed 10.0 pixels after
  /// the first child in the main axis, and so on. The [spacing] is not applied
  /// before the first child or after the last child.
  ///
  /// If the [spacing] is 10.0 and the [mainAxisAlignment] is [MainAxisAlignment.end],
  /// then the last child will be placed at the end of the main axis, and the
  /// second-to-last child will be placed 10.0 pixels before the last child in
  /// the main axis, and so on. The [spacing] is not applied before the first
  /// child or after the last child.
  ///
  /// If the [spacing] is 10.0 and the [mainAxisAlignment] is [MainAxisAlignment.center],
  /// then the children will be placed in the center of the main axis with 10.0
  /// pixels of space between the children. The [spacing] is not applied before the first
  /// child or after the last child.
  ///
  /// If the [spacing] is 10.0 and the [mainAxisAlignment] is [MainAxisAlignment.spaceBetween],
  /// then there will be a minimum of 10.0 pixels of space between each child in the
  /// main axis. If the free space is 100.0 pixels between the two children,
  /// then the minimum space between the children will be 10.0 pixels and the
  /// remaining 90.0 pixels will be the free space between the children. The
  /// [spacing] is not applied before the first child or after the last child.
  ///
  /// If the [spacing] is 10.0 and the [mainAxisAlignment] is [MainAxisAlignment.spaceAround],
  /// then there will be a minimum of 10.0 pixels of space between each child in the
  /// main axis, and the remaining free space will be placed between the children as
  /// well as before the first child and after the last child. The [spacing] is
  /// not applied before the first child or after the last child.
  ///
  /// If the [spacing] is 10.0 and the [mainAxisAlignment] is [MainAxisAlignment.spaceEvenly],
  /// then there will be a minimum of 10.0 pixels of space between each child in the
  /// main axis, and the remaining free space will be evenly placed between the
  /// children as well as before the first child and after the last child. The
  /// [spacing] is not applied before the first child or after the last child.
  ///
  /// When the [spacing] is non-zero, the layout size will be larger than
  /// the sum of the children's layout sizes in the main axis.
  ///
  /// When the total children's layout sizes and total spacing between the
  /// children is greater than the maximum constraints in the main axis, then
  /// the children will overflow. For example, if there are two children and the
  /// maximum constraint is 100.0 pixels, the children's layout sizes are 50.0
  /// pixels each, and the spacing is 10.0 pixels, then the children will
  /// overflow by 10.0 pixels.
  ///
  /// Defaults to 0.0.
  /// {@endtemplate}
  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (_spacing == value) {
      return;
    }
    _spacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! AnimatedFlexParentData) {
      child.parentData = AnimatedFlexParentData();
    }
  }

  double _getIntrinsicSize({
    required Axis sizingDirection,
    required double
        extent, // The extent in the direction that isn't the sizing direction.
    required _ChildSizingFunction
        childSize, // A method to find the size in the sizing direction.
  }) {
    if (_direction == sizingDirection) {
      // INTRINSIC MAIN SIZE
      // Intrinsic main size is the smallest size the flex container can take
      // while maintaining the min/max-content contributions of its flex items.
      double totalFlex = 0.0;
      double inflexibleSpace = spacing * (childCount - 1);
      double maxFlexFractionSoFar = 0.0;
      for (RenderBox? child = firstChild;
          child != null;
          child = childAfter(child)) {
        final int flex = _getFlex(child);
        totalFlex += flex;
        if (flex > 0) {
          final double flexFraction = childSize(child, extent) / flex;
          maxFlexFractionSoFar = math.max(maxFlexFractionSoFar, flexFraction);
        } else {
          inflexibleSpace += childSize(child, extent);
        }
      }
      return maxFlexFractionSoFar * totalFlex + inflexibleSpace;
    } else {
      // INTRINSIC CROSS SIZE
      // Intrinsic cross size is the max of the intrinsic cross sizes of the
      // children, after the flexible children are fit into the available space,
      // with the children sized using their max intrinsic dimensions.
      final bool isHorizontal = switch (direction) {
        Axis.horizontal => true,
        Axis.vertical => false,
      };

      Size layoutChild(RenderBox child, BoxConstraints constraints) {
        final double mainAxisSizeFromConstraints =
            isHorizontal ? constraints.maxWidth : constraints.maxHeight;
        // A infinite mainAxisSizeFromConstraints means this child is flexible (or extent is double.infinity).
        assert((_getFlex(child) != 0 && extent.isFinite) ==
            mainAxisSizeFromConstraints.isFinite);
        final double maxMainAxisSize = mainAxisSizeFromConstraints.isFinite
            ? mainAxisSizeFromConstraints
            : (isHorizontal
                ? child.getMaxIntrinsicWidth(double.infinity)
                : child.getMaxIntrinsicHeight(double.infinity));
        return isHorizontal
            ? Size(maxMainAxisSize, childSize(child, maxMainAxisSize))
            : Size(childSize(child, maxMainAxisSize), maxMainAxisSize);
      }

      return _computeSizes(
        constraints: isHorizontal
            ? BoxConstraints(maxWidth: extent)
            : BoxConstraints(maxHeight: extent),
        layoutChild: layoutChild,
        getBaseline: ChildLayoutHelper.getDryBaseline,
      ).axisSize.crossAxisExtent;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _getIntrinsicSize(
      sizingDirection: Axis.horizontal,
      extent: height,
      childSize: (RenderBox child, double extent) =>
          child.getMinIntrinsicWidth(extent),
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _getIntrinsicSize(
      sizingDirection: Axis.horizontal,
      extent: height,
      childSize: (RenderBox child, double extent) =>
          child.getMaxIntrinsicWidth(extent),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _getIntrinsicSize(
      sizingDirection: Axis.vertical,
      extent: width,
      childSize: (RenderBox child, double extent) =>
          child.getMinIntrinsicHeight(extent),
    );
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _getIntrinsicSize(
      sizingDirection: Axis.vertical,
      extent: width,
      childSize: (RenderBox child, double extent) =>
          child.getMaxIntrinsicHeight(extent),
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return switch (_direction) {
      Axis.horizontal =>
        defaultComputeDistanceToHighestActualBaseline(baseline),
      Axis.vertical => defaultComputeDistanceToFirstActualBaseline(baseline),
    };
  }

  static int _getFlex(RenderBox child) {
    final AnimatedFlexParentData childParentData =
        child.parentData! as AnimatedFlexParentData;
    return childParentData.flex ?? 0;
  }

  static FlexFit _getFit(RenderBox child) {
    final AnimatedFlexParentData childParentData =
        child.parentData! as AnimatedFlexParentData;
    return childParentData.fit ?? FlexFit.tight;
  }

  bool get _isBaselineAligned {
    return switch (crossAxisAlignment) {
      CrossAxisAlignment.baseline => switch (direction) {
          Axis.horizontal => true,
          Axis.vertical => false,
        },
      CrossAxisAlignment.start ||
      CrossAxisAlignment.center ||
      CrossAxisAlignment.end ||
      CrossAxisAlignment.stretch =>
        false,
    };
  }

  double _getCrossSize(Size size) {
    return switch (_direction) {
      Axis.horizontal => size.height,
      Axis.vertical => size.width,
    };
  }

  double _getMainSize(Size size) {
    return switch (_direction) {
      Axis.horizontal => size.width,
      Axis.vertical => size.height,
    };
  }

  // flipMainAxis is used to decide whether to lay out
  // left-to-right/top-to-bottom (false), or right-to-left/bottom-to-top
  // (true). Returns false in cases when the layout direction does not matter
  // (for instance, there is no child).
  bool get _flipMainAxis =>
      firstChild != null &&
      switch (direction) {
        Axis.horizontal => switch (textDirection) {
            null || TextDirection.ltr => false,
            TextDirection.rtl => true,
          },
        Axis.vertical => switch (verticalDirection) {
            VerticalDirection.down => false,
            VerticalDirection.up => true,
          },
      };

  bool get _flipCrossAxis =>
      firstChild != null &&
      switch (direction) {
        Axis.vertical => switch (textDirection) {
            null || TextDirection.ltr => false,
            TextDirection.rtl => true,
          },
        Axis.horizontal => switch (verticalDirection) {
            VerticalDirection.down => false,
            VerticalDirection.up => true,
          },
      };

  BoxConstraints _constraintsForNonFlexChild(BoxConstraints constraints) {
    final bool fillCrossAxis = switch (crossAxisAlignment) {
      CrossAxisAlignment.stretch => true,
      CrossAxisAlignment.start ||
      CrossAxisAlignment.center ||
      CrossAxisAlignment.end ||
      CrossAxisAlignment.baseline =>
        false,
    };
    return switch (_direction) {
      Axis.horizontal => fillCrossAxis
          ? BoxConstraints.tightFor(height: constraints.maxHeight)
          : BoxConstraints(maxHeight: constraints.maxHeight),
      Axis.vertical => fillCrossAxis
          ? BoxConstraints.tightFor(width: constraints.maxWidth)
          : BoxConstraints(maxWidth: constraints.maxWidth),
    };
  }

  BoxConstraints _constraintsForFlexChild(
      RenderBox child, BoxConstraints constraints, double maxChildExtent) {
    assert(_getFlex(child) > 0.0);
    assert(maxChildExtent >= 0.0);
    final double minChildExtent = switch (_getFit(child)) {
      FlexFit.tight => maxChildExtent,
      FlexFit.loose => 0.0,
    };
    final bool fillCrossAxis = switch (crossAxisAlignment) {
      CrossAxisAlignment.stretch => true,
      CrossAxisAlignment.start ||
      CrossAxisAlignment.center ||
      CrossAxisAlignment.end ||
      CrossAxisAlignment.baseline =>
        false,
    };
    return switch (_direction) {
      Axis.horizontal => BoxConstraints(
          minWidth: minChildExtent,
          maxWidth: maxChildExtent,
          minHeight: fillCrossAxis ? constraints.maxHeight : 0.0,
          maxHeight: constraints.maxHeight,
        ),
      Axis.vertical => BoxConstraints(
          minWidth: fillCrossAxis ? constraints.maxWidth : 0.0,
          maxWidth: constraints.maxWidth,
          minHeight: minChildExtent,
          maxHeight: maxChildExtent,
        ),
    };
  }

  @override
  double? computeDryBaseline(
      BoxConstraints constraints, TextBaseline baseline) {
    final _LayoutSizes sizes = _computeSizes(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.dryLayoutChild,
      getBaseline: ChildLayoutHelper.getDryBaseline,
    );

    if (_isBaselineAligned) {
      return sizes.baselineOffset;
    }

    final BoxConstraints nonFlexConstraints =
        _constraintsForNonFlexChild(constraints);
    BoxConstraints constraintsForChild(RenderBox child) {
      final double? spacePerFlex = sizes.spacePerFlex;
      final int flex;
      return spacePerFlex != null && (flex = _getFlex(child)) > 0
          ? _constraintsForFlexChild(child, constraints, flex * spacePerFlex)
          : nonFlexConstraints;
    }

    BaselineOffset baselineOffset = BaselineOffset.noBaseline;
    switch (direction) {
      case Axis.vertical:
        final double freeSpace = math.max(0.0, sizes.mainAxisFreeSpace);
        final bool flipMainAxis = _flipMainAxis;
        final (double leadingSpaceY, double spaceBetween) = distributeSpace(
            mainAxisAlignment, freeSpace, childCount, flipMainAxis, spacing);
        double y = flipMainAxis
            ? leadingSpaceY +
                (childCount - 1) * spaceBetween +
                (sizes.axisSize.mainAxisExtent - sizes.mainAxisFreeSpace)
            : leadingSpaceY;
        final double directionUnit = flipMainAxis ? -1.0 : 1.0;
        for (RenderBox? child = firstChild;
            baselineOffset == BaselineOffset.noBaseline && child != null;
            child = childAfter(child)) {
          final BoxConstraints childConstraints = constraintsForChild(child);
          final Size childSize = child.getDryLayout(childConstraints);
          final double? childBaselineOffset =
              child.getDryBaseline(childConstraints, baseline);
          final double additionalY = flipMainAxis ? -childSize.height : 0.0;
          baselineOffset =
              BaselineOffset(childBaselineOffset) + y + additionalY;
          y += directionUnit * (spaceBetween + childSize.height);
        }
      case Axis.horizontal:
        final bool flipCrossAxis = _flipCrossAxis;
        for (RenderBox? child = firstChild;
            child != null;
            child = childAfter(child)) {
          final BoxConstraints childConstraints = constraintsForChild(child);
          final BaselineOffset distance =
              BaselineOffset(child.getDryBaseline(childConstraints, baseline));
          final double freeCrossAxisSpace = sizes.axisSize.crossAxisExtent -
              child.getDryLayout(childConstraints).height;
          final BaselineOffset childBaseline = distance +
              _getChildCrossAxisOffset(
                  crossAxisAlignment, freeCrossAxisSpace, flipCrossAxis);
          baselineOffset = baselineOffset.minOf(childBaseline);
        }
    }
    return baselineOffset.offset;
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    FlutterError? constraintsError;
    assert(() {
      constraintsError = _debugCheckConstraints(
        constraints: constraints,
        reportParentConstraints: false,
      );
      return true;
    }());
    if (constraintsError != null) {
      assert(debugCannotComputeDryLayout(error: constraintsError));
      return Size.zero;
    }

    return _computeSizes(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.dryLayoutChild,
      getBaseline: ChildLayoutHelper.getDryBaseline,
    ).axisSize.toSize(direction);
  }

  FlutterError? _debugCheckConstraints(
      {required BoxConstraints constraints,
      required bool reportParentConstraints}) {
    FlutterError? result;
    assert(() {
      final double maxMainSize = _direction == Axis.horizontal
          ? constraints.maxWidth
          : constraints.maxHeight;
      final bool canFlex = maxMainSize < double.infinity;
      RenderBox? child = firstChild;
      while (child != null) {
        final int flex = _getFlex(child);
        if (flex > 0) {
          final String identity =
              _direction == Axis.horizontal ? 'row' : 'column';
          final String axis =
              _direction == Axis.horizontal ? 'horizontal' : 'vertical';
          final String dimension =
              _direction == Axis.horizontal ? 'width' : 'height';
          DiagnosticsNode error, message;
          final List<DiagnosticsNode> addendum = <DiagnosticsNode>[];
          if (!canFlex &&
              (mainAxisSize == MainAxisSize.max ||
                  _getFit(child) == FlexFit.tight)) {
            error = ErrorSummary(
                'RenderFlex children have non-zero flex but incoming $dimension constraints are unbounded.');
            message = ErrorDescription(
              'When a $identity is in a parent that does not provide a finite $dimension constraint, for example '
              'if it is in a $axis scrollable, it will try to shrink-wrap its children along the $axis '
              'axis. Setting a flex on a child (e.g. using Expanded) indicates that the child is to '
              'expand to fill the remaining space in the $axis direction.',
            );
            if (reportParentConstraints) {
              // Constraints of parents are unavailable in dry layout.
              RenderBox? node = this;
              switch (_direction) {
                case Axis.horizontal:
                  while (!node!.constraints.hasBoundedWidth &&
                      node.parent is RenderBox) {
                    node = node.parent! as RenderBox;
                  }
                  if (!node.constraints.hasBoundedWidth) {
                    node = null;
                  }
                case Axis.vertical:
                  while (!node!.constraints.hasBoundedHeight &&
                      node.parent is RenderBox) {
                    node = node.parent! as RenderBox;
                  }
                  if (!node.constraints.hasBoundedHeight) {
                    node = null;
                  }
              }
              if (node != null) {
                addendum.add(node.describeForError(
                    'The nearest ancestor providing an unbounded width constraint is'));
              }
            }
            addendum.add(ErrorHint(
                'See also: https://flutter.dev/unbounded-constraints'));
          } else {
            return true;
          }
          result = FlutterError.fromParts(<DiagnosticsNode>[
            error,
            message,
            ErrorDescription(
              'These two directives are mutually exclusive. If a parent is to shrink-wrap its child, the child '
              'cannot simultaneously expand to fit its parent.',
            ),
            ErrorHint(
              'Consider setting mainAxisSize to MainAxisSize.min and using FlexFit.loose fits for the flexible '
              'children (using Flexible rather than Expanded). This will allow the flexible children '
              'to size themselves to less than the infinite remaining space they would otherwise be '
              'forced to take, and then will cause the RenderFlex to shrink-wrap the children '
              'rather than expanding to fit the maximum constraints provided by the parent.',
            ),
            ErrorDescription(
              'If this message did not help you determine the problem, consider using debugDumpRenderTree():\n'
              '  https://flutter.dev/to/debug-render-layer\n'
              '  https://api.flutter.dev/flutter/rendering/debugDumpRenderTree.html',
            ),
            describeForError('The affected RenderFlex is',
                style: DiagnosticsTreeStyle.errorProperty),
            DiagnosticsProperty<dynamic>(
                'The creator information is set to', debugCreator,
                style: DiagnosticsTreeStyle.errorProperty),
            ...addendum,
            ErrorDescription(
              "If none of the above helps enough to fix this problem, please don't hesitate to file a bug:\n"
              '  https://github.com/flutter/flutter/issues/new?template=2_bug.yml',
            ),
          ]);
          return true;
        }
        child = childAfter(child);
      }
      return true;
    }());
    return result;
  }

  _LayoutSizes _computeSizes({
    required BoxConstraints constraints,
    required ChildLayouter layoutChild,
    required ChildBaselineGetter getBaseline,
  }) {
    assert(_debugHasNecessaryDirections);

    // Determine used flex factor, size inflexible items, calculate free space.
    final double maxMainSize = _getMainSize(constraints.biggest);
    final bool canFlex = maxMainSize.isFinite;
    final BoxConstraints nonFlexChildConstraints =
        _constraintsForNonFlexChild(constraints);
    // Null indicates the children are not baseline aligned.
    final TextBaseline? textBaseline = _isBaselineAligned
        ? (this.textBaseline ??
            (throw FlutterError(
                'To use CrossAxisAlignment.baseline, you must also specify which baseline to use using the "textBaseline" argument.')))
        : null;

    // The first pass lays out non-flex children and computes total flex.
    int totalFlex = 0;
    RenderBox? firstFlexChild;
    _AscentDescent accumulatedAscentDescent = _AscentDescent.none;
    // Initially, accumulatedSize is the sum of the spaces between children in the main axis.
    AxisSize accumulatedSize = AxisSize.fromSize(
        size: Size(spacing * (childCount - 1), 0.0), direction: direction);
    for (RenderBox? child = firstChild;
        child != null;
        child = childAfter(child)) {
      final int flex;
      if (canFlex && (flex = _getFlex(child)) > 0) {
        totalFlex += flex;
        firstFlexChild ??= child;
      } else {
        final AxisSize childSize = AxisSize.fromSize(
            size: layoutChild(child, nonFlexChildConstraints),
            direction: direction);
        accumulatedSize += childSize;
        // Baseline-aligned children contributes to the cross axis extent separately.
        final double? baselineOffset = textBaseline == null
            ? null
            : getBaseline(child, nonFlexChildConstraints, textBaseline);
        accumulatedAscentDescent += _AscentDescent(
            baselineOffset: baselineOffset,
            crossSize: childSize.crossAxisExtent);
      }
    }

    assert((totalFlex == 0) == (firstFlexChild == null));
    assert(firstFlexChild == null ||
        canFlex); // If we are given infinite space there's no need for this extra step.

    // The second pass distributes free space to flexible children.
    final double flexSpace =
        math.max(0.0, maxMainSize - accumulatedSize.mainAxisExtent);
    final double spacePerFlex = flexSpace / totalFlex;
    for (RenderBox? child = firstFlexChild;
        child != null && totalFlex > 0;
        child = childAfter(child)) {
      final int flex = _getFlex(child);
      if (flex == 0) {
        continue;
      }
      totalFlex -= flex;
      assert(spacePerFlex.isFinite);
      final double maxChildExtent = spacePerFlex * flex;
      assert(
          _getFit(child) == FlexFit.loose || maxChildExtent < double.infinity);
      final BoxConstraints childConstraints =
          _constraintsForFlexChild(child, constraints, maxChildExtent);
      final AxisSize childSize = AxisSize.fromSize(
          size: layoutChild(child, childConstraints), direction: direction);
      accumulatedSize += childSize;
      final double? baselineOffset = textBaseline == null
          ? null
          : getBaseline(child, childConstraints, textBaseline);
      accumulatedAscentDescent += _AscentDescent(
          baselineOffset: baselineOffset, crossSize: childSize.crossAxisExtent);
    }
    assert(totalFlex == 0);

    // The overall height of baseline-aligned children contributes to the cross axis extent.
    accumulatedSize += switch (accumulatedAscentDescent) {
      null => AxisSize.empty,
      (final double ascent, final double descent) =>
        AxisSize(mainAxisExtent: 0, crossAxisExtent: ascent + descent),
    };

    final double idealMainSize = switch (mainAxisSize) {
      MainAxisSize.max when maxMainSize.isFinite => maxMainSize,
      MainAxisSize.max || MainAxisSize.min => accumulatedSize.mainAxisExtent,
    };

    final AxisSize constrainedSize = AxisSize(
            mainAxisExtent: idealMainSize,
            crossAxisExtent: accumulatedSize.crossAxisExtent)
        .applyConstraints(constraints, direction);
    return _LayoutSizes(
      axisSize: constrainedSize,
      mainAxisFreeSpace:
          constrainedSize.mainAxisExtent - accumulatedSize.mainAxisExtent,
      baselineOffset: accumulatedAscentDescent.baselineOffset,
      spacePerFlex: firstFlexChild == null ? null : spacePerFlex,
    );
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    assert(() {
      final FlutterError? constraintsError = _debugCheckConstraints(
        constraints: constraints,
        reportParentConstraints: true,
      );
      if (constraintsError != null) {
        throw constraintsError;
      }
      return true;
    }());

    final _LayoutSizes sizes = _computeSizes(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
      getBaseline: ChildLayoutHelper.getBaseline,
    );

    final double crossAxisExtent = sizes.axisSize.crossAxisExtent;
    size = sizes.axisSize.toSize(direction);
    _overflow = math.max(0.0, -sizes.mainAxisFreeSpace);

    final double remainingSpace = math.max(0.0, sizes.mainAxisFreeSpace);
    final bool flipMainAxis = _flipMainAxis;
    final bool flipCrossAxis = _flipCrossAxis;
    final (double leadingSpace, double betweenSpace) = distributeSpace(
        mainAxisAlignment, remainingSpace, childCount, flipMainAxis, spacing);
    final (_NextChild nextChild, RenderBox? topLeftChild) =
        flipMainAxis ? (childBefore, lastChild) : (childAfter, firstChild);
    final double? baselineOffset = sizes.baselineOffset;
    assert(baselineOffset == null ||
        (crossAxisAlignment == CrossAxisAlignment.baseline &&
            direction == Axis.horizontal));

    // Position all children in visual order: starting from the top-left child and
    // work towards the child that's farthest away from the origin.
    double childMainPosition = leadingSpace;
    for (RenderBox? child = topLeftChild;
        child != null;
        child = nextChild(child)) {
      final double? childBaselineOffset;
      final bool baselineAlign = baselineOffset != null &&
          (childBaselineOffset =
                  child.getDistanceToBaseline(textBaseline!, onlyReal: true)) !=
              null;
      final double childCrossPosition = baselineAlign
          ? baselineOffset - childBaselineOffset!
          : _getChildCrossAxisOffset(crossAxisAlignment,
              crossAxisExtent - _getCrossSize(child.size), flipCrossAxis);
      final AnimatedFlexParentData childParentData =
          child.parentData! as AnimatedFlexParentData;
      childParentData.offset = switch (direction) {
        Axis.horizontal => Offset(childMainPosition, childCrossPosition),
        Axis.vertical => Offset(childCrossPosition, childMainPosition),
      };
      childMainPosition += _getMainSize(child.size) + betweenSpace;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hasOverflow) {
      defaultPaint(context, offset);
      return;
    }

    // There's no point in drawing the children if we're empty.
    if (size.isEmpty) {
      return;
    }

    _clipRectLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      defaultPaint,
      clipBehavior: clipBehavior,
      oldLayer: _clipRectLayer.layer,
    );

    assert(() {
      final List<DiagnosticsNode> debugOverflowHints = <DiagnosticsNode>[
        ErrorDescription(
          'The overflowing $runtimeType has an orientation of $_direction.',
        ),
        ErrorDescription(
          'The edge of the $runtimeType that is overflowing has been marked '
          'in the rendering with a yellow and black striped pattern. This is '
          'usually caused by the contents being too big for the $runtimeType.',
        ),
        ErrorHint(
          'Consider applying a flex factor (e.g. using an Expanded widget) to '
          'force the children of the $runtimeType to fit within the available '
          'space instead of being sized to their natural size.',
        ),
        ErrorHint(
          'This is considered an error condition because it indicates that there '
          'is content that cannot be seen. If the content is legitimately bigger '
          'than the available space, consider clipping it with a ClipRect widget '
          'before putting it in the flex, or using a scrollable container rather '
          'than a Flex, like a ListView.',
        ),
      ];

      // Simulate a child rect that overflows by the right amount. This child
      // rect is never used for drawing, just for determining the overflow
      // location and amount.
      final Rect overflowChildRect = switch (_direction) {
        Axis.horizontal => Rect.fromLTWH(0.0, 0.0, size.width + _overflow, 0.0),
        Axis.vertical => Rect.fromLTWH(0.0, 0.0, 0.0, size.height + _overflow),
      };
      paintOverflowIndicator(
          context, offset, Offset.zero & size, overflowChildRect,
          overflowHints: debugOverflowHints);
      return true;
    }());
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    switch (clipBehavior) {
      case Clip.none:
        return null;
      case Clip.hardEdge:
      case Clip.antiAlias:
      case Clip.antiAliasWithSaveLayer:
        return _hasOverflow ? Offset.zero & size : null;
    }
  }

  @override
  String toStringShort() {
    String header = super.toStringShort();
    if (!kReleaseMode) {
      if (_hasOverflow) {
        header += ' OVERFLOWING';
      }
    }
    return header;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis>('direction', direction));
    properties.add(EnumProperty<MainAxisAlignment>(
        'mainAxisAlignment', mainAxisAlignment));
    properties.add(EnumProperty<MainAxisSize>('mainAxisSize', mainAxisSize));
    properties.add(EnumProperty<CrossAxisAlignment>(
        'crossAxisAlignment', crossAxisAlignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(EnumProperty<VerticalDirection>(
        'verticalDirection', verticalDirection,
        defaultValue: null));
    properties.add(EnumProperty<TextBaseline>('textBaseline', textBaseline,
        defaultValue: null));
    properties.add(DoubleProperty('spacing', spacing, defaultValue: null));
  }
}

/// A widget that displays its children in a one-dimensional array.
///
/// The [AnimatedFlex] widget allows you to control the axis along which the children are
/// placed (horizontal or vertical). This is referred to as the _main axis_. If
/// you know the main axis in advance, then consider using a [Row] (if it's
/// horizontal) or [Column] (if it's vertical) instead, because that will be less
/// verbose.
///
/// To cause a child to expand to fill the available space in the [direction]
/// of this widget's main axis, wrap the child in an [Expanded] widget.
///
/// The [AnimatedFlex] widget does not scroll (and in general it is considered an error
/// to have more children in a [AnimatedFlex] than will fit in the available room). If
/// you have some widgets and want them to be able to scroll if there is
/// insufficient room, consider using a [ListView].
///
/// The [AnimatedFlex] widget does not allow its children to wrap across multiple
/// horizontal or vertical runs. For a widget that allows its children to wrap,
/// consider using the [Wrap] widget instead of [AnimatedFlex].
///
/// If you only have one child, then rather than using [AnimatedFlex], [Row], or
/// [Column], consider using [Align] or [Center] to position the child.
///
/// ## Layout algorithm
///
/// _This section describes how a [AnimatedFlex] is rendered by the framework._
/// _See [BoxConstraints] for an introduction to box layout models._
///
/// Layout for a [AnimatedFlex] proceeds in six steps:
///
/// 1. Layout each child with a null or zero flex factor (e.g., those that are
///    not [Expanded]) with unbounded main axis constraints and the incoming
///    cross axis constraints. If the [crossAxisAlignment] is
///    [CrossAxisAlignment.stretch], instead use tight cross axis constraints
///    that match the incoming max extent in the cross axis.
/// 2. Divide the remaining main axis space among the children with non-zero
///    flex factors (e.g., those that are [Expanded]) according to their flex
///    factor. For example, a child with a flex factor of 2.0 will receive twice
///    the amount of main axis space as a child with a flex factor of 1.0.
/// 3. Layout each of the remaining children with the same cross axis
///    constraints as in step 1, but instead of using unbounded main axis
///    constraints, use max axis constraints based on the amount of space
///    allocated in step 2. Children with [Flexible.fit] properties that are
///    [FlexFit.tight] are given tight constraints (i.e., forced to fill the
///    allocated space), and children with [Flexible.fit] properties that are
///    [FlexFit.loose] are given loose constraints (i.e., not forced to fill the
///    allocated space).
/// 4. The cross axis extent of the [AnimatedFlex] is the maximum cross axis extent of
///    the children (which will always satisfy the incoming constraints).
/// 5. The main axis extent of the [AnimatedFlex] is determined by the [mainAxisSize]
///    property. If the [mainAxisSize] property is [MainAxisSize.max], then the
///    main axis extent of the [AnimatedFlex] is the max extent of the incoming main
///    axis constraints. If the [mainAxisSize] property is [MainAxisSize.min],
///    then the main axis extent of the [AnimatedFlex] is the sum of the main axis
///    extents of the children (subject to the incoming constraints).
/// 6. Determine the position for each child according to the
///    [mainAxisAlignment] and the [crossAxisAlignment]. For example, if the
///    [mainAxisAlignment] is [MainAxisAlignment.spaceBetween], any main axis
///    space that has not been allocated to children is divided evenly and
///    placed between the children.
///
/// See also:
///
///  * [Row], for a version of this widget that is always horizontal.
///  * [Column], for a version of this widget that is always vertical.
///  * [Expanded], to indicate children that should take all the remaining room.
///  * [Flexible], to indicate children that should share the remaining room.
///  * [Spacer], a widget that takes up space proportional to its flex value.
///    that may be sized smaller (leaving some remaining room unused).
///  * [Wrap], for a widget that allows its children to wrap over multiple _runs_.
///  * The [catalog of layout widgets](https://flutter.dev/widgets/layout/).
class AnimatedFlex extends MultiChildRenderObjectWidget {
  /// Creates a flex layout.
  ///
  /// The [direction] is required.
  ///
  /// If [crossAxisAlignment] is [CrossAxisAlignment.baseline], then
  /// [textBaseline] must not be null.
  ///
  /// The [textDirection] argument defaults to the ambient [Directionality], if
  /// any. If there is no ambient directionality, and a text direction is going
  /// to be necessary to decide which direction to lay the children in or to
  /// disambiguate `start` or `end` values for the main or cross axis
  /// directions, the [textDirection] must not be null.
  const AnimatedFlex({
    super.key,
    required this.direction,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline, // NO DEFAULT: we don't know what the text's baseline should be
    this.clipBehavior = Clip.none,
    this.spacing = 0.0,
    super.children,
  }) : assert(
            !identical(crossAxisAlignment, CrossAxisAlignment.baseline) ||
                textBaseline != null,
            'textBaseline is required if you specify the crossAxisAlignment with CrossAxisAlignment.baseline');
  // Cannot use == in the assert above instead of identical because of https://github.com/dart-lang/language/issues/1811.

  /// The direction to use as the main axis.
  ///
  /// If you know the axis in advance, then consider using a [Row] (if it's
  /// horizontal) or [Column] (if it's vertical) instead of a [AnimatedFlex], since that
  /// will be less verbose. (For [Row] and [Column] this property is fixed to
  /// the appropriate axis.)
  final Axis direction;

  /// How the children should be placed along the main axis.
  ///
  /// For example, [MainAxisAlignment.start], the default, places the children
  /// at the start (i.e., the left for a [Row] or the top for a [Column]) of the
  /// main axis.
  final MainAxisAlignment mainAxisAlignment;

  /// How much space should be occupied in the main axis.
  ///
  /// After allocating space to children, there might be some remaining free
  /// space. This value controls whether to maximize or minimize the amount of
  /// free space, subject to the incoming layout constraints.
  ///
  /// If some children have a non-zero flex factors (and none have a fit of
  /// [FlexFit.loose]), they will expand to consume all the available space and
  /// there will be no remaining free space to maximize or minimize, making this
  /// value irrelevant to the final layout.
  final MainAxisSize mainAxisSize;

  /// How the children should be placed along the cross axis.
  ///
  /// For example, [CrossAxisAlignment.center], the default, centers the
  /// children in the cross axis (e.g., horizontally for a [Column]).
  ///
  /// When the cross axis is vertical (as for a [Row]) and the children
  /// contain text, consider using [CrossAxisAlignment.baseline] instead.
  /// This typically produces better visual results if the different children
  /// have text with different font metrics, for example because they differ in
  /// [TextStyle.fontSize] or other [TextStyle] properties, or because
  /// they use different fonts due to being written in different scripts.
  final CrossAxisAlignment crossAxisAlignment;

  /// Determines the order to lay children out horizontally and how to interpret
  /// `start` and `end` in the horizontal direction.
  ///
  /// Defaults to the ambient [Directionality].
  ///
  /// If [textDirection] is [TextDirection.rtl], then the direction in which
  /// text flows starts from right to left. Otherwise, if [textDirection] is
  /// [TextDirection.ltr], then the direction in which text flows starts from
  /// left to right.
  ///
  /// If the [direction] is [Axis.horizontal], this controls the order in which
  /// the children are positioned (left-to-right or right-to-left), and the
  /// meaning of the [mainAxisAlignment] property's [MainAxisAlignment.start] and
  /// [MainAxisAlignment.end] values.
  ///
  /// If the [direction] is [Axis.horizontal], and either the
  /// [mainAxisAlignment] is either [MainAxisAlignment.start] or
  /// [MainAxisAlignment.end], or there's more than one child, then the
  /// [textDirection] (or the ambient [Directionality]) must not be null.
  ///
  /// If the [direction] is [Axis.vertical], this controls the meaning of the
  /// [crossAxisAlignment] property's [CrossAxisAlignment.start] and
  /// [CrossAxisAlignment.end] values.
  ///
  /// If the [direction] is [Axis.vertical], and the [crossAxisAlignment] is
  /// either [CrossAxisAlignment.start] or [CrossAxisAlignment.end], then the
  /// [textDirection] (or the ambient [Directionality]) must not be null.
  final TextDirection? textDirection;

  /// Determines the order to lay children out vertically and how to interpret
  /// `start` and `end` in the vertical direction.
  ///
  /// Defaults to [VerticalDirection.down].
  ///
  /// If the [direction] is [Axis.vertical], this controls which order children
  /// are painted in (down or up), the meaning of the [mainAxisAlignment]
  /// property's [MainAxisAlignment.start] and [MainAxisAlignment.end] values.
  ///
  /// If the [direction] is [Axis.vertical], and either the [mainAxisAlignment]
  /// is either [MainAxisAlignment.start] or [MainAxisAlignment.end], or there's
  /// more than one child, then the [verticalDirection] must not be null.
  ///
  /// If the [direction] is [Axis.horizontal], this controls the meaning of the
  /// [crossAxisAlignment] property's [CrossAxisAlignment.start] and
  /// [CrossAxisAlignment.end] values.
  ///
  /// If the [direction] is [Axis.horizontal], and the [crossAxisAlignment] is
  /// either [CrossAxisAlignment.start] or [CrossAxisAlignment.end], then the
  /// [verticalDirection] must not be null.
  final VerticalDirection verticalDirection;

  /// If aligning items according to their baseline, which baseline to use.
  ///
  /// This must be set if using baseline alignment. There is no default because there is no
  /// way for the framework to know the correct baseline _a priori_.
  final TextBaseline? textBaseline;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.none].
  final Clip clipBehavior;

  /// {@macro flutter.rendering.RenderFlex.spacing}
  final double spacing;

  bool get _needTextDirection {
    switch (direction) {
      case Axis.horizontal:
        return true; // because it affects the layout order.
      case Axis.vertical:
        return crossAxisAlignment == CrossAxisAlignment.start ||
            crossAxisAlignment == CrossAxisAlignment.end;
    }
  }

  /// The value to pass to [AnimatedRenderFlex.textDirection].
  ///
  /// This value is derived from the [textDirection] property and the ambient
  /// [Directionality]. The value is null if there is no need to specify the
  /// text direction. In practice there's always a need to specify the direction
  /// except for vertical flexes (e.g. [Column]s) whose [crossAxisAlignment] is
  /// not dependent on the text direction (not `start` or `end`). In particular,
  /// a [Row] always needs a text direction because the text direction controls
  /// its layout order. (For [Column]s, the layout order is controlled by
  /// [verticalDirection], which is always specified as it does not depend on an
  /// inherited widget and defaults to [VerticalDirection.down].)
  ///
  /// This method exists so that subclasses of [AnimatedFlex] that create their own
  /// render objects that are derived from [AnimatedRenderFlex] can do so and still use
  /// the logic for providing a text direction only when it is necessary.
  @protected
  TextDirection? getEffectiveTextDirection(BuildContext context) {
    return textDirection ??
        (_needTextDirection ? Directionality.maybeOf(context) : null);
  }

  @override
  AnimatedRenderFlex createRenderObject(BuildContext context) {
    return AnimatedRenderFlex(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: getEffectiveTextDirection(context),
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      clipBehavior: clipBehavior,
      spacing: spacing,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant AnimatedRenderFlex renderObject) {
    renderObject
      ..direction = direction
      ..mainAxisAlignment = mainAxisAlignment
      ..mainAxisSize = mainAxisSize
      ..crossAxisAlignment = crossAxisAlignment
      ..textDirection = getEffectiveTextDirection(context)
      ..verticalDirection = verticalDirection
      ..textBaseline = textBaseline
      ..clipBehavior = clipBehavior
      ..spacing = spacing;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis>('direction', direction));
    properties.add(EnumProperty<MainAxisAlignment>(
        'mainAxisAlignment', mainAxisAlignment));
    properties.add(EnumProperty<MainAxisSize>('mainAxisSize', mainAxisSize,
        defaultValue: MainAxisSize.max));
    properties.add(EnumProperty<CrossAxisAlignment>(
        'crossAxisAlignment', crossAxisAlignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(EnumProperty<VerticalDirection>(
        'verticalDirection', verticalDirection,
        defaultValue: VerticalDirection.down));
    properties.add(EnumProperty<TextBaseline>('textBaseline', textBaseline,
        defaultValue: null));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior,
        defaultValue: Clip.none));
    properties.add(DoubleProperty('spacing', spacing, defaultValue: 0.0));
  }
}
