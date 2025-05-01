library animated_containers;

import 'dart:collection';

import 'package:animated_containers/animated_containers.dart';
import 'package:circular_reveal_animation/circular_reveal_animation.dart';
import 'package:flutter/material.dart';

// mostly copied from flutter's Wrap widget
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:animated_containers/retargetable_easers.dart';

import 'util.dart';

(double leadingSpace, double betweenSpace) distributeWrapSpace(
    WrapAlignment alignment,
    double freeSpace,
    double itemSpacing,
    int itemCount,
    bool flipped) {
  assert(itemCount > 0);
  return switch (alignment) {
    WrapAlignment.start => (flipped ? freeSpace : 0.0, itemSpacing),
    WrapAlignment.end => distributeWrapSpace(
        WrapAlignment.start, freeSpace, itemSpacing, itemCount, !flipped),
    WrapAlignment.spaceBetween when itemCount < 2 => distributeWrapSpace(
        WrapAlignment.start, freeSpace, itemSpacing, itemCount, flipped),
    WrapAlignment.center => (freeSpace / 2.0, itemSpacing),
    WrapAlignment.spaceBetween => (
        0,
        freeSpace / (itemCount - 1) + itemSpacing
      ),
    WrapAlignment.spaceAround => (
        freeSpace / itemCount / 2,
        freeSpace / itemCount + itemSpacing
      ),
    WrapAlignment.spaceEvenly => (
        freeSpace / (itemCount + 1),
        freeSpace / (itemCount + 1) + itemSpacing
      ),
  };
}

/// Who [AnimatedWrap] should align children within a run in the cross axis.
enum AnimatedWrapCrossAlignment {
  /// Place the children as close to the start of the run in the cross axis as
  /// possible.
  ///
  /// If this value is used in a horizontal direction, a [TextDirection] must be
  /// available to determine if the start is the left or the right.
  ///
  /// If this value is used in a vertical direction, a [VerticalDirection] must be
  /// available to determine if the start is the top or the bottom.
  start,

  /// Place the children as close to the end of the run in the cross axis as
  /// possible.
  ///
  /// If this value is used in a horizontal direction, a [TextDirection] must be
  /// available to determine if the end is the left or the right.
  ///
  /// If this value is used in a vertical direction, a [VerticalDirection] must be
  /// available to determine if the end is the top or the bottom.
  end,

  /// Place the children as close to the middle of the run in the cross axis as
  /// possible.
  center;

  // TODO(ianh): baseline.
  // this todo was inherited from Wrap. If you want to add baseline alignment, you might want to take inspiration from anything that might have been added to Wrap, but don't count on it, it's been missing for a while.

  AnimatedWrapCrossAlignment get _flipped => switch (this) {
        AnimatedWrapCrossAlignment.start => AnimatedWrapCrossAlignment.end,
        AnimatedWrapCrossAlignment.end => AnimatedWrapCrossAlignment.start,
        AnimatedWrapCrossAlignment.center => AnimatedWrapCrossAlignment.center,
      };

  double get _alignment => switch (this) {
        AnimatedWrapCrossAlignment.start => 0,
        AnimatedWrapCrossAlignment.end => 1,
        AnimatedWrapCrossAlignment.center => 0.5,
      };
}

class _RunMetrics {
  AxisSize axisSize = AxisSize.empty;
  int childCount = 0;
  RenderBox? leadingChild;
}

/// Parent data for use with [AnimatedWrapRender].
class AnimatedWrapParentData extends ContainerBoxParentData<RenderBox> {
  // todo: replace with:
  // Simulation? simulation;
  // Simulation Function(Offset position, Offset velocity)? simulationFactory;
  // which can be set via a Flowable
  Offset previousOffset = const Offset(double.nan, double.nan);
  Offset previousVelocity = const Offset(0, 0);
}

/// Displays its children in multiple horizontal or vertical runs.
///
/// A [AnimatedWrapRender] lays out each child and attempts to place the child adjacent
/// to the previous child in the main axis, given by [direction], leaving
/// [spacing] space in between. If there is not enough space to fit the child,
/// [AnimatedWrapRender] creates a new _run_ adjacent to the existing children in the
/// cross axis.
///
/// After all the children have been allocated to runs, the children within the
/// runs are positioned according to the [alignment] in the main axis and
/// according to the [crossAxisAlignment] in the cross axis.
///
/// The runs themselves are then positioned in the cross axis according to the
/// [runSpacing] and [runAlignment].
///
/// When children change position, they are smoothly animated if the movement
/// exceeds the [sensitivity] threshold.
class AnimatedWrapRender extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, AnimatedWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, AnimatedWrapParentData> {
  /// Creates a wrap render object.
  ///
  /// By default, the wrap layout is horizontal and both the children and the
  /// runs are aligned to the start.
  AnimatedWrapRender({
    List<RenderBox>? children,
    Axis direction = Axis.horizontal,
    WrapAlignment alignment = WrapAlignment.start,
    double spacing = 0.0,
    WrapAlignment runAlignment = WrapAlignment.start,
    double runSpacing = 0.0,
    AnimatedWrapCrossAlignment crossAxisAlignment =
        AnimatedWrapCrossAlignment.start,
    TextDirection? textDirection,
    VerticalDirection verticalDirection = VerticalDirection.down,
    Clip clipBehavior = Clip.none,
    required AnimationController animation,
    double sensitivity = 5.0,
    // Simulation Function(Offset position, Offset velocity)? moveSimulationConstructor,
  })  : _direction = direction,
        _alignment = alignment,
        _spacing = spacing,
        _runAlignment = runAlignment,
        _runSpacing = runSpacing,
        _crossAxisAlignment = crossAxisAlignment,
        _textDirection = textDirection,
        _verticalDirection = verticalDirection,
        _clipBehavior = clipBehavior,
        _animation = animation,
        _sensitivity = sensitivity {
    animation.addListener(() {
      markNeedsPaint();
    });
    addAll(children);
  }

