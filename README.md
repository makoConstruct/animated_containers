A fully animated wrap widget, where layout changes (internal movement, reordering, etc) animate. Also handles insertion and deletion animations.

## Usage

The main thing to know is that all child widgets must have keys. If all you want to animate is changes in the size of the AimatedWrap (then see roadmap), then we could make that work without needing keys, but if you want to animate insertions, removals, or reorderings — and you probably do — then of course we need to be able to identify the widgets with ids.

See doc comments/source code, but if you're just curious about the basics: There's a `AnimatedWrap.material3({List<Widget> children ...})` factory which creates an AnimatedWrap with default settings that I think fit in well enough with material design 3, which defaults to using a 400ms `movementDuration`, and an `insertionBuilder`/`removalBuilder` that animate insertions and removals with a CircularRevealAnimation (an expanding circular clip).

The constructor mostly mirrors [flutter's Wrap widget](https://api.flutter.dev/flutter/widgets/Wrap-class.html), but there are some other parameters with explaining

```dart
AnimatedWrap.material3(
    Key? key,
    Axis direction = Axis.horizontal,
    WrapAlignment alignment = WrapAlignment.start,
    double spacing = 0.0,
    WrapAlignment runAlignment = WrapAlignment.start,
    double runSpacing = 0.0,
    WrapCrossAlignment crossAxisAlignment = WrapCrossAlignment.start,
    TextDirection textDirection = TextDirection.ltr,
    VerticalDirection verticalDirection = VerticalDirection.down,
    Clip clipBehavior = Clip.none,
    List<Widget> children = const <Widget>[],
    /// controls how far a widget must move  the animation activates for
    /// the given layout change (you'll probably never want to override
    /// the default of 5 logical pixels)
    double sensitivity = 5,
    /// how long it takes for the widgets to move to their target positions
    /// when the layout changes
    Duration movementDuration = const Duration(milliseconds: 400),
    /// length of the animation of a widget that's in the process of
    /// disappearing because its source widget has been removed from
    /// `children`
    Duration removalDuration = const Duration(milliseconds: 280),
    /// when a widget is removed, the animated removal widget is built using
    /// this, given the removed child and a controller for the animation. For
    /// material3, It defaults to a shrinking circular clip
    Widget Function(Widget child, Animation<double> controller)? removalBuilder,
    /// length of the animation of a widget that's in the process of appearing
    Duration insertionDuration = const Duration(milliseconds: 500),
    /// how the insertion animation is built from the inserted child
    Widget Function(Widget child, Animation<double> controller)?
        insertionBuilder,
    /// when the widget first appears, should the items animate as if they'd
    /// just been inserted? If so (if non-null) should we do a fancy wave of
    /// insert animations by delaying each item's animation insertion slightly
    /// more than the last? If so, a non-zero value specifies the amount of
    /// delay added for each further item.
    Duration? staggeredInitialInsertionAnimation,
);
```

There's a nice example app at example/lib/main.dart

## roadmap
- ~~add flex functionality~~ create an animated flex container
- ~~given the above, we can make a very general "AnimatedFlex" container, and make AnimatedWrap a special case of AnimatedFlex.~~ this turned out to be unworkable and if workable, impractical.
- provide AnimatedColumn and AnimatedRow as a special case of AnimatedFlex, thereby fully addressing flutter's general lack of layout change animation.
- add `double? rudeHeightLimit` to AnimatedWrap. If the height of a child is greater than this, it'll be given a line of its own.
- add `double? minRunHeight` to AnimatedWrap, which ensures that runs will always be at least this tall.
- add an animation mode to AnimatedWrap where items wrap from going off-screen on the right to coming back in on the left instead of moving normally (at this point, AnimatedWrap will no longer be a special case of AnimatedFlex)

### help wanted, would love to see
- use a Simulation object + constructor (that takes a position and velocity) to do motion instead of only supporting the one parabolic easer I always use.
    - offer other default motion Simulations: eg, a bouncy one, or one that's similar to the very precise analytical one we have now but instead of assuming a fixed duration and finding the minimum acceleration that'll get there in that time, assumes a maximum rate of acceleration and finds the minimum duration to get there. Or one that's like smooth ease but where movement on the y axis is faster (it'll look more like a swoop). Or one where movement on the y axis uses a steeper ease curve (but I'm definitely not coding that one)
    - now you can solve a minor bug where removal positioneds jump to their target position instantly (*you can see it when you delete a lot while movement animation is still ongoing*). To fix this, will need to be able to transfer the simulation to the removal Positioned, so this depends on the above (currently we're not using actual Simulation objects for motion. There's a note in the code with further advice for this. Ask me if you need more help).
    - support transfering animated children from one animated container to another? (It would have to have a globalkey of course). This is going to have complicated rules to deal with z-sorting and clipping.
- Consider allowing children without keys for those users who just want size change layout aniation. We might actually not need to change much to get that to work. If you are a user who needs that, and doesn't also use insert, remove or reorder animations, say something, as I'm currently not sure whether yall actually exist.