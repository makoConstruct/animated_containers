import 'dart:math';
import 'dart:ui';

import 'package:animated_containers/animated_containers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_touch_ripple/components/touch_ripple_context.dart';
import 'package:flutter_touch_ripple/widgets/touch_ripple.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnimatedWrap Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 34, 34, 34)),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum DemoOrientation {
  normal,
  weird,
}

class _MyHomePageState extends State<MyHomePage> {
  final _random = Random();
  final List<_Item> _items = [];
  int _nextId = 0;
  final FocusNode _focusNode = FocusNode();
  int _insertButtonPressCount = 0;
  DemoOrientation _orientation = DemoOrientation.normal;
  @override
  void initState() {
    super.initState();
    // Add initial items
    for (int i = 0; i < 14; i++) {
      _items.add(_createRandomItem());
    }
  }

  // note, irl, you should probably use [FIC IList](https://pub.dev/packages/fast_immutable_collections#fast-immutable-collections)s instead of modifying a List like this. Doing it this way, we have to clone the list every time we build, which makes rebuilding a bit less efficient. But for a code example I'll just use the simple datastructure that everyone already has.
  _Item _createRandomItem() {
    final (Color, Color) colors = _getRandomColors(_random);
    final mid = _nextId++;
    return _Item(
      id: mid,
      key: ValueKey(mid),
      width: lengthDistribution[_random.nextInt(lengthDistribution.length)],
      backgroundColor: colors.$1,
      color: colors.$2,
      onTap: () => _removeItem(mid),
    );
  }

