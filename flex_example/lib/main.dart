import 'dart:math';
import 'dart:ui';

import 'package:animated_containers/animated_containers.dart';
import 'package:animated_containers/animated_flex.dart';
import 'package:animated_containers/ranimated_container.dart';
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
      title: 'animated flex',
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

class _MyHomePageState extends State<MyHomePage> {
  final _random = Random();
  final List<Widget> _items = [];
  int _nextId = 0;
  final FocusNode _focusNode = FocusNode();
  int _insertButtonPressCount = 0;

  @override
  void initState() {
    super.initState();
    // Add initial items
    for (int i = 0; i < 7; i++) {
      _items.add(_createRandomItem());
    }
  }

  Widget _createRandomItem() {
    final (Color, Color) colors = _getRandomColors(_random);
    final mid = _nextId++;
    bool isExpandy = _random.nextDouble() > 0.3;
    final width =
        lengthDistribution[_random.nextInt(lengthDistribution.length)];
    return AnFlexible(
      key: ValueKey(mid),
      flex: isExpandy ? 1 : 0,
      fit: FlexFit.tight,
      child: RanimatedContainer(
        constraints: BoxConstraints(minWidth: width),
        animationDuration: AnimatedFlex.material3MoveAnimationDuration,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colors.$1,
        ),
        child: ourTouchRipple(
          onTap: () => _removeItem(mid),
          color: const Color.fromARGB(255, 255, 255, 255),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Text(
              '$mid',
              style: TextStyle(
                color: colors.$2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _removeItem(int id) {
    setState(() {
      _items.removeWhere((item) => item.key == ValueKey(id));
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

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('animated flex'),
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
                constraints: const BoxConstraints(
                    minHeight: double.infinity, maxWidth: 700),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8.0),
                  child: AnimatedFlex(
                    direction: Axis.horizontal,
                    spacing: 8,
                    children: _items.toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedWrap.material3(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.end,
                  crossAxisAlignment: AnimatedWrapCrossAlignment.end,
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

// todo: delete this I guess :(
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