  /// The direction to use as the main axis.
  ///
  /// For example, if [direction] is [Axis.horizontal], the default, the
  /// children are placed adjacent to one another in a horizontal run until the
  /// available horizontal space is consumed, at which point a subsequent
  /// children are placed in a new run vertically adjacent to the previous run.
  Axis get direction => _direction;
  Axis _direction;
  set direction(Axis value) {
    if (_direction == value) {
      return;
    }
    _direction = value;
    markNeedsLayout();
  }

  // Simulation Function(Offset position, Offset velocity)? moveSimulationConstructor;

  /// How the children within a run should be placed in the main axis.
  ///
  /// For example, if [alignment] is [WrapAlignment.center], the children in
  /// each run are grouped together in the center of their run in the main axis.
  ///
  /// Defaults to [WrapAlignment.start].
  ///
  /// See also:
  ///
  ///  * [runAlignment], which controls how the runs are placed relative to each
  ///    other in the cross axis.
  ///  * [crossAxisAlignment], which controls how the children within each run
  ///    are placed relative to each other in the cross axis.
  WrapAlignment get alignment => _alignment;
  WrapAlignment _alignment;
  set alignment(WrapAlignment value) {
    if (_alignment == value) {
      return;
    }
    _alignment = value;
    markNeedsLayout();
  }