  void _removeItem(int id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });
  }

  void _insertThreeItems() {
    setState(() {
      for (int i = 0; i < 3; i++) {
        final insertIndex = _random.nextInt(_items.length + 1);
        _items.insert(insertIndex, _createRandomItem());
      }
    });
  }

  void _removeFirstItem() {
    if (_items.isNotEmpty) {
      setState(() {
        _items.removeAt(0);
      });
    }
  }

  void _insertOneItem() {
    setState(() {
      int insertPosition = 3 * _insertButtonPressCount;
      if (insertPosition >= _items.length) {
        _insertButtonPressCount = 0;
        insertPosition = 0;
      }
      _items.insert(insertPosition, _createRandomItem());
      _insertButtonPressCount++;
    });
  }

  void _shiftOne() {
    setState(() {
      final removed = _items.removeAt(_random.nextInt(_items.length));
      // +1 because after the end is a valid position too
      _items.insert(_random.nextInt(_items.length + 1), removed);
    });
  }

  void _swapSome(int nToSwap) {
    // don't swap more items than there are
    nToSwap = min(nToSwap, _items.length);
    setState(() {
      final indices = [];
      for (int i = 0; i < nToSwap; i++) {
        int ni;
        // ensure all indices are unique
        do {
          ni = _random.nextInt(_items.length);
        } while (indices.contains(ni));
        indices.add(ni);
      }
      // swap the items
      final temp = _items[indices[0]];
      for (int i = 0; i < nToSwap - 1; i++) {
        _items[indices[i]] = _items[indices[i + 1]];
      }
      _items[indices[nToSwap - 1]] = temp;
    });
  }

  void _resizeOne() {
    setState(() {
      final int index = _random.nextInt(_items.length);
      final _Item prev = _items[index];
      double width;
      // repeat until we get a new width
      do {
        width = lengthDistribution[_random.nextInt(lengthDistribution.length)];
      } while (prev.width == width);
      _items[index] = _Item(
        id: prev.id,
        key: prev.key,
        width: width,
        backgroundColor: prev.backgroundColor,
        color: prev.color,
        onTap: prev.onTap,
      );
    });
  }

  void _toggleOrientation() {
    setState(() {
      _orientation = _orientation == DemoOrientation.normal
          ? DemoOrientation.weird
          : DemoOrientation.normal;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('animated wrap'),
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              _removeFirstItem();
            } else if (event.logicalKey == LogicalKeyboardKey.digit1) {
              _insertOneItem();
            } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
              _insertThreeItems();
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              _swapSome(3);
            }
          }
        },
        autofocus: true,
        child: Container(
          constraints: const BoxConstraints.expand(),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                constraints: const BoxConstraints.expand(),
                child: switch (_orientation) {
                  DemoOrientation.normal => SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      padding: const EdgeInsets.all(8.0),
                      child: AnimatedWrap.material3(
                        spacing: 8,
                        // movementDuration: const Duration(milliseconds: 280),
                        runSpacing: 8,
                        staggeredInitialInsertionAnimation:
                            const Duration(milliseconds: 29),
                        children: _items.toList(),
                      ),
                    ),
                  DemoOrientation.weird => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      child: AnimatedWrap.material3(
                        direction: Axis.vertical,
                        alignment: WrapAlignment.start,
                        runAlignment: WrapAlignment.start,
                        crossAxisAlignment: AnimatedWrapCrossAlignment.start,
                        verticalDirection: VerticalDirection.up,
                        textDirection: TextDirection.rtl,
                        spacing: 2,
                        runSpacing: 14,
                        staggeredInitialInsertionAnimation:
                            const Duration(milliseconds: 29),
                        children: _items.toList(),
                      ),
                    )
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedWrap.material3(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.start,
                  verticalDirection: VerticalDirection.up,
                  spacing: 11,
                  runSpacing: 11,
                  children: [
                    ElevatedButton(
                      onPressed: _insertOneItem,
                      key: const ValueKey('insert one'),
                      child: const Text('insert one'),
                    ),
                    ElevatedButton(
                      onPressed: _insertThreeItems,
                      key: const ValueKey('insert three'),
                      child: const Text('insert three'),
                    ),
                    ElevatedButton(
                      onPressed: _shiftOne,
                      key: const ValueKey('shift one'),
                      child: const Text('shift one'),
                    ),
                    ElevatedButton(
                      onPressed: () => _swapSome(3),
                      key: const ValueKey('swap three'),
                      child: const Text('swap three'),
                    ),
                    ElevatedButton(
                      onPressed: () => _resizeOne(),
                      key: const ValueKey('resize one'),
                      child: const Text('resize one'),
                    ),
                    ElevatedButton(
                      onPressed: () => _toggleOrientation(),
                      key: const ValueKey('toggle orientation'),
                      child: Text(
                          'orientation: ${_orientation == DemoOrientation.normal ? 'normal' : 'weird'}'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// todo: delete this I guess :( it doesn't look as nice as the default button
class OurButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  static OurButton textKeyed(VoidCallback onPressed, String text) => OurButton(
        onPressed,
        text,
        key: ValueKey(text),
      );
  const OurButton(this.onPressed, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceDim,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: ourTouchRipple(
        onTap: onPressed,
        color: theme.colorScheme.onSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Text(text, style: theme.textTheme.bodyLarge),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final int id;
  final double width;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _Item({
    super.key,
    required this.id,
    required this.width,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RanimatedContainer(
      constraints: BoxConstraints(minWidth: width),
      animationDuration: material3MoveAnimationDuration,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ourTouchRipple(
        onTap: onTap,
        color: const Color.fromARGB(255, 255, 255, 255),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 8.0,
          ),
          child: Text(
            '$id',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

const colors = [
  (Color(0xffcfeca2), Color(0xff3f5a11)),
  (Color.fromARGB(255, 240, 184, 233), Color(0xff670f5c)),
  (Color(0xffafe9ef), Color(0xff0b5359)),
  (Color(0xffefcaaf), Color(0xff5b3112)),
];

(Color, Color) _getRandomColors(Random random) {
  return colors[random.nextInt(colors.length)];
}

const List<double> lengthDistribution = [17.0, 35.0, 35.0, 60.0, 110.0];

Color lightenColor(Color color, double amount) {
  return Color.fromARGB(
    (color.a * 255).toInt(),
    (clampDouble(color.r + (1 - color.r) * amount, 0, 1) * 255).toInt(),
    (clampDouble(color.g + (1 - color.g) * amount, 0, 1) * 255).toInt(),
    (clampDouble(color.b + (1 - color.b) * amount, 0, 1) * 255).toInt(),
  );
}

Interval delayedCurve(
        {required Duration by,
        required Duration total,
        Curve curve = Curves.linear}) =>
    Interval(curve: curve, by.inMilliseconds / total.inMilliseconds, 1.0);

Widget ourTouchRipple({
  Key? key,
  TouchRippleShape? shape,
  required Widget child,
  Color color = const Color.fromARGB(255, 255, 255, 255),
  required VoidCallback onTap,
}) =>
    TouchRipple(
      key: key,
      cancelBehavior: TouchRippleCancelBehavior.none,
      onTap: onTap,
      hoverColor: color.withAlpha(40),
      rippleColor: color.withAlpha(100),
      child: child,
    );
