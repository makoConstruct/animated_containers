import 'dart:math';

import 'package:animated_layout/animated_layout.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    // Add initial items
    for (int i = 0; i < 40; i++) {
      _items.add(_createRandomItem());
    }
  }

  _WrapItem _createRandomItem() {
    final (Color, Color) colors = _getRandomColors(_random);
    final mid = _nextId++;
    return _WrapItem(
      id: mid,
      width: lengthDistribution[_random.nextInt(lengthDistribution.length)],
      backgroundColor: colors.$1,
      color: colors.$2,
      key: GlobalKey(),
      onTap: () => _removeItem(mid),
    );
  }

  void _removeItem(int id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });
  }

  void _addThreeItems() {
    setState(() {
      for (int i = 0; i < 3; i++) {
        final insertIndex = _random.nextInt(_items.length + 1);
        _items.insert(insertIndex, _createRandomItem());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnimatedWrap Demo'),
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              constraints: const BoxConstraints.expand(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedWrap(
                  wrappingLineChangeAnimation: true,
                  spacing: 8,
                  runSpacing: 8,
                  movementDuration: const Duration(milliseconds: 200),
                  insertionDuration: const Duration(milliseconds: 600),
                  insertionBuilder: (child, animation) => ScaleTransition(
                    scale: animation.drive(CurveTween(
                        curve: delayedCurve(const Duration(milliseconds: 400),
                            const Duration(milliseconds: 200),
                            curve: Curves.easeOut))),
                    child: child,
                  ),
                  removalDuration: const Duration(milliseconds: 200),
                  removalBuilder: (child, animation) => ScaleTransition(
                    scale: ReverseAnimation(animation)
                        .drive(CurveTween(curve: Curves.easeIn)),
                    child: child,
                  ),
                  children: _items.toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _addThreeItems,
                child: const Text('Add 3 Random Items'),
              ),
            ),
          ],
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
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
  (Color(0xffefafe8), Color(0xff670f5c)),
  (Color(0xffafe9ef), Color(0xff0b5359)),
  (Color(0xffefcaaf), Color(0xff5b3112)),
];
(Color, Color) _getRandomColors(Random random) {
  return colors[random.nextInt(colors.length)];
}

const List<double> lengthDistribution = [17.0, 35.0, 35.0, 60.0, 110.0];