  /// How much space to place between children in a run in the main axis.
  ///
  /// For example, if [spacing] is 10.0, the children will be spaced at least
  /// 10.0 logical pixels apart in the main axis.
  ///
  /// If there is additional free space in a run (e.g., because the wrap has a
  /// minimum size that is not filled or because some runs are longer than
  /// others), the additional free space will be allocated according to the
  /// [alignment].
  ///
  /// Defaults to 0.0.
  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (_spacing == value) {
      return;
    }
    _spacing = value;
    markNeedsLayout();
  }

  /// How the runs themselves should be placed in the cross axis.
  ///
  /// For example, if [runAlignment] is [WrapAlignment.center], the runs are
  /// grouped together in the center of the overall [RenderWrap] in the cross
  /// axis.
  ///
  /// Defaults to [WrapAlignment.start].
  ///
  /// See also:
  ///
  ///  * [alignment], which controls how the children within each run are placed
  ///    relative to each other in the main axis.
  ///  * [crossAxisAlignment], which controls how the children within each run
  ///    are placed relative to each other in the cross axis.
  WrapAlignment get runAlignment => _runAlignment;
  WrapAlignment _runAlignment;
  set runAlignment(WrapAlignment value) {
    if (_runAlignment == value) {
      return;
    }
    _runAlignment = value;
    markNeedsLayout();
  }

  /// How much space to place between the runs themselves in the cross axis.
  ///
  /// For example, if [runSpacing] is 10.0, the runs will be spaced at least
  /// 10.0 logical pixels apart in the cross axis.
  ///
  /// If there is additional free space in the overall [RenderWrap] (e.g.,
  /// because the wrap has a minimum size that is not filled), the additional
  /// free space will be allocated according to the [runAlignment].
  ///
  /// Defaults to 0.0.
  double get runSpacing => _runSpacing;
  double _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) {
      return;
    }
    _runSpacing = value;
    markNeedsLayout();
  }

  /// How the children within a run should be aligned relative to each other in
  /// the cross axis.
  ///
  /// For example, if this is set to [AnimatedWrapCrossAlignment.end], and the
  /// [direction] is [Axis.horizontal], then the children within each
  /// run will have their bottom edges aligned to the bottom edge of the run.
  ///
  /// Defaults to [AnimatedWrapCrossAlignment.start].
  ///
  /// See also:
  ///
  ///  * [alignment], which controls how the children within each run are placed
  ///    relative to each other in the main axis.
  ///  * [runAlignment], which controls how the runs are placed relative to each
  ///    other in the cross axis.
  AnimatedWrapCrossAlignment get crossAxisAlignment => _crossAxisAlignment;
  AnimatedWrapCrossAlignment _crossAxisAlignment;
  set crossAxisAlignment(AnimatedWrapCrossAlignment value) {
    if (_crossAxisAlignment == value) {
      return;
    }
    _crossAxisAlignment = value;
    markNeedsLayout();
  }

  /// Determines the order to lay children out horizontally and how to interpret
  /// `start` and `end` in the horizontal direction.
  ///
  /// If the [direction] is [Axis.horizontal], this controls the order in which
  /// children are positioned (left-to-right or right-to-left), and the meaning
  /// of the [alignment] property's [WrapAlignment.start] and
  /// [WrapAlignment.end] values.
  ///
  /// If the [direction] is [Axis.horizontal], and either the
  /// [alignment] is either [WrapAlignment.start] or [WrapAlignment.end], or
  /// there's more than one child, then the [textDirection] must not be null.
  ///
  /// If the [direction] is [Axis.vertical], this controls the order in
  /// which runs are positioned, the meaning of the [runAlignment] property's
  /// [WrapAlignment.start] and [WrapAlignment.end] values, as well as the
  /// [crossAxisAlignment] property's [AnimatedWrapCrossAlignment.start] and
  /// [AnimatedWrapCrossAlignment.end] values.
  ///
  /// If the [direction] is [Axis.vertical], and either the
  /// [runAlignment] is either [WrapAlignment.start] or [WrapAlignment.end], the
  /// [crossAxisAlignment] is either [AnimatedWrapCrossAlignment.start] or
  /// [AnimatedWrapCrossAlignment.end], or there's more than one child, then the
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
  /// are painted in (down or up), the meaning of the [alignment] property's
  /// [WrapAlignment.start] and [WrapAlignment.end] values.
  ///
  /// If the [direction] is [Axis.vertical], and either the [alignment]
  /// is either [WrapAlignment.start] or [WrapAlignment.end], or there's
  /// more than one child, then the [verticalDirection] must not be null.
  ///
  /// If the [direction] is [Axis.horizontal], this controls the order in which
  /// runs are positioned, the meaning of the [runAlignment] property's
  /// [WrapAlignment.start] and [WrapAlignment.end] values, as well as the
  /// [crossAxisAlignment] property's [AnimatedWrapCrossAlignment.start] and
  /// [AnimatedWrapCrossAlignment.end] values.
  ///
  /// If the [direction] is [Axis.horizontal], and either the
  /// [runAlignment] is either [WrapAlignment.start] or [WrapAlignment.end], the
  /// [crossAxisAlignment] is either [AnimatedWrapCrossAlignment.start] or
  /// [AnimatedWrapCrossAlignment.end], or there's more than one child, then the
  /// [verticalDirection] must not be null.
  VerticalDirection get verticalDirection => _verticalDirection;
  VerticalDirection _verticalDirection;
  set verticalDirection(VerticalDirection value) {
    if (_verticalDirection != value) {
      _verticalDirection = value;
      markNeedsLayout();
    }
  }

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

  bool get _debugHasNecessaryDirections {
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
    if (alignment == WrapAlignment.start || alignment == WrapAlignment.end) {
      switch (direction) {
        case Axis.horizontal:
          assert(textDirection != null,
              'Horizontal $runtimeType with alignment $alignment has a null textDirection, so the alignment cannot be resolved.');
        case Axis.vertical:
          break;
      }
    }
    if (runAlignment == WrapAlignment.start ||
        runAlignment == WrapAlignment.end) {
      switch (direction) {
        case Axis.horizontal:
          break;
        case Axis.vertical:
          assert(textDirection != null,
              'Vertical $runtimeType with runAlignment $runAlignment has a null textDirection, so the alignment cannot be resolved.');
      }
    }
    if (crossAxisAlignment == AnimatedWrapCrossAlignment.start ||
        crossAxisAlignment == AnimatedWrapCrossAlignment.end) {
      switch (direction) {
        case Axis.horizontal:
          break;
        case Axis.vertical:
          assert(textDirection != null,
              'Vertical $runtimeType with crossAxisAlignment $crossAxisAlignment has a null textDirection, so the alignment cannot be resolved.');
      }
    }
    return true;
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  // the only reason we have to store this is that we're ordinarily not allowed to access the size during performLayout until after we've written it. Not sure why. We need a previousSize for animation. Not because we animate size changes but because it lets us comensiate for probable offset changes. See the stuff we do with the given alignment in performLayout.
  Size? previousSize;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! AnimatedWrapParentData) {
      child.parentData = AnimatedWrapParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    switch (direction) {
      case Axis.horizontal:
        double width = 0.0;
        RenderBox? child = firstChild;
        while (child != null) {
          width = max(width, child.getMinIntrinsicWidth(double.infinity));
          child = childAfter(child);
        }
        return width;
      case Axis.vertical:
        return getDryLayout(BoxConstraints(maxHeight: height)).width;
    }
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    switch (direction) {
      case Axis.horizontal:
        double width = 0.0;
        RenderBox? child = firstChild;
        while (child != null) {
          width += child.getMaxIntrinsicWidth(double.infinity);
          child = childAfter(child);
        }
        return width;
      case Axis.vertical:
        return getDryLayout(BoxConstraints(maxHeight: height)).width;
    }
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    switch (direction) {
      case Axis.horizontal:
        return getDryLayout(BoxConstraints(maxWidth: width)).height;
      case Axis.vertical:
        double height = 0.0;
        RenderBox? child = firstChild;
        while (child != null) {
          height = max(height, child.getMinIntrinsicHeight(double.infinity));
          child = childAfter(child);
        }
        return height;
    }
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    switch (direction) {
      case Axis.horizontal:
        return getDryLayout(BoxConstraints(maxWidth: width)).height;
      case Axis.vertical:
        double height = 0.0;
        RenderBox? child = firstChild;
        while (child != null) {
          height += child.getMaxIntrinsicHeight(double.infinity);
          child = childAfter(child);
        }
        return height;
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  double _getMainAxisExtent(Size childSize) {
    return switch (direction) {
      Axis.horizontal => childSize.width,
      Axis.vertical => childSize.height,
    };
  }

  double _getCrossAxisExtent(Size childSize) {
    return switch (direction) {
      Axis.horizontal => childSize.height,
      Axis.vertical => childSize.width,
    };
  }

  Offset _getOffset(double mainAxisOffset, double crossAxisOffset) {
    return switch (direction) {
      Axis.horizontal => Offset(mainAxisOffset, crossAxisOffset),
      Axis.vertical => Offset(crossAxisOffset, mainAxisOffset),
    };
  }

  (bool flipHorizontal, bool flipVertical) get _areAxesFlipped {
    final bool flipHorizontal = switch (textDirection ?? TextDirection.ltr) {
      TextDirection.ltr => false,
      TextDirection.rtl => true,
    };
    final bool flipVertical = switch (verticalDirection) {
      VerticalDirection.down => false,
      VerticalDirection.up => true,
    };
    return switch (direction) {
      Axis.horizontal => (flipHorizontal, flipVertical),
      Axis.vertical => (flipVertical, flipHorizontal),
    };
  }

  @override
  double? computeDryBaseline(
      covariant BoxConstraints constraints, TextBaseline baseline) {
    if (firstChild == null) {
      return null;
    }
    final BoxConstraints childConstraints = switch (direction) {
      Axis.horizontal => BoxConstraints(maxWidth: constraints.maxWidth),
      Axis.vertical => BoxConstraints(maxHeight: constraints.maxHeight),
    };

    final (AxisSize childrenAxisSize, List<_RunMetrics> runMetrics) =
        _computeRuns(constraints, ChildLayoutHelper.dryLayoutChild);
    final AxisSize containerAxisSize =
        childrenAxisSize.applyConstraints(constraints, direction);

    BaselineOffset baselineOffset = BaselineOffset.noBaseline;
    void findHighestBaseline(Offset offset, RenderBox child) {
      baselineOffset = baselineOffset.minOf(
          BaselineOffset(child.getDryBaseline(childConstraints, baseline)) +
              offset.dy);
    }

    Size getChildSize(RenderBox child) => child.getDryLayout(childConstraints);
    _positionChildren(runMetrics, childrenAxisSize, containerAxisSize,
        findHighestBaseline, getChildSize);
    return baselineOffset.offset;
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _computeDryLayout(constraints);
  }

  Size _computeDryLayout(BoxConstraints constraints,
      [ChildLayouter layoutChild = ChildLayoutHelper.dryLayoutChild]) {
    final (BoxConstraints childConstraints, double mainAxisLimit) =
        switch (direction) {
      Axis.horizontal => (
          BoxConstraints(maxWidth: constraints.maxWidth),
          constraints.maxWidth
        ),
      Axis.vertical => (
          BoxConstraints(maxHeight: constraints.maxHeight),
          constraints.maxHeight
        ),
    };

    double mainAxisExtent = 0.0;
    double crossAxisExtent = 0.0;
    double runMainAxisExtent = 0.0;
    double runCrossAxisExtent = 0.0;
    int childCount = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final Size childSize = layoutChild(child, childConstraints);
      final double childMainAxisExtent = _getMainAxisExtent(childSize);
      final double childCrossAxisExtent = _getCrossAxisExtent(childSize);
      // There must be at least one child before we move on to the next run.
      if (childCount > 0 &&
          runMainAxisExtent + childMainAxisExtent + spacing > mainAxisLimit) {
        mainAxisExtent = max(mainAxisExtent, runMainAxisExtent);
        crossAxisExtent += runCrossAxisExtent + runSpacing;
        runMainAxisExtent = 0.0;
        runCrossAxisExtent = 0.0;
        childCount = 0;
      }
      runMainAxisExtent += childMainAxisExtent;
      runCrossAxisExtent = max(runCrossAxisExtent, childCrossAxisExtent);
      if (childCount > 0) {
        runMainAxisExtent += spacing;
      }
      childCount += 1;
      child = childAfter(child);
    }
    crossAxisExtent += runCrossAxisExtent;
    mainAxisExtent = max(mainAxisExtent, runMainAxisExtent);

    return constraints.constrain(switch (direction) {
      Axis.horizontal => Size(mainAxisExtent, crossAxisExtent),
      Axis.vertical => Size(crossAxisExtent, mainAxisExtent),
    });
  }

  static Size _getChildSize(RenderBox child) => child.size;
  static void _setChildPosition(Offset offset, RenderBox child) {
    (child.parentData! as AnimatedWrapParentData).offset = offset;
  }

  bool _hasVisualOverflow = false;

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    assert(_debugHasNecessaryDirections);
    if (firstChild == null) {
      size = constraints.smallest;
      _hasVisualOverflow = false;
      return;
    }

    final (AxisSize childrenAxisSize, List<_RunMetrics> runMetrics) =
        _computeRuns(constraints, ChildLayoutHelper.layoutChild);
    final AxisSize containerAxisSize =
        childrenAxisSize.applyConstraints(constraints, direction);
    size = containerAxisSize.toSize(direction);
    final AxisSize freeAxisSize = containerAxisSize - childrenAxisSize;
    _hasVisualOverflow =
        freeAxisSize.mainAxisExtent < 0.0 || freeAxisSize.crossAxisExtent < 0.0;

    // record positions prior to layout change for animation purposes
    bool needsAnimation = false;
    RenderBox? child = firstChild;
    final List<AnimatedWrapParentData> setAfterLayout =
        <AnimatedWrapParentData>[];
    while (child != null) {
      final cpd = child.parentData! as AnimatedWrapParentData;
      // wondering if we should use a simulator parameter here, but for now, we'll just use the one DynamicEaseInOutSimulation behavior directly.
      // to implement that, you'd need to store the simulation in the parentData. The Simulator type would have to be configured with a constructor that takes a position and a velocity and is called on initalizing the wrap item.
      // oh, you'll also have to get rid of _motionAnimation and _animation and continue calling for repaints until all simulations are `isDone`.
      if (!cpd.previousOffset.dx.isNaN) {
        final (Offset offset, Offset velocity) = easeValVelOffset(
          cpd.previousOffset,
          cpd.offset,
          0,
          1,
          _animation.value,
          cpd.previousVelocity,
        );
        cpd.previousOffset = offset;
        cpd.previousVelocity = velocity;
      } else {
        // has no previousPosition, so shouldn't animate, so we set these after layout
        setAfterLayout.add(cpd);
      }
      child = childAfter(child);
    }

    _positionChildren(runMetrics, freeAxisSize, containerAxisSize,
        _setChildPosition, _getChildSize);

    for (final cpd in setAfterLayout) {
      cpd.previousOffset = cpd.offset;
    }

    // correct the previousOffsets if needed:
    // we adjust previousOffsets depending on alignment if there was a size change. This makes it possible to prevent certain animation discontinuities. EG: If you had extra space on the right, but were then shortened, you would never expect the children to glitch to the left before animating back. Yet if you reverse the scene and do that (size change for a right-aligned wrap), that actually does happen! We address that here.
    if (previousSize != null && size != previousSize) {
      // we use the alignment to determine if we should move everything in train with the far horizontal boundary or the far vertical boundary. We considered using offset, (which would also aniamte movement within the parent), but that would create inconsistent behavior, since a child widget isn't always told when the offset changes.
      // move everything in train with the far horizontal boundary if appropriate
      if (direction == Axis.horizontal
          ? alignment == WrapAlignment.end
          : runAlignment == WrapAlignment.end) {
        var dx = size.width - (previousSize?.width ?? 0);
        for (RenderBox? child = firstChild;
            child != null;
            child = childAfter(child)) {
          final parentData = child.parentData! as AnimatedWrapParentData;
          parentData.previousOffset = parentData.previousOffset + Offset(dx, 0);
        }
      }
      // also handle center alignment
      if (direction == Axis.horizontal
          ? alignment == WrapAlignment.center
          : runAlignment == WrapAlignment.center) {
        final dx = size.width / 2 - (previousSize?.width ?? 0) / 2;
        for (RenderBox? child = firstChild;
            child != null;
            child = childAfter(child)) {
          final parentData = child.parentData! as AnimatedWrapParentData;
          parentData.previousOffset = parentData.previousOffset + Offset(dx, 0);
        }
      }
      // move everything in train with the far vertical boundary if appropriate
      if (direction == Axis.vertical
          ? alignment == WrapAlignment.end
          : runAlignment == WrapAlignment.end) {
        var dy = size.height - (previousSize?.height ?? 0);
        for (RenderBox? child = firstChild;
            child != null;
            child = childAfter(child)) {
          final parentData = child.parentData! as AnimatedWrapParentData;
          parentData.previousOffset = parentData.previousOffset + Offset(0, dy);
        }
      }
      // also handle vertical center alignment
      if (direction == Axis.vertical
          ? alignment == WrapAlignment.center
          : runAlignment == WrapAlignment.center) {
        final dy = size.height / 2 - (previousSize?.height ?? 0) / 2;
        for (RenderBox? child = firstChild;
            child != null;
            child = childAfter(child)) {
          final parentData = child.parentData! as AnimatedWrapParentData;
          parentData.previousOffset = parentData.previousOffset + Offset(0, dy);
        }
      }
      // and nothing special needs to be done if the horizontal or vertical alignment is start, and I don't think I'm going to handle spaceBetween or spaceEvenly
    }
    previousSize = size;

    /// check if we need to animate
    child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as AnimatedWrapParentData;

      if (!parentData.previousOffset.dx.isNaN) {
        if ((parentData.offset - parentData.previousOffset).distance >
            _sensitivity) {
          needsAnimation = true;
          break;
        }
      }
      child = childAfter(child);
    }

    if (needsAnimation) {
      _animation.forward(from: 0);
    }
  }

  // Look ahead, creates a new run if incorporating the child would exceed the allowed line width.
  (AxisSize childrenSize, List<_RunMetrics> runMetrics) _computeRuns(
      BoxConstraints constraints, ChildLayouter layoutChild) {
    final (BoxConstraints childConstraints, double mainAxisLimit) =
        switch (direction) {
      Axis.horizontal => (
          BoxConstraints(maxWidth: constraints.maxWidth),
          constraints.maxWidth
        ),
      Axis.vertical => (
          BoxConstraints(maxHeight: constraints.maxHeight),
          constraints.maxHeight
        ),
    };

    final (bool flipMainAxis, _) = _areAxesFlipped;
    final double spacing = this.spacing;

    final List<_RunMetrics> runMetrics = <_RunMetrics>[];
    _RunMetrics? currentRun;
    AxisSize childrenAxisSize = AxisSize.empty;

    void completeRun() {
      childrenAxisSize += currentRun!.axisSize.flipped;
    }

    void newRun(RenderBox child, AxisSize childSize) {
      currentRun = _RunMetrics();
      currentRun!.axisSize = childSize;
      currentRun!.leadingChild = child;
      currentRun!.childCount = 1;
      runMetrics.add(currentRun!);
    }

    for (RenderBox? child = firstChild;
        child != null;
        child = childAfter(child)) {
      final AxisSize childSize = AxisSize.fromSize(
          size: layoutChild(child, childConstraints), direction: direction);

      if (currentRun == null) {
        newRun(child, childSize);
      } else if (currentRun!.axisSize.mainAxisExtent +
              childSize.mainAxisExtent +
              spacing >
          mainAxisLimit + precisionErrorTolerance) {
        // if we've exceeded the main axis limit, complete the current run and start a new one
        completeRun();
        newRun(child, childSize);
      } else {
        currentRun!.axisSize +=
            childSize + AxisSize(mainAxisExtent: spacing, crossAxisExtent: 0.0);
        currentRun!.childCount += 1;
        // yeah it traverses them backwards in _positionChildren if flipMainAxis.
        currentRun!.leadingChild =
            flipMainAxis ? child : currentRun!.leadingChild ?? child;
      }
    }
    if (currentRun != null) {
      completeRun();
    }

    // distribute spacing between runs
    assert(runMetrics.isNotEmpty);
    final double totalRunSpacing = runSpacing * (runMetrics.length - 1);
    childrenAxisSize +=
        AxisSize(mainAxisExtent: totalRunSpacing, crossAxisExtent: 0.0) +
            currentRun!.axisSize.flipped;

    return (childrenAxisSize.flipped, runMetrics);
  }

  void _positionChildren(
      List<_RunMetrics> runMetrics,
      AxisSize freeAxisSize,
      AxisSize containerAxisSize,
      PositionChild positionChild,
      GetChildSize getChildSize) {
    assert(runMetrics.isNotEmpty);

    final double spacing = this.spacing;

    final double crossAxisFreeSpace = max(0.0, freeAxisSize.crossAxisExtent);

    final (bool flipMainAxis, bool flipCrossAxis) = _areAxesFlipped;
    final AnimatedWrapCrossAlignment effectiveCrossAlignment =
        flipCrossAxis ? crossAxisAlignment._flipped : crossAxisAlignment;

    final (double runLeadingSpace, double runBetweenSpace) =
        distributeWrapSpace(
      runAlignment,
      crossAxisFreeSpace,
      runSpacing,
      runMetrics.length,
      flipCrossAxis,
    );
    final NextChild nextChild = flipMainAxis ? childBefore : childAfter;

    double runCrossAxisOffset = runLeadingSpace;
    final Iterable<_RunMetrics> runs =
        flipCrossAxis ? runMetrics.reversed : runMetrics;
    for (final _RunMetrics run in runs) {
      final double runCrossAxisExtent = run.axisSize.crossAxisExtent;
      int childCount = run.childCount;

      final double mainAxisFreeSpace = max(
          0.0, containerAxisSize.mainAxisExtent - run.axisSize.mainAxisExtent);

      final (double childLeadingSpace, double childBetweenSpace) =
          distributeWrapSpace(
              alignment, mainAxisFreeSpace, spacing, childCount, flipMainAxis);

      double childMainAxisOffset = childLeadingSpace;

      for (RenderBox? child = run.leadingChild;
          child != null && childCount > 0;
          child = nextChild(child), childCount -= 1) {
        final AxisSize(
          mainAxisExtent: double childMainAxisExtent,
          crossAxisExtent: double childCrossAxisExtent
        ) = AxisSize.fromSize(size: getChildSize(child), direction: direction);
        final double childCrossAxisOffset = effectiveCrossAlignment._alignment *
            (runCrossAxisExtent - childCrossAxisExtent);
        positionChild(
            _getOffset(
                childMainAxisOffset, runCrossAxisOffset + childCrossAxisOffset),
            child);
        childMainAxisOffset += childMainAxisExtent + childBetweenSpace;
      }
      runCrossAxisOffset += runCrossAxisExtent + runBetweenSpace;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  void doPaint(PaintingContext context, Offset offset) {
    _clipRectLayer.layer = null;
    // Paint each child with its current animated position
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as AnimatedWrapParentData;
      final animatedOffset = !parentData.previousOffset.dx.isNaN
          ? easeOffset(
              parentData.previousOffset,
              parentData.offset,
              0,
              1,
              _animation.value,
              parentData.previousVelocity,
            )
          : parentData.offset;

      context.paintChild(child, offset + animatedOffset);
      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // TODO(ianh): move the debug flex overflow paint logic somewhere common so
    // it can be reused here
    if (_hasVisualOverflow && clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        doPaint,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      doPaint(context, offset);
    }
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis>('direction', direction));
    properties.add(EnumProperty<WrapAlignment>('alignment', alignment));
    properties.add(DoubleProperty('spacing', spacing));
    properties.add(EnumProperty<WrapAlignment>('runAlignment', runAlignment));
    properties.add(DoubleProperty('runSpacing', runSpacing));
    properties.add(DoubleProperty('crossAxisAlignment', runSpacing));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(EnumProperty<VerticalDirection>(
        'verticalDirection', verticalDirection,
        defaultValue: VerticalDirection.down));
  }

  // todo: the agent added this. so maybe we need to do something for new children, but this is clearly not it (super.adoptChild already setupParentDatas).
  // @override
  // void adoptChild(RenderObject child) {
  //   super.adoptChild(child);
  //   final parentData = child.parentData! as AnimatedWrapParentData;
  //   // We'll set the key when we create the render object instead
  //   if (child is RenderBox) {
  //     setupParentData(child);
  //   }
  // }

  AnimationController _animation;
  set animation(AnimationController value) {
    if (_animation == value) return;
    _animation = value;
    markNeedsPaint();
  }

  double _sensitivity;
  set sensitivity(double value) {
    if (_sensitivity == value) return;
    _sensitivity = value;
  }
}

