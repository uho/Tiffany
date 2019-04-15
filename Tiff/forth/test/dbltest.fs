\ test some double primitives

\ fm/mod, sm/rem, um/mod, s>d, m*, um* already covered in coretest.fs

{ 0. 0 m+ -> 0. }
{ 0. 1 m+ -> 1. }
{ 0. -1 m+ -> -1. }
{ 1. -1 m+ -> 0. }
{ MAX-UINT 0 1 m+ -> 0 1 }
{ MAX-UINT MAX-UINT 1 m+ -> 0. }

{ 0. 0. d+ -> 0. }
{ 1. -1. d+ -> 0. }
{ -1. 1. d+ -> 0. }
{ -1. -1. d+ -> -2. }
{ MAX-UINT 0 2dup d+ -> MAX-UINT 1- 1 }
{ MAX-UINT 1 1 1 d+ -> 0 3 }

{ 0. 0. d- -> 0. }
{ 0. 1. d- -> -1. }
{ 0. -1. d- -> 1. }
{ 1. 0. d- -> 1. }
{ 1. 1. d- -> 0. }
{ -1. -1. d- -> 0. }
{ 1. -1. d- -> 2. }
{ -1. 1. d- -> -2. }
{ 0 2 1. d- -> MAX-UINT 1 }

{ 0. dnegate -> 0. }
{ 1. dnegate -> -1. }
{ -2. dnegate -> 2. }
{ 0 1 dnegate -> 0 -1 }
{ 1 1 dnegate -> MAX-UINT -2 }

{ 1. d2* -> 2. }
{ -10. d2* -> -20. }
{ MAX-UINT 1 d2* -> MAX-UINT 1- 3 }

{ 0. d2/ -> 0. }
{ 1. d2/ -> 0. }
{ -1. d2/ -> -1. }
{ MAX-UINT 3 d2/ -> MAX-UINT 1 }

{ 0. 0. d= -> true }
{ 0. 1. d= -> false }
{ 0 1 0 0 d= -> false }
{ 1 1 0 0 d= -> false }

{ 0. 0. d<> -> false }
{ 0. 1. d<> -> true }
{ 0 1 0 0 d<> -> true }
{ 1 1 0 0 d<> -> true }

{ 1. 1. d< -> false }
{ 0. 1. d< -> true }
{ 1 0 0 1 d< -> true }
{ 0 1 1 0 d< -> false }
{ -1. 0. d< -> true }

{ 1. 1. d> -> false }
{ 0. 1. d> -> false }
{ 1 0 0 1 d> -> false }
{ 0 1 1 0 d> -> true }
{ -1. 0. d> -> false }

{ 1. 1. d>= -> true }
{ 0. 1. d>= -> false }
{ 1 0 0 1 d>= -> false }
{ 0 1 1 0 d>= -> true }
{ -1. 0. d>= -> false }

{ 1. 1. d<= -> true }
{ 0. 1. d<= -> true }
{ 1 0 0 1 d<= -> true }
{ 0 1 1 0 d<= -> false }
{ -1. 0. d<= -> true }

\ Since the d-comparisons, the du-comparisons, and the d0-comparisons
\ are generated from the same source, we only test the ANS words in
\ the following.

{ 0. d0= -> true }
{ 1. d0= -> false }
{ 0 1 d0= -> false }
{ 1 1 d0= -> false }
{ -1. d0= -> false }

{ 0. d0< -> false }
{ -1. d0< -> true }
{ -1 0 d0< -> false }
{ 0 min-int d0< -> true }

{ 1. 1. du< -> false }
{ 0. 1. du< -> true }
{ 1 0 0 1 du< -> true }
{ 0 1 1 0 du< -> false }
{ -1. 0. du< -> false }

\ some M*/ consistency checks against */

{ -7. 3 5 M*/ -> -7 3 5 */ s>d }
{  7. 3 5 M*/ ->  7 3 5 */ s>d }
