[![pub package](https://img.shields.io/pub/v/animated_containers.svg)](https://pub.dartlang.org/packages/animated_containers)

`AnimatedWrap` is a fully animated alternative to flutter's `Wrap` widget, where layout changes (reordering etc) animate. It also handles insertion and deletion animations.

We also provide `AnimatedFlex` (and an `AnimatedRow`, and `AnimatedColumn`). AnimatedFlex doesn't currently do size change animations the way you'd expect, but we offer another way of doing it, using "ranimated" widgets (currently just `RanimatedContainer`) which we think is arguably better than the idiomatic way.

## `AnimatedWrap`: Usage

Mostly mirrors [flutter's Wrap widget](https://api.flutter.dev/flutter/widgets/Wrap-class.html), but there are some other parameters worth explaining

```dart
AnimatedWrap.material3(
    Key? key,
    Axis direction = Axis.horizontal,
    WrapAlignment alignment = WrapAlignment.start,
    WrapAlignment runAlignment = WrapAlignment.start,
    WrapCrossAlignment crossAxisAlignment = WrapCrossAlignment.start,
    double spacing = 0.0,
    double runSpacing = 0.0,
    /// the direction the wrap flows in (doesn't actually affect text)
    TextDirection textDirection = TextDirection.ltr,
    VerticalDirection verticalDirection = VerticalDirection.down,
    /// the clip rect currently doesn't animate, so if you clip, be warned it
    /// may create a mild animation defect when downsizing.
    Clip clipBehavior = Clip.none,
    List<Widget> children = const <Widget>[],
    /// controls how far a widget must move  the animation activates for
    /// the given layout change (you'll probably never want to override
    /// the default)
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
    /// how the insertion animation is built from a newly inserted child
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

## `AnimatedFlex`

It's like a `Flex` widget, but you have to use `AnFlexible(flex: double, fit: FlexFit, child: Widget)` around your widget instead of a `Flexible`, and note that `AnFlexible` has to be there when the widget is inserted (it needs to be there even before your widget `build`s). We've been unable to replicate `Flexible`'s behavior due to the fact that we're inserting additional insert and removal animations between the item and the `AnimatedFlex` (*so the ParentDataWidget stuff can't reach the AnimatedFlexParentData. It's conceivable a custom parent data render object could go recursive and get there, I currently don't see a need.*)

## `RanimatedContainer`

A ranimation is an animation that lays out immediately as if it *already ran*, but where visuals lag behind. Ranimations have a number of advantages over the naive approach:

- It doesn't have to call layout every frame of the animation, it only lays out its contents and size once, like any other widget, and due to layout being fully resolved, it can plan the animation with knowledge of the final position. (*But also, you have to deal with retargeting if the user initiates another animation while the first is still ongoing.*)
- It can easily animate *in response to* layout changes (*conventional animations can't, because if they lay out every frame, every frame triggers the animation to start over again*), or can only animate in limited ways while making it often intractably awkward to do insertions and deletions and reorderings.
- Allows the user to immediately interact with the application as if the change had already completed, rather than having to wait for the animation to complete before the animated item becomes interactive or settles in the expected position. This also avoids some classes of app logic bug.

So, `RanimatedContainer` lays out like a regular `Container`, but still visually animates.

Caveat: It's only partly implemented. See its doc page for the details.

## DynamicEaseInOutSimulation

I want to highlight our DynamicEaseInOut motion simulation, which is currently used everywhere. It's using a rare approach where animation generally lands exactly on target at the required time, while never having any discontinuities in its velocity and still supporting smooth re-targeting when the animation is interrupted with a new animation target.

We'd like more motion simulations of this kind, though with variable duration, if you'd like. All they need to be able to do is implement `Simulation` (which can advance its position and velocity for a given timestep, and then mark itself done when it's reached its target and stopped) and a constructor/retarget method (which takes `prevPosition` `prevVelocity` and `targetPosition` and returns a new Simulation object).

## roadmap
- add `double? rudeHeightLimit` to AnimatedWrap. If the height of a child is greater than this, it'll be given a line of its own (*in text and text-like paragraphs, this looks nicer than having lines with mixed height contents*) (I need this for a tree editor/viewer)
- add `double? minRunHeight` to AnimatedWrap, which ensures that runs will always be at least this tall. (from baseline, ideally? Or if you're using CrossAxisAlignment.baseline, it's measured from baseline)
- add `double? maxRunHeight` to AnimatedWrap.
- add a `wrapFromRightToLeft` animation mode to `AnimatedWrap` where items wrap from going off-screen on the right to coming back in on the left instead of moving normally, as the normal way can be quite confusing, it'll look like things are moving around a lot when their index in the list hasn't changed.
    - this will need to distinguish swaps from other movements. Swaps shouldn't wrap, they should move the usual way, but they may *cause* other items to wrap. It's going to be a little complicated.

### help wanted, would love to see
- use a `Simulation` object + constructor (that takes `prevPosition` `prevVelocity` and `targetPosition`) to do motion instead of only supporting that one parabolic easer I made.
    - offer other default motion Simulations: eg, a bouncy one, or one that's similar to the very precise analytical one we have now but instead of assuming a fixed duration and finding the minimum acceleration that'll get there in that time, assumes a maximum rate of acceleration and finds the minimum duration to get there. Or one that's like smooth ease but where movement on the y axis is faster (it'll look more like a swoop). Or one where movement on the y axis uses a steeper ease curve.
    - now you can solve a minor bug where removal positioneds jump to their target position instantly (*you can see it when you delete a lot while movement animation is still ongoing*). To fix this, will need to be able to transfer the simulation to the removal Positioned, so this depends on the above (currently we're not using actual Simulation objects for motion. There's a note in the code with further advice for this. Ask me if you need more help).
    - support transfering animated children from one animated container to another? (It would have to have a globalkey of course). This is going to have complicated rules to deal with z-sorting and clipping. Maybe not possible without proper framework-level z-sorting?
        - But maybe you could have some sort of `TransferHostLayer` stack widget as an ancestor that you can temporarily place yourself into while the transfer is happening.
- Animate changes to the size of the clipping rect. (It should have the same behavior as the size change animation in [RanimatedContainer], that is, it should use alignment as a hint as to how to center the clip rect within or around itself. (as of the writing of this point, RanimatedContainer didn't have that yet, so also get RanimatedContainer while you're at it. For that matter, RanimatedContainer should also animate its clipping rect.))
- Consider allowing children without keys for those users who really just want size change layout animation (and not reordering or deletion and so on). We might actually not need to change much to get that to work. I'm just not sure there are a lot of people who need that but also don't use insert, remove or reorder animations.
- More conventional resize animations for flex items, as an option: `bool AnFlexible.shouldAnimateSize`.

### why we don't currently support flex sizing within a wrap

I just about implemented this (1f9e05), but on consideration, I don't see any usecases for it. I think it wouldn't make a lot of sense:

First, you'd need to impose a fairly tight limit on how wide or how short an item can be, since if you have no limit, items on orphan lines will often be freakishly wide, and if you have no lower limit, items will frequently be squished into a tiny sliver by their siblings. And if you're going to impose that sort of constraint, you're not getting any major practical benefits from having flex sizing.

I guess it could make sense in situations where there's supposed to be a lot of variability in item width, but those are rare. In common situations with variable width, eg, text, every item will request maximum width and get the entire run to itself, so it would stop being a wrap! Although... what about height-for-width sizing? (*the norm is width-for-height, where a width is given and the text widget decides its height on that basis. We could do layout differently!*)

Aesthetically, it means introducing fairly random size changes to elements, which usually look bad. See [the size change issue](https://github.com/flutter/flutter/issues/84948). Getting size changes right is difficult given the current state of UI animation programming. Even our Ranimation approach doesn't work perfectly for AnimatedFlex, as it will always create gaps between elements as the animation proceeds (sometimes this is fine of course, eg, reorderings, where theres's not really an alternative)