/// An animated version of [Wrap] that smoothly transitions children when their positions change.
class AnimatedWrap extends StatefulWidget {
  /// Creates an animated wrap layout.
  const AnimatedWrap({
    super.key,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing = 0.0,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing = 0.0,
    this.crossAxisAlignment = AnimatedWrapCrossAlignment.start,
    this.textDirection = TextDirection.ltr,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    this.children = const <Widget>[],
    this.sensitivity = 5,
    this.movementDuration = defaultMoveAnimationDuration,
    this.removalDuration = defaultRemovalDuration,
    this.removalBuilder,
    this.insertionDuration = defaultInsertionDuration,
    this.insertionBuilder,
    this.staggeredInitialInsertionAnimation,
  });

  /// Has a bunch of nice defaults that I think fit well into material design 3.
  static AnimatedWrap material3({
    Key? key,
    Axis direction = Axis.horizontal,
    WrapAlignment alignment = WrapAlignment.start,
    double spacing = 0.0,
    WrapAlignment runAlignment = WrapAlignment.start,
    double runSpacing = 0.0,
    AnimatedWrapCrossAlignment crossAxisAlignment =
        AnimatedWrapCrossAlignment.start,
    TextDirection textDirection = TextDirection.ltr,
    VerticalDirection verticalDirection = VerticalDirection.down,
    Clip clipBehavior = Clip.none,
    List<Widget> children = const <Widget>[],
    double sensitivity = 5,
    Duration movementDuration = material3MoveAnimationDuration,
    Duration removalDuration = material3RemovalDuration,
    Widget Function(Widget child, Animation<double> controller)? removalBuilder,
    Duration insertionDuration = material3InsertionDuration,
    Widget Function(Widget child, Animation<double> controller)?
        insertionBuilder,
    Duration? staggeredInitialInsertionAnimation,
  }) =>
      AnimatedWrap(
        key: key,
        direction: direction,
        alignment: alignment,
        spacing: spacing,
        runAlignment: runAlignment,
        runSpacing: runSpacing,
        crossAxisAlignment: crossAxisAlignment,
        textDirection: textDirection,
        verticalDirection: verticalDirection,
        clipBehavior: clipBehavior,
        sensitivity: sensitivity,
        movementDuration: movementDuration,
        insertionDuration: insertionDuration,
        insertionBuilder: insertionBuilder ??
            (child, animation) {
              return CircularRevealAnimation(
                  animation: delayAnimation(animation,
                          by: insertionDuration -
                              material3InsertionDelayDuration,
                          total: insertionDuration)
                      .drive(CurveTween(curve: Curves.easeOut)),
                  child: child);
            },
        removalDuration: removalDuration,
        removalBuilder: removalBuilder ??
            (child, animation) {
              return CircularRevealAnimation(
                  animation: ReverseAnimation(animation)
                      .drive(CurveTween(curve: Curves.easeInCubic)),
                  child: child);
            },
        children: children,
      );

