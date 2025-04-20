A fully animated wrap widget.

A wrap widget where layout changes (internal movement, reordering, etc) animate.

Also handles insertion and deletion animations.

## roadmap
- [] add flex functionality (call it AnimatedFlex)
- [] add line count constraint
- [] provide animated Columns and Rows as a special case of AnimatedFlex (AnimatedWrap is already a special case of AnimatedFlex)
- [] add an animation mode to AnimatedWrap where items wrap from going off-screen on the right to coming back in on the left instead of moving normally (at this point, AnimatedWrap will no longer be a special case of AnimatedFlex)
