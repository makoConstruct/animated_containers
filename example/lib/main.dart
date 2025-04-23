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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
  final List<_WrapItem> _items = [];
  int _nextId = 0;
  final FocusNode _focusNode = FocusNode();
  int _insertButtonPressCount = 0;

  @override
  void initState() {
    super.initState();
    // Add initial items
    for (int i = 0; i < 14; i++) {
      _items.add(_createRandomItem());
    }
  }

  _WrapItem _createRandomItem() {
    final (Color, Color) colors = _getRandomColors(_random);
    final mid = _nextId++;
    return _WrapItem(
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8.0),
                  child: AnimatedWrap.material3(
                    spacing: 8,
                    runSpacing: 8,
                    children: _items.toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedWrap.material3(
                  alignment: AnimatedWrapAlignment.center,
                  runAlignment: AnimatedWrapAlignment.end,
                  crossAxisAlignment: AnimatedWrapCrossAlignment.end,
                  verticalDirection: VerticalDirection.up,
                  spacing: 11,
                  runSpacing: 11,
                  children: [
                    ElevatedButton(
                      key: const Key('insertOne'),
                      onPressed: _insertOneItem,
                      child: const Text('insert one'),
                    ),
                    ElevatedButton(
                      key: const Key('insertThree'),
                      onPressed: _insertThreeItems,
                      child: const Text('insert three'),
                    ),
                    ElevatedButton(
                      key: const Key('shiftOne'),
                      onPressed: _shiftOne,
                      child: const Text('shift one'),
                    ),
                    ElevatedButton(
                      key: const Key('swapFive'),
                      onPressed: () => _swapSome(3),
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

class _WrapItem extends StatelessWidget {
  final int id;
  final double width;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _WrapItem({
    super.key,
    required this.id,
    required this.width,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: width),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.hardEdge,
        // we use TouchRipple instead of InkWell because InkWell looks terrible and no one should use it.
        child: ourTouchRipple(
          onTap: onTap,
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
  required Widget child,
  required VoidCallback onTap,
}) =>
    TouchRipple(
      cancelBehavior: TouchRippleCancelBehavior.none,
      onTap: onTap,
      hoverColor: Colors.white.withAlpha(40),
      rippleColor: Colors.white.withAlpha(100),
      child: child,
    );
