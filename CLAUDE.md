# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter package called `animated_containers` that provides animated alternatives to Flutter's layout widgets. The main components are:

- **AnimatedWrap**: A fully animated alternative to Flutter's `Wrap` widget with insertion, deletion, and reordering animations
- **AnimatedFlex/AnimatedRow/AnimatedColumn**: Animated alternatives to `Flex` widgets using `AnFlexible` instead of `Flexible`
- **RanimatedContainer**: A "ranimation" container that lays out immediately but animates visually, avoiding layout-per-frame issues
- **DynamicEaseInOutSimulation**: Custom animation simulation with smooth retargeting capabilities

## Development Commands

- **Lint**: `flutter analyze` or check `analysis_options.yaml` for linting rules
- **Test**: `flutter test` (run from package root)
- **Example app**: `cd example && flutter run` for main demo, `cd flex_example && flutter run` for flex demo
- **Package build**: `flutter packages pub publish --dry-run` to validate package

## Architecture

### Core Files
- `lib/animated_wrap.dart`: Main AnimatedWrap implementation with layout and animation logic
- `lib/animated_flex.dart`: AnimatedFlex implementation requiring AnFlexible wrappers
- `lib/ranimated_container.dart`: RanimatedContainer for immediate layout with visual lag
- `lib/retargetable_easers.dart`: DynamicEaseInOutSimulation and animation utilities
- `lib/util.dart`: Shared utilities
- `lib/animated_containers.dart`: Main library export file with default animation durations

### Animation System
The package uses a "ranimation" approach where layout happens immediately but visuals animate to catch up. This avoids layout-per-frame performance issues and allows immediate user interaction. The `DynamicEaseInOutSimulation` provides smooth retargeting when animations are interrupted.

### Material Design Integration
Default Material 3 animation durations and builders are provided. The package integrates with `circular_reveal_animation` for Material-style removal animations.

## Package Dependencies
- `flutter_animate: ^4.5.2`
- `circular_reveal_animation: ^2.0.1` (waiting for 2.0.2 update)

## Development Notes
- Uses Flutter's standard analysis options with `flutter_lints`
- Example apps demonstrate usage patterns in `example/lib/main.dart` and `flex_example/lib/main.dart`
- The package exports all public APIs through `lib/animated_containers.dart`