
flex stuff:

This was a bad idea. This is a failed branch. Here I'll document what happened.

I came in with an idealized conception of how flex layout would work. I spent a day hammering flutter's way of doing flex layout into my head. The next day, I was ready to implement, and I did, and it was going to work, but then I put it all together: This is useless.

Flutter's flex layout treats children with nonzero flex as if they have zero width in the initial layout pass. As a result, sometimes they'll be put in a line where they won't really fit, where non-flex children are taking up 99% of the space. They'll be forced to have an extremely small width, to be effectively invisible, the user wont know what's happening.

A way of salvaging this would be to have a minWidth parameter in the AnimatedWrap and in the `Flowable` wrapper (that would go around child elements, similar to Flex containers' `Flexible`) to override it. But at that point you admit that there isn't a lot of variability in the widths of the children.

If you have any real variability, the wrap will occasionally violate it by forcing the element into a position where it can't express that. A wrap, in flutter's layout process, cannot be fully responsive to the preference of the subjects.

It's such an introduction of complexity for a feature that few people would use. I have no plans to use it myself.

And the thing I really dislike about it is that it's going to require some way of animating item size changes. It implies that. Flex is further not all that compatible with Animation.

Should a framework exceed the needs of most of its users? I suppose so.

## 0.9.0

AnimatedWrap is here.