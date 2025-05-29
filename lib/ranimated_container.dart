// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:animated_containers/retargetable_easers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter/widgets.dart';

/// A [Container] but animates in a way that's well suited to layout animations. We can define "ranimation" as a way of implementing animation where the layout update is instant (where in a sense it has *already ran*), but where the visuals move to the new layout smoothly. It has many advantages:
/// - Doesn't have to call layout every frame of the animation
/// - Can animate layout changes (conventional animations can't, or can only animate it in limited ways while making it very awkward to work with)
/// - Allows the user to immediately interact with the application as if the change had completed, rather than having to wait for the animation to complete. This also avoids certain kinds of bugs.
/// - Allows the animation to plan its motion more intelligently because the target isn't constantly being changed.
/// shortcomings and bugs
/// there's some major todo here though:
/// - need to interpolate between decorations (using lerpTo methods)
/// - Animate changes to the clipping rect on size change, not just the decoration.
/// - Adjust the animation using alignment as a positioning cue as to how the origin of the RenderObject probably moved as a result of the size change.
/// - Also animate the offset of the contents. Ranimated objects can't animate their origins.
/// - Render decoration foreground in front of the child.
class RanimatedContainer extends StatefulWidget {
  /// Creates a widget that combines common painting, positioning, and sizing widgets.
  ///
  /// The `height` and `width` values include the padding.
  ///
  /// The `color` and `decoration` arguments cannot both be supplied, since
  /// it would potentially result in the decoration drawing over the background
  /// color. To supply a decoration with a color, use `decoration:
  /// BoxDecoration(color: color)`.
  RanimatedContainer({
    super.key,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    double? width,
    double? height,
    BoxConstraints? constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.child,
    this.clipBehavior = Clip.none,
    required this.animationDuration,
  })  : assert(margin == null || margin.isNonNegative),
        assert(padding == null || padding.isNonNegative),
        assert(decoration == null || decoration.debugAssertIsValid()),
        assert(constraints == null || constraints.debugAssertIsValid()),
        assert(decoration != null || clipBehavior == Clip.none),
        assert(
          color == null || decoration == null,
          'Cannot provide both a color and a decoration\n'
          'To provide both, use "decoration: BoxDecoration(color: color)".',
        ),
        constraints = (width != null || height != null)
            ? constraints?.tighten(width: width, height: height) ??
                BoxConstraints.tightFor(width: width, height: height)
            : constraints;

  /// The [child] contained by the container.
  ///
  /// If null, and if the [constraints] are unbounded or also null, the
  /// container will expand to fill all available space in its parent, unless
  /// the parent provides unbounded constraints, in which case the container
  /// will attempt to be as small as possible.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  /// Align the [child] within the container.
  ///
  /// If non-null, the container will expand to fill its parent and position its
  /// child within itself according to the given value. If the incoming
  /// constraints are unbounded, then the child will be shrink-wrapped instead.
  ///
  /// Ignored if [child] is null.
  ///
  /// See also:
  ///
  ///  * [Alignment], a class with convenient constants typically used to
  ///    specify an [AlignmentGeometry].
  ///  * [AlignmentDirectional], like [Alignment] for specifying alignments
  ///    relative to text direction.
  final AlignmentGeometry? alignment;

  /// Empty space to inscribe inside the [decoration]. The [child], if any, is
  /// placed inside this padding.
  ///
  /// This padding is in addition to any padding inherent in the [decoration];
  /// see [Decoration.padding].
  final EdgeInsetsGeometry? padding;

  /// The color to paint behind the [child].
  ///
  /// This property should be preferred when the background is a simple color.
  /// For other cases, such as gradients or images, use the [decoration]
  /// property.
  ///
  /// If the [decoration] is used, this property must be null. A background
  /// color may still be painted by the [decoration] even if this property is
  /// null.
  final Color? color;

  /// The decoration to paint behind the [child].
  ///
  /// Use the [color] property to specify a simple solid color.
  ///
  /// The [child] is not clipped to the decoration. To clip a child to the shape
  /// of a particular [ShapeDecoration], consider using a [ClipPath] widget.
  final Decoration? decoration;

  /// The decoration to paint in front of the [child].
  final Decoration? foregroundDecoration;

  /// Additional constraints to apply to the child.
  ///
  /// The constructor `width` and `height` arguments are combined with the
  /// `constraints` argument to set this property.
  ///
  /// The [padding] goes inside the constraints.
  final BoxConstraints? constraints;

  /// Empty space to surround the [decoration] and [child].
  final EdgeInsetsGeometry? margin;

  /// The transformation matrix to apply before painting the container.
  final Matrix4? transform;

  /// The alignment of the origin, relative to the size of the container, if [transform] is specified.
  ///
  /// When [transform] is null, the value of this property is ignored.
  ///
  /// See also:
  ///
  ///  * [Transform.alignment], which is set by this property.
  final AlignmentGeometry? transformAlignment;

  /// The clip behavior when [RanimatedContainer.decoration] is not null.
  ///
  /// Defaults to [Clip.none]. Must be [Clip.none] if [decoration] is null.
  ///
  /// If a clip is to be applied, the [Decoration.getClipPath] method
  /// for the provided decoration must return a clip path. (This is not
  /// supported by all decorations; the default implementation of that
  /// method throws an [UnsupportedError].)
  final Clip clipBehavior;

