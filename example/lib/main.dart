import 'dart:math';

import 'package:animated_containers/animated_containers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _insertOneItem,
                      child: const Text('insert one'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _insertThreeItems,
                      child: const Text('insert three'),
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
  (Color.fromARGB(255, 240, 184, 233), Color(0xff670f5c)),
  (Color(0xffafe9ef), Color(0xff0b5359)),
  (Color(0xffefcaaf), Color(0xff5b3112)),
];

(Color, Color) _getRandomColors(Random random) {
  return colors[random.nextInt(colors.length)];
}

const List<double> lengthDistribution = [17.0, 35.0, 35.0, 60.0, 110.0];