  /// The direction to use as the main axis.
  final Axis direction;

  /// How the children within a run should be placed in the main axis.
  final WrapAlignment alignment;

  /// How much space to place between children in a run in the main axis.
  final double spacing;

  /// How the runs themselves should be placed in the cross axis.
  final WrapAlignment runAlignment;

  /// How much space to place between the runs themselves in the cross axis.
  final double runSpacing;

  /// How the children within a run should be aligned relative to each other in
  /// the cross axis.
  final AnimatedWrapCrossAlignment crossAxisAlignment;

  /// Determines the order to lay children out horizontally and how to interpret
  /// `start` and `end` in the horizontal direction.
  final TextDirection? textDirection;

  /// Determines the order to lay children out vertically and how to interpret
  /// `start` and `end` in the vertical direction.
  final VerticalDirection verticalDirection;

  /// The content will be clipped (or not) according to this option.
  final Clip clipBehavior;

  /// The widgets below this widget in the tree.
  final List<Widget> children;

  /// The duration over which to animate changes in child positions.
  final Duration movementDuration;

  /// The builder that wraps widgets for removal animations.
  final Widget Function(Widget child, Animation<double> controller)?
      removalBuilder;

  /// The duration over which to animate the removal of children.
  final Duration? removalDuration;

  /// The minimum amount of movement required to trigger an animation.
  /// Movements smaller than this will happen instantly.
  final double sensitivity;

  /// The duration over which to animate the insertion of children.
  final Duration? insertionDuration;

  /// The builder that wraps widgets for insertion animations.
  final Widget Function(Widget child, Animation<double> controller)?
      insertionBuilder;

  /// When a widget goes from one line to another, if this is false, it just moves there in the obvious way, while if this is true, it wraps out from the right side of the previous line, into the next line (it gets rendered twice to acheive this visual effect). Surprisingly, this looks way more normal in many cases.
  // (doesn't work yet)
  final bool wrappingLineChangeAnimation = false;

  // /// Whether to animate the initial showing of the list.
  // final bool initialInsertAnimation;

  /// if non-null, we do an effect where the first children animate in with a cascade (the first one animates in immediately, the next one `staggeredInitialInsertionAnimation` later, etc.). Set this to zero if you just want stuff to animate in at the same time. Leave it as null if you don't want to run insertion animations for initial children.
  final Duration? staggeredInitialInsertionAnimation;

  @override
  State<AnimatedWrap> createState() => AnimatedWrapState();
}

class _Removal {
  final _AnimatedWrapItem item;
  final Rect rect;
  _Removal(this.item, this.rect);
}

class Insertion {
  final AnimationController controller;
  final Widget child;
  Insertion(this.controller, this.child);
}

Interval delayedCurve(
        {required Duration by,
        required Duration total,
        Curve curve = Curves.linear}) =>
    Interval(curve: curve, by.inMilliseconds / total.inMilliseconds, 1.0);

Animation<double> delayAnimation(Animation<double> animation,
        {required Duration by, required Duration total}) =>
    CurvedAnimation(
      parent: animation,
      curve: Interval(by.inMilliseconds / total.inMilliseconds, 1.0),
    );

/// returns an animation with duration [broader], but doesn't raise from 0 until [broader - duration], meaning that it will appear as if it runs for [duration] after a delay. We do it this way instead of specifying {delay, duration} because flutter requires the duration to have been decided generally before you receive an animation, so this ends up being more succinct/parametizable.
Animation<double> delayedAnimation(Animation<double> animation,
    {required Duration duration, required Duration within}) {
  final curve = Interval(
      (within.inMilliseconds - duration.inMilliseconds) / within.inMilliseconds,
      1.0);
  return CurvedAnimation(parent: animation, curve: curve);
}

class AnimatedWrapState extends State<AnimatedWrap>
    with TickerProviderStateMixin {
  late final AnimationController _moveAnimator = AnimationController(
    vsync: this,
    duration: widget.movementDuration,
  );
  late HashMap<Key, _AnimatedWrapItem> _childItems =
      HashMap<Key, _AnimatedWrapItem>();
  final GlobalKey _stackKey = GlobalKey();

  /// we keep another one so that we can default-initialize them if the user fails to supply one or the other.
  late final Widget Function(Widget, Animation<double>) _insertionBuilder;
  late final Duration _insertionDuration;
  late final Widget Function(Widget, Animation<double>) _removalBuilder;
  late final Duration _removalDuration;
  final List<_Removal> _removingChildren = [];
  @override
  void dispose() {
    for (final child in _childItems.values) {
      child.insertionController?.dispose();
      child.removalController?.dispose();
    }
    _moveAnimator.dispose();
    super.dispose();
  }

  void _requireKey(Widget child) {
    if (child.key == null) {
      throw Exception(
          "AnimatedWrap requires all children to have unique keys. We can't animate changes if we can't tell when a widget is new, removed, or moved, and to tell that, we need keys.");
    }
  }

  _AnimatedWrapItem _makeWrapFor(Widget child,
      {Duration delay = Duration.zero, bool duringInitState = false}) {
    if (widget.staggeredInitialInsertionAnimation != null) {
      _requireKey(child);
      final insertingController = AnimationController(
        vsync: this,
        duration: delay + _insertionDuration,
      );
      insertingController.forward();
      final removalController =
          AnimationController(duration: _removalDuration, vsync: this);
      return _AnimatedWrapItem(
        key: GlobalKey(),
        insertionController: insertingController,
        insertionAnimation: CurvedAnimation(
            parent: insertingController,
            curve: Interval(
                delay.inMilliseconds /
                    (delay.inMilliseconds + _insertionDuration.inMilliseconds),
                1.0)),
        removalController: removalController,
        removalAnimation: removalController,
        removalBuilder: _removalBuilder,
        insertingBuilder: _insertionBuilder,
        child: child,
      );
    } else {
      final removalController =
          AnimationController(duration: _removalDuration, vsync: this);
      final insertionController =
          AnimationController(duration: _insertionDuration, vsync: this);
      insertionController.forward();
      return _AnimatedWrapItem(
        key: GlobalKey(),
        insertionController: insertionController,
        insertionAnimation: insertionController,
        removalController: removalController,
        removalAnimation: removalController,
        insertingBuilder: _insertionBuilder,
        removalBuilder: _removalBuilder,
        child: child,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    assert(() {
      for (final child in widget.children) {
        if (child.key == null) {
          throw FlutterError('All children of AnimatedWrap must have keys.\n'
              'This is required for proper animation tracking when children are added, removed, or reordered.');
        }
      }
      return true;
    }());

    // provide defaults
    _insertionDuration = widget.insertionDuration ?? defaultInsertionDuration;
    _insertionBuilder = widget.insertionBuilder ??
        (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation.drive(CurveTween(curve: Curves.easeOut)),
              child: child,
            ));

    _removalBuilder = widget.removalBuilder ??
        (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation.drive(CurveTween(curve: Curves.easeOut)),
              child: child,
            ));
    _removalDuration = widget.removalDuration ?? defaultRemovalDuration;

    if (widget.staggeredInitialInsertionAnimation != null) {
      Duration cumulativeDelay = Duration.zero;
      for (final child in widget.children) {
        _childItems[child.key!] =
            _makeWrapFor(child, delay: cumulativeDelay, duringInitState: true);
        cumulativeDelay += widget.staggeredInitialInsertionAnimation!;
      }
    } else {
      for (final child in widget.children) {
        _childItems[child.key!] = _makeWrapFor(child, duringInitState: true);
      }
    }
  }

  void checkChildChanges(List<Widget> oldChildren, List<Widget> newChildren) {
    final previousChildItems = _childItems;
    _childItems = HashMap<Key, _AnimatedWrapItem>();
    for (final child in newChildren) {
      _requireKey(child);
      _childItems[child.key!] =
          previousChildItems[child.key] ?? _makeWrapFor(child);
    }

    // insertion animation logic is already handled in _makeWrapFor above, if needed.

    for (final child in oldChildren) {
      if (_removalBuilder != null && !_childItems.containsKey(child.key)) {
        _AnimatedWrapItem removing = previousChildItems[child.key]!;
        RenderBox? robj = (removing.key as GlobalKey)
            .currentContext
            ?.findRenderObject() as RenderBox?;
        Offset? o = robj?.localToGlobal(Offset.zero,
            ancestor: _stackKey.currentContext?.findRenderObject());
        Size? s = robj?.size;
        if (o != null && s != null) {
          removing.removalController?.forward();
          removing.removalController?.addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                _removingChildren.removeWhere((r) => r.item == removing);
              });
              removing.removalController?.dispose();
              removing.insertionController?.dispose();
            }
          });

          setState(() {
            _removingChildren.add(_Removal(removing, o & s));
          });
        } else {
          removing.removalController?.dispose();
          removing.insertionController?.dispose();
        }
      }
    }
    // and moves are handled by the render object
  }

  @override
  void didUpdateWidget(AnimatedWrap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.movementDuration != oldWidget.movementDuration) {
      _moveAnimator.duration = widget.movementDuration;
    }

    if (oldWidget.children != widget.children) {
      checkChildChanges(oldWidget.children, widget.children);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(key: _stackKey, children: [
      ..._removingChildren.map((_Removal e) {
        return Positioned(
          left: e.rect.left,
          top: e.rect.top,
          width: e.rect.width,
          height: e.rect.height,
          child: e.item,
        );
      }),
      _AnimatedWrapRender(
        direction: widget.direction,
        alignment: widget.alignment,
        spacing: widget.spacing,
        runAlignment: widget.runAlignment,
        runSpacing: widget.runSpacing,
        crossAxisAlignment: widget.crossAxisAlignment,
        textDirection: widget.textDirection,
        verticalDirection: widget.verticalDirection,
        clipBehavior: widget.clipBehavior,
        animation: _moveAnimator,
        sensitivity: widget.sensitivity,
        children: widget.children.map((e) => _childItems[e.key]!).toList(),
      ),
    ]);
  }
}