  final Duration animationDuration;

  @override
  State<RanimatedContainer> createState() => _RanimatedContainerState();
}

class _RanimatedContainerState extends State<RanimatedContainer>
    with TickerProviderStateMixin {
  late AnimationController _animation;
  late SmoothOffsetEaser _spanEaser;
  Offset get _spanEaserEndValue => Offset(
      (_spanEaser.simulationx as DynamicEaseInOutSimulation).endValue,
      (_spanEaser.simulationy as DynamicEaseInOutSimulation).endValue);

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _spanEaser =
        SmoothOffsetEaser(const Offset(double.nan, double.nan), duration: 1);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // floats a positioned container with all of the right decorations and so on behind, whose sizing follows along with the size of the child container
    return SizeChangeReporter(
        onSizeChange: (size) {
          if (size != _spanEaserEndValue) {
            setState(() {
              _spanEaser.target(Offset(size.width, size.height),
                  time: _animation.value);
              _animation.forward(from: 0);
            });
          }
        },
        child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              Offset size = _spanEaser.x(_animation.value);
              if (size.dx.isNaN || size.dy.isNaN) {
                // then this is the first render, so there'll be no animation, and we wouldn't know what size to animate to anyway, so just render as a normal container
                return Container(
                  alignment: widget.alignment,
                  padding: widget.padding,
                  color: widget.color,
                  decoration: widget.decoration,
                  foregroundDecoration: widget.foregroundDecoration,
                  constraints: widget.constraints,
                  margin: widget.margin,
                  transform: widget.transform,
                  transformAlignment: widget.transformAlignment,
                  clipBehavior: widget.clipBehavior,
                  child: widget.child,
                );
              } else {
                return Stack(
                    fit: StackFit.passthrough,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                          left: 0,
                          top: 0,
                          child: SizedBox(
                            width: 0,
                            height: 0,
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              maxWidth: size.dx,
                              maxHeight: size.dy,
                              child: Container(
                                color: widget.color,
                                padding: widget.padding,
                                decoration: widget.decoration,
                                foregroundDecoration:
                                    widget.foregroundDecoration,
                                margin: widget.margin,
                                transform: widget.transform,
                                transformAlignment: widget.transformAlignment,
                              ),
                            ),
                          )
                          // todo: interpolate from previous decoration
                          ),
                      Container(
                          constraints: widget.constraints,
                          alignment: widget.alignment,
                          padding: widget.padding,
                          clipBehavior: widget.clipBehavior,
                          transform: widget.transform,
                          transformAlignment: widget.transformAlignment,
                          margin: widget.margin,
                          child: widget.child),
                    ]);
              }
            }));
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AlignmentGeometry>(
        'alignment', widget.alignment,
        showName: false, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>(
        'padding', widget.padding,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Clip>(
        'clipBehavior', widget.clipBehavior,
        defaultValue: Clip.none));
    if (widget.color != null) {
      properties.add(DiagnosticsProperty<Color>('bg', widget.color));
    } else {
      properties.add(DiagnosticsProperty<Decoration>('bg', widget.decoration,
          defaultValue: null));
    }
    properties.add(DiagnosticsProperty<Decoration>(
        'fg', widget.foregroundDecoration,
        defaultValue: null));
    properties.add(DiagnosticsProperty<BoxConstraints>(
        'constraints', widget.constraints,
        defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>(
        'margin', widget.margin,
        defaultValue: null));
    properties
        .add(ObjectFlagProperty<Matrix4>.has('transform', widget.transform));
  }
}

/// A widget that reports the size of its child via a callback.
class SizeChangeReporter extends StatefulWidget {
  const SizeChangeReporter({
    super.key,
    required this.onSizeChange,
    required this.child,
  });

  /// Called whenever the size of the [child] changes.
  final ValueChanged<Size> onSizeChange;

  /// The widget whose size is being monitored.
  final Widget child;

  @override
  State<SizeChangeReporter> createState() => _SizeChangeReporterState();
}

class _SizeChangeReporterState extends State<SizeChangeReporter> {
  @override
  Widget build(BuildContext context) {
    return _RenderSizeChangeReporter(
      onSizeChange: widget.onSizeChange,
      child: widget.child,
    );
  }
}

class _RenderSizeChangeReporter extends SingleChildRenderObjectWidget {
  const _RenderSizeChangeReporter({
    required this.onSizeChange,
    required super.child,
  });

  final ValueChanged<Size> onSizeChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSizeChangeReporterBox(onSizeChange);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderSizeChangeReporterBox renderObject) {
    renderObject.onSizeChange = onSizeChange;
  }
}

class _RenderSizeChangeReporterBox extends RenderProxyBox {
  _RenderSizeChangeReporterBox(this.onSizeChange);

  ValueChanged<Size> onSizeChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _oldSize) {
      _oldSize = size;
      // Using addPostFrameCallback to avoid calling setState during build/layout phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSizeChange(size);
      });
    }
  }
}
