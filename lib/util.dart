import 'dart:math';

import 'package:flutter/material.dart';

typedef NextChild = RenderBox? Function(RenderBox child);
typedef PositionChild = void Function(Offset offset, RenderBox child);
typedef GetChildSize = Size Function(RenderBox child);
// A 2D vector that uses a [RenderWrap]'s main axis and cross axis as its first and second coordinate axes.
// It represents the same vector as (double mainAxisExtent, double crossAxisExtent).
extension type const AxisSize._(Size _size) {
  AxisSize({required double mainAxisExtent, required double crossAxisExtent})
      : this._(Size(mainAxisExtent, crossAxisExtent));
  AxisSize.fromSize({required Size size, required Axis direction})
      : this._(_convert(size, direction));

  static const AxisSize empty = AxisSize._(Size.zero);

  static Size _convert(Size size, Axis direction) {
    return switch (direction) {
      Axis.horizontal => size,
      Axis.vertical => size.flipped,
    };
  }

  double get mainAxisExtent => _size.width;
  double get crossAxisExtent => _size.height;

  Size toSize(Axis direction) => _convert(_size, direction);

  BoxConstraints toBoxConstraints(Axis direction, bool isTight) =>
      switch (direction) {
        Axis.horizontal => BoxConstraints(
            minWidth: isTight ? _size.width : 0.0,
            maxWidth: _size.width,
            minHeight: 0.0,
            maxHeight: _size.height,
          ),
        Axis.vertical => BoxConstraints(
            minWidth: 0.0,
            maxWidth: _size.width,
            minHeight: isTight ? _size.height : 0.0,
            maxHeight: _size.height,
          )
      };

  AxisSize applyConstraints(BoxConstraints constraints, Axis direction) {
    final BoxConstraints effectiveConstraints = switch (direction) {
      Axis.horizontal => constraints,
      Axis.vertical => constraints.flipped,
    };
    return AxisSize._(effectiveConstraints.constrain(_size));
  }

  AxisSize get flipped => AxisSize._(_size.flipped);
  AxisSize operator +(AxisSize other) => AxisSize._(Size(
      _size.width + other._size.width, max(_size.height, other._size.height)));
  AxisSize operator -(AxisSize other) => AxisSize._(
      Size(_size.width - other._size.width, _size.height - other._size.height));
}

(double leadingSpace, double betweenSpace) distributeSpace(
    MainAxisAlignment alignment,
    double freeSpace,
    int itemCount,
    bool flipped,
    double spacing) {
  assert(itemCount >= 0);
  return switch (alignment) {
    MainAxisAlignment.start => flipped ? (freeSpace, spacing) : (0.0, spacing),
    MainAxisAlignment.end => distributeSpace(
        MainAxisAlignment.start, freeSpace, itemCount, !flipped, spacing),
    MainAxisAlignment.spaceBetween when itemCount < 2 => distributeSpace(
        MainAxisAlignment.start, freeSpace, itemCount, flipped, spacing),
    MainAxisAlignment.spaceAround when itemCount == 0 => distributeSpace(
        MainAxisAlignment.start, freeSpace, itemCount, flipped, spacing),
    MainAxisAlignment.center => (freeSpace / 2.0, spacing),
    MainAxisAlignment.spaceBetween => (
        0.0,
        freeSpace / (itemCount - 1) + spacing
      ),
    MainAxisAlignment.spaceAround => (
        freeSpace / itemCount / 2,
        freeSpace / itemCount + spacing
      ),
    MainAxisAlignment.spaceEvenly => (
        freeSpace / (itemCount + 1),
        freeSpace / (itemCount + 1) + spacing
      ),
  };
}