/// the items that're put into the AnimatedWrapRender, where the animations take place. We need it to be a separate widget so that we can find the renderobject when we're doing removal positionings.
class _AnimatedWrapItem extends StatelessWidget {
  /// The widget to be displayed.
  final Widget child;

  /// managed by AnmatedWrap
  /// The controller for the insertion animation. (null if the builder is null)
  final AnimationController? insertionController;

  /// The controller for the removal animation (null if the builder is null)
  final AnimationController? removalController;

  /// Generally just a cast of the insertion controller, sometimes augmented with a delay curve.
  final Animation<double> insertionAnimation;

  /// Generally just a cast of the removal controller, sometimes augmented with a delay curve.
  final Animation<double> removalAnimation;

  /// The builder that wraps this widget when it's being inserted.
  final Widget Function(Widget child, Animation<double> controller)
      insertingBuilder;

  /// The builder that wraps this widget when it's being removed.
  final Widget Function(Widget child, Animation<double> controller)
      removalBuilder;

  const _AnimatedWrapItem({
    required this.child,
    super.key,
    required this.insertingBuilder,
    required this.removalBuilder,
    this.insertionController,
    this.removalController,
    required this.insertionAnimation,
    required this.removalAnimation,
  });

  @override
  Widget build(BuildContext context) {
    // this mess is just, it uses the builder/controller if it's available, that's it, that's all.
    return removalBuilder(
        insertingBuilder(child, insertionAnimation), removalAnimation);
  }
}

class _AnimatedWrapRender extends MultiChildRenderObjectWidget {
  const _AnimatedWrapRender({
    required this.direction,
    required this.alignment,
    required this.spacing,
    required this.runAlignment,
    required this.runSpacing,
    required this.crossAxisAlignment,
    required this.textDirection,
    required this.verticalDirection,
    required this.clipBehavior,
    required this.animation,
    required this.sensitivity,
    required super.children,
  });

  final Axis direction;
  final WrapAlignment alignment;
  final double spacing;
  final WrapAlignment runAlignment;
  final double runSpacing;
  final AnimatedWrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;
  final AnimationController animation;
  final double sensitivity;

  @override
  AnimatedWrapRender createRenderObject(BuildContext context) {
    return AnimatedWrapRender(
      direction: direction,
      alignment: alignment,
      spacing: spacing,
      runAlignment: runAlignment,
      runSpacing: runSpacing,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
      animation: animation,
      sensitivity: sensitivity,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, AnimatedWrapRender renderObject) {
    renderObject
      ..direction = direction
      ..alignment = alignment
      ..spacing = spacing
      ..runAlignment = runAlignment
      ..runSpacing = runSpacing
      ..crossAxisAlignment = crossAxisAlignment
      ..textDirection = textDirection
      ..verticalDirection = verticalDirection
      ..clipBehavior = clipBehavior
      ..animation = animation
      ..sensitivity = sensitivity;
  }
}
