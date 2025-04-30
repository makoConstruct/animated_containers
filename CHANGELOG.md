## 0.9.1


### AnimatedFlex completed with RanimatedContainer

I eventually accepted that having animated flex without animating size changes wasn't worth much. This was tough, but I thought up a way I'm not too unhappy with.

Layout animations inherently work in a different way from basic flutter animations, they can't run layout again and again, for obvious reasons, they have to let layout go through for real and then visually animate that change.

RanimatedContainer also does that, but for size changes of a Container. So on the layout level, its actual size changes immediately, but the background of the container will animate.

I initially went about this by trying to alter a lot of the RenderObjects that Container uses to make them animate, eventually it dawned on me that there wouldn't be much of a difference between that and just rendering a container behind the contents and animating it the traditional way, with a size cue from a simple widget `SizeChangeReporter(onSizeChange: Function (size), child: Widget)`.

And it seems to work well enough. I'm sure there'd be seams between the children, though.

It's also going to need the same alignment sensitivity that AnimatedWrap has. Currently it's top left anchored.

### AnimatedFlex Added

Making `AnFlexible` work was tricky! But I found a way!

### failed project: Attempting to use Animation<Offset>s with Simulations to drive layout animation.

I only realized right at the last moment that you can't animate layout on the widget level because the animation's response to the layout changes have to come through instantly, so you don't have time to generate a Transform.translate and wait for it to render, by that time, it'll render a glitch frame.

So they really can't be driven by animations.

### failed project: attempting to put flex in AnimationWrap:

Putting flex in AnimatedWrap was a bad idea. This is a failed branch. Here I'll document what happened.

I came in with an idealized conception of how flex layout would work. I spent a day hammering flutter's way of doing flex layout into my head. The next day, I was ready to implement, and I did, and it was going to work, but then I put it all together: This is useless.

Flutter's flex layout treats children with nonzero flex as if they have zero width in the initial layout pass. As a result, sometimes they'll be put in a line where they won't really fit, where non-flex children are taking up 99% of the space. They'll be forced to have an extremely small width, to be effectively invisible, the user wont know what's happening.

A way of salvaging this would be to have a minWidth parameter in the AnimatedWrap and in the `Flowable` wrapper (that would go around child elements, similar to Flex containers' `Flexible`) to override it. But at that point you admit that there isn't a lot of variability in the widths of the children.

If you have any real variability, the wrap will occasionally violate it by forcing the element into a position where it can't express that. A wrap, in flutter's layout process, cannot be fully responsive to the preference of the subjects.

It's such an introduction of complexity for a feature that few people would use. I have no plans to use it myself.

And the thing I really dislike about it is that it's going to require some way of animating item size changes. It implies that. Flex is further not all that compatible with Animation.

Should a framework exceed the needs of most of its users? I suppose so.

## 0.9.0

AnimatedWrap is here.