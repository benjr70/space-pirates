# Prior art: procedural spaceship interior generation

Research for [#3](https://github.com/benjr70/space-pirates/issues/3), feeding the
silhouette prototype ([#4](https://github.com/benjr70/space-pirates/issues/4)), the BSP
partitioning prototype ([#5](https://github.com/benjr70/space-pirates/issues/5)) and Hatch
placement ([#7](https://github.com/benjr70/space-pirates/issues/7)).

Audience is whoever writes those specs, not a general reader. Every section ends in
takeaways phrased as *for our generator, this suggests X*.

Trust labels used throughout:

- **[P]** primary — library source, the technique's canonical wiki page, a peer-reviewed
  paper, a textbook, or the generator author's own writing.
- **[M]** medium — a real, readable open-source generator by a hobbyist; a named dev's blog.
- **[L]** low — community wiki, forum, or a summary of a summary. Stated as low on purpose.

**Read the contradictions first.** [§4](#4-what-contradicts-or-complicates-the-settled-decisions)
is the highest-value part of this document; the three questions are answered above it.

---

## 1. BSP partitioning with a hard minimum room size

### 1.1 The canonical description

RogueBasin's *Basic BSP Dungeon generation* is the origin of essentially all the folklore
here, and it is the same author (Jice) as libtcod's implementation **[P]**
(<https://www.roguebasin.com/index.php/Basic_BSP_Dungeon_generation>):

> choose a random direction : horizontal or vertical splitting / choose a random position
> (x for vertical, y for horizontal) / split the dungeon into two sub-dungeons

> When choosing the splitting position, we have to take care not to be too close to the
> dungeon border. **We must be able to place a room inside each generated sub-dungeon.**

> **Different rules on the splitting position can result in homogeneous sub-dungeons
> (position between 0.45 and 0.55) or heterogeneous ones (position between 0.1 and 0.9).**
> We can also choose to use a deeper recursion level on some parts of the dungeon so that
> we get smaller rooms there.

Worth knowing: the widely-repeated **0.3–0.7 clamp is not from here**. RogueBasin's numbers
are 0.45–0.55 and 0.1–0.9. 0.3–0.7 appears independently in later implementations (§1.3).

### 1.2 Split axis

Three patterns, all attested.

**(a) Pure random axis.** RogueBasin, above. Herbert Wolverson's `bsp_interior.rs` does a
literal coin flip and always cuts at the exact midpoint **[P]**
(<https://github.com/amethyst/rustrogueliketutorial/blob/master/chapter-26-bsp-interiors/src/map_builders/bsp_interior.rs>):

```rust
let split = rng.roll_dice(1, 4);
if split <= 2 { /* Horizontal split */ } else { /* Vertical split */ }
```

**(b) Aspect-ratio-driven — split the longer axis once it gets too long.** The AS3 tutorial
code most `Leaf`/`splitLeaf` implementations descend from **[P]**
(<https://github.com/tutsplus/Using-BSP-Trees-to-Generate-Game-Maps/blob/master/src/Leaf.as>):

```actionscript
// if the width is >25% larger than height, we split vertically
// if the height is >25% larger than the width, we split horizontally
var splitH:Boolean = FlxG.random() > 0.5;
if (width > height && width / height >= 1.25) splitH = false;
else if (height > width && height / width >= 1.25) splitH = true;
```

The much-copied Python port keeps the 1.25 rule verbatim **[P]**
(<https://github.com/AtTheMatinee/dungeon-generation/blob/master/dungeonGenerationAlgorithms.py>).

**(c) libtcod — the most carefully engineered version, and worth copying wholesale.**
`TCOD_bsp_split_recursive`, verbatim **[P]**
(<https://github.com/libtcod/libtcod/blob/develop/src/libtcod/bsp_c.c>):

```c
if (nb == 0 || (node->w < 2 * minHSize && node->h < 2 * minVSize)) return;
/* promote square rooms */
if (node->h < 2 * minVSize || node->w > node->h * maxHRatio)
  horiz = false;
else if (node->w < 2 * minHSize || node->h > node->w * maxVRatio)
  horiz = true;
else
  horiz = (TCOD_random_get_int(randomizer, 0, 1) == 0);
if (horiz) {
  position = TCOD_random_get_int(randomizer, node->y + minVSize, node->y + node->h - minVSize);
} else {
  position = TCOD_random_get_int(randomizer, node->x + minHSize, node->x + node->w - minHSize);
}
```

Semantics the documentation does not spell out:

- `horizontal == true` means a *horizontal cutting line*, i.e. the node is sliced along y
  into top and bottom children. So `horiz` shortens **height**, `!horiz` shortens **width**.
- **`maxHRatio` is not a bound on output aspect ratio.** `node->w > node->h * maxHRatio`
  reads "this node is more than `maxHRatio`x wider than tall" and forces a vertical cut to
  *reduce the width*. It is a **negative-feedback controller** pushing leaves toward square —
  the source comment is literally `/* promote square rooms */`. A single split is not
  guaranteed to bring a child under the ratio; it only ever pushes in the correcting direction.
- **The min-size escape hatch shares the same branches.** `node->h < 2*minVSize` forces
  `horiz = false`; `node->w < 2*minHSize` forces `horiz = true`. Because min-size dominance
  and ratio dominance live in the same cascade, they can never disagree about the sign of the
  correction. This is the detail the tutsplus lineage gets wrong (§1.5, F5).
- `nb` is an independent **depth budget**, so the tree has at most `2^nb` leaves.
- libtcod's own sample passes **`1.5f, 1.5f`**, and shows the standard wall trick **[P]**
  (<https://github.com/libtcod/libtcod/blob/develop/samples/samples_c.c>):

```c
TCOD_bsp_split_recursive(
    bsp, NULL, bspDepth, minRoomSize + (roomWalls ? 1 : 0), minRoomSize + (roomWalls ? 1 : 0), 1.5f, 1.5f);
```

python-tcod's docstring is consistent but thin: *"max_horizontal_ratio: Prevent creating a
horizontal ratio more extreme than this."* **[P]**
(<https://python-tcod.readthedocs.io/en/latest/tcod/bsp.html>).

### 1.3 Split ratio and split position

Two genuinely different schemes, and they are **not** equivalent.

**(i) Min-size offset — sample uniformly over the legal interval, no ratio at all.** libtcod,
above: `position ∈ [edge + minSize, edge + extent - minSize]`, so both children clear the
minimum by construction. Same idea in the tutsplus lineage with `MIN_LEAF_SIZE = 6`,
`MAX_LEAF_SIZE = 20` **[P]**; the Python port uses `MIN_LEAF_SIZE = 10`, `ROOM_MIN_SIZE = 6`
**[P]**.

**(ii) Percentage-clamped ratio.**

| Ratio | Source |
| --- | --- |
| 0.45–0.55 (homogeneous), 0.1–0.9 (heterogeneous) | RogueBasin **[P]** |
| 0.30–0.70 | Jono Shields, Godot BSP generator **[M]** (<https://jonoshields.com/post/bsp-dungeon/>) |
| 0.30–0.60 *plus* a min-size clamp | `Grim-/MagicAndMyths` **[M]** |

The MagicAndMyths generator is the clearest ratio-first / clamp-second example **[M]**
(<https://github.com/Grim-/MagicAndMyths/blob/main/src/MagicAndMyths/MapGen/BSP/BspUtility.cs>):

```csharp
minSplitPosition = 0.3f,  maxSplitPosition = 0.6f,  minRoomSize = 10;
splitBufferRatio = 2f,    maxElongationRatio = 1.5f;
public int MinSplitBuffer => (int)(minRoomSize / splitBufferRatio);
public int MinSplittableDimension => (minRoomSize * 2) + (MinSplitBuffer * 2);
...
float splitRatio = Rand.Range(config.minSplitPosition, config.maxSplitPosition);
int split = rect.minX + (int)(rect.Width * splitRatio);
return Mathf.Clamp(split, rect.minX + minBuffer + config.minRoomSize,
                          rect.maxX - (minBuffer + config.minRoomSize));
```

Note the clamp **silently overrides the ratio**, which is exactly why the split must also be
gated on `MinSplittableDimension` beforehand — otherwise the clamp collapses to a single legal
position and every marginal node splits at the same place.

**(iii) Fixed 50/50.** Wolverson's interiors builder always cuts at `half_width`/`half_height`
**[P]**.

**The important distinction, because it decides one of our open questions.** Scheme (i)'s
*ratio* distribution depends on node size: a large node yields near-uniform ratios (slivers
possible), a barely-splittable node is forced toward 50/50. Scheme (ii)'s ratio distribution
is size-independent but needs its own min-size guard. Pick one deliberately rather than
sliding into a hybrid.

### 1.4 Stop condition

**Overwhelmingly "check before splitting, and refuse."** No primary implementation found
splits-then-discards or splits-then-merges.

| Implementation | Guard |
| --- | --- |
| libtcod **[P]** | `if (nb == 0 \|\| (node->w < 2*minHSize && node->h < 2*minVSize)) return;` — note the `&&`: it gives up only when *neither* axis is viable |
| tutsplus / AtTheMatinee **[P]** | `if (max <= MIN_LEAF_SIZE) return false;` — applied *after* the axis is chosen, which is a weaker guard (F5) |
| Wolverson interiors **[P]** | `if half_width > MIN_ROOM_SIZE { ... }`, `MIN_ROOM_SIZE = 8` |
| Wolverson BSP rooms **[P]** | `is_possible(candidate)` rejection over a 240-attempt budget |
| PCG Book ch.3 **[P]** | "A leaf node is not split any further if it is below a minimum size (we will consider a minimal width of w/4 and minimal height of h/4 for this example)" (<https://www.pcgbook.com/chapter03.pdf>) |

**Min room size vs. min node size vs. depth — three constants, and conflating them is the
usual bug.**

1. **Min node size** is what the splitter enforces: an axis is splittable when
   `extent >= 2 * minNodeSize`.
2. **Min room size** is smaller than min node size whenever the room is shrunk inside its
   leaf. tutsplus: `MIN_LEAF_SIZE = 6` but rooms are `randomNumber(3, width - 2)`.
   AtTheMatinee: leaf 10, room 6. libtcod's sample makes the relation explicit by passing
   `minRoomSize + 1` when walls are wanted.
3. **Depth** is an *independent additional cap*. Whichever binds first wins, and for typical
   parameters the size guard binds first — which is precisely why requested depth never equals
   observed room count (F3).

MagicAndMyths is the only source found that names the composite bound:
`MinSplittableDimension = (minRoomSize * 2) + (MinSplitBuffer * 2)` with
`MinSplitBuffer = minRoomSize / 2`, i.e. **you need roughly 3x the min room size on an axis
before that axis is splittable at all**, because it reserves wall buffer on both sides **[M]**.

### 1.5 Known failure modes

**F1 — degenerate slivers / extreme aspect ratios.** This is the failure `maxHRatio`/
`maxVRatio` exist to fix (`/* promote square rooms */`), and the 1.25 rule is the same fix
with a different constant **[P]**. Honest caveat: **no primary prose source names and analyses
the sliver problem.** The evidence is that every serious implementation ships a mitigation for
it.

**F2 — uniform "everything is the same box".** The PCG Book is the citation **[P]**
(<https://www.pcgbook.com/chapter03.pdf>): BSP "allows for a **very structured appearance** of
the dungeon"; the strict form "creates **very symmetric, 'square' dungeons**"; and even after
relaxing it so each cell holds a stochastically-sized room, "dungeons are still likely to be
**very neatly ordered**." Josh Ge (Cogmind) puts it more briefly — BSP produces "some of the
simplest and **most immediately recognizable** roguelike maps" **[P]**
(<https://www.gridsagegames.com/blog/2014/06/procedural-map-generation/>).

**This is the single most important finding for issue #5: the "generic floorplan" look we are
trying to escape is the documented default output of the exact algorithm we chose, in both of
its variants.**

**F3 — leaf count is a power-of-two-ish function of depth, so an exact room count is
unsatisfiable by depth alone.** `k` splits give exactly `k+1` leaves; uniform depth `d` gives
at most `2^d`. But the size guard truncates branches unevenly, so you get *some* number `<= 2^d`
that you cannot dial. The PCG Book's own worked example "is terminated with **7 leaf nodes**"
— not 4, not 8 **[P]**. A generator's docs put the practical version well: "Depth-4 tree at
full expansion = up to 16 leaves… Early termination… turns the node into a leaf instead of
splitting… most dungeons have 8–12 rooms depending on how the aspect checks fire" **[M]**
(<https://github.com/leereilly/gh-dungeons/blob/main/docs/dungeon-generation.md>).

**F4 — dead space.** Shrinking rooms inside their leaves (the standard F2 fix) buys variety at
the cost of unused area. Wolverson names the trade-off directly when introducing the *BSP
interiors* variant, which exists because it "makes most of the available space usable" compared
to traditional BSP dungeons — and he says it is suitable for **"castles or spaceships"** **[P]**
(<https://bfnightly.bracketproductions.com/rustbook/chapter_26.html>). That is our exact case,
and it argues for the interiors variant (rooms fill their leaves, no dead space) over the
classic variant (rooms shrink inside leaves).

**F5 — a real bug class in the most-copied guard.** tutsplus/AtTheMatinee choose the axis
first, then test only that axis:

```actionscript
var max:int = (splitH ? height : width) - Registry.MIN_LEAF_SIZE;
if (max <= Registry.MIN_LEAF_SIZE) return false;
```

A leaf that is perfectly splittable on the *other* axis is reported unsplittable purely because
of the coin flip. libtcod avoids this by folding the min-size test into the axis-selection
cascade. (The comparison of the two sources is the researcher's reading, not a claim either
author makes.)

**F6 — libtcod edge case, only if min sizes are asymmetric.** `TCOD_random_get_i` silently
swaps an inverted range (`SORT_MINMAX(min, max, int)`) **[P]**
(<https://github.com/libtcod/libtcod/blob/develop/src/libtcod/mersenne_c.c>). If the ratio
branch forces `horiz = false` on a node with `w < 2*minHSize`, the range inverts and the split
silently produces children *below* the minimum instead of erroring. Reaching it requires
`minHSize` and `minVSize` to differ substantially; with equal min sizes and ratio >= 1 it is
unreachable, which is why nobody hits it — libtcod's sample passes the same value for both.
**We do not have that luxury: our floor is 8 wide by 6 tall (§4.1), which is exactly the
asymmetric case.**

### 1.6 Remedies

| Remedy | Evidence |
| --- | --- |
| **Aspect-ratio-forced axis** | libtcod `1.5f` **[P]**; tutsplus 1.25 **[P]**; MagicAndMyths `maxElongationRatio = 1.5f` **[M]** |
| **Soft bias instead of a hard rule** — worth stealing | MagicAndMyths, outside the elongation band, biases rather than flipping fair: `return rect.Width > rect.Height ? Rand.Value < 0.6f : Rand.Value < 0.4f;` **[M]** |
| **Ratio clamping** | RogueBasin **[P]**; 0.3–0.7 **[M]**; 0.3–0.6 + clamp **[M]** |
| **Reject splits that breach the minimum** | Everything in §1.4 |
| **Retry with an attempt budget** | Wolverson's 240-attempt rejection loop **[P]** |
| **Adaptive relaxation of the minimum** | MagicAndMyths trades the hard minimum away, down to 50%, rather than miss the count: `float adaptiveMultiplier = Math.Max(0.5f, 1f - (attempts * 0.01f));` **[M]**. Recorded so we can *reject* it — our floor is enforced by a test. |
| **Shrinking the room inside its leaf** | RogueBasin, PCG Book, tutsplus, backdrifting.net **[P/M]** |
| **Non-uniform split distributions** | libtcod gets this free: `TCOD_random_get_int` dispatches on the RNG's configured distribution, so `TCOD_DISTRIBUTION_GAUSSIAN` biases splits toward centre and the `_INVERSE` variants toward the edges **[P]** (<https://github.com/libtcod/libtcod/blob/develop/src/libtcod/mersenne_c.c>). The coupling is real in the source but **undocumented** — no article recommends it. Available lever, unproven. |
| **Non-uniform depth** | RogueBasin: "use a deeper recursion level on some parts of the dungeon" **[P]** |
| **Prune leaves you don't want** | MagicAndMyths shuffles leaves, tags keepers, `PruneUnmarkedLeafNodes(rootNode)` **[M]** |
| **Post-pass merging of undersized leaves** | **No source found.** Searches surfaced only merging of *overlapping rooms* into organic shapes, a different technique. **[L] — treat as untested folklore.** |

Two authors specifically looked for have **nothing** on BSP, verified rather than assumed: Bob
Nystrom's *Rooms and Mazes* does not discuss BSP at all, and Amit Patel reaches a minimum room
size by a completely different route — "Parallel bfs to expand these slightly so that they all
have a minimum room size" **[P]** (<https://www.redblobgames.com/x/2043-bfs-dungeons/>). Cite
them as alternatives, not as BSP sources.

### 1.7 Hitting an exact room count

**Yes, one real generator does it, and it is close to the obvious guess — but it is not a
documented technique.** No article, wiki page, textbook or talk describes it.

`Grim-/MagicAndMyths` does it in three stages **[M]**:

1. **Overshoot with depth**, sized from the target:
   `int initialMaxDepth = (int)Math.Ceiling(Math.Log(targetRoomCount, 2)) + 1;`
2. **If short, greedily split the largest splittable leaf, one split at a time** — the
   priority-queue idea, implemented as a linear scan over `node.rect.Area`, with a depth budget
   of exactly 1 per iteration and `maxSplitAttempts: 400`. It is **not guaranteed** to reach the
   target: it logs `"Could only generate {n} rooms out of {target} desired"` and returns short.
3. **If over, prune down**: shuffle the leaves, `Take(mainRoomCount)`, tag, prune the rest.

The **structurally correct version**, which follows directly from "`k` splits ⇒ `k+1` leaves"
but which no source writes down: seed a max-heap with the root and pop-split-push exactly
`N-1` times, refusing pops that cannot legally split. That gives exactly `N` leaves whenever
the area permits, with no depth parameter at all, and largest-first ordering keeps leaf sizes
even. **This is a derivation, not a citation.** The closest published thing is the PCG Book's
iterative formulation, which picks a leaf **at random** rather than by size and stops on min
size rather than on a count: "in every iteration a leaf node is chosen at random and split
along a randomly chosen vertical or horizontal line" **[P]**. Largest-leaf + count-stop is a
one-line change to a textbook algorithm, which is probably why nobody wrote it up.

Hard ceiling worth stating in the spec: with a hard minimum, `floor(area / minArea)` bounds
room count absolutely, and no retry budget beats it.

### 1.8 For our generator, this suggests

1. **Copy libtcod's axis cascade, not the tutsplus one.** Fold the min-size test into
   axis selection (`h < 2*minV` forces one axis, `w < 2*minH` forces the other, ratio forces
   otherwise, coin flip last) and stop only when *neither* axis is viable. This avoids F5 for
   free and gives ratio control and min-size safety from a single piece of logic.
2. **Choose scheme (i) or (ii) explicitly and write down why.** Recommendation: scheme (i)
   (min-size-offset sampling), because it makes the hard floor structural rather than a clamp
   that can silently override the ratio — and our floor is test-enforced, so structural is
   worth more than distributional prettiness.
3. **Use the BSP *interiors* variant, not classic BSP.** Wolverson says outright it "makes
   most of the available space usable" and names "castles or spaceships" as its use case **[P]**.
   Rooms fill their leaves; the one-tile gap between siblings is the shared wall, which is
   already our convention (`scripts/data/room_data.gd`). Classic BSP's shrink-inside-the-leaf
   produces dead space we have no use for inside a hull.
4. **Do not promise an exact room count from a depth parameter.** Use the largest-leaf
   pop-split-push loop for exactly `N-1` splits, and let it return short. Issue #2 already has
   the graceful-degradation story — mandatory Roles are satisfied first, so a short partition
   still yields a legal ship.
5. **Set the elongation ratio deliberately, around 1.5.** Note it interacts with our floor:
   8x6 is already an aspect ratio of 1.33, so at the floor the two constraints nearly coincide.
   At our real room sizes (100–200 tiles) there is room for both.
6. **Reject adaptive relaxation of the minimum.** MagicAndMyths trades the floor away to hit a
   count; `tests/test_layouts.gd` will fail us for that. Prefer returning short.
7. **Beware F6.** Our min sizes are asymmetric (8 vs 6) — the exact configuration in which
   libtcod's inverted-range bug becomes reachable. If we port that cascade, assert the sampling
   range is non-empty rather than trusting the RNG to clamp.

---

## 2. Making a partitioned space read as a designed vessel

### 2.1 The "everything looks like the same box" problem has a canonical name

Kate Compton, *So you want to build a generator…* (2016) **[P]**
(<https://galaxykate0.tumblr.com/post/139774965871/so-you-want-to-build-a-generator>; tumblr is
flaky, archival PDF at
<https://golancourses.net/2022f/wp-content/uploads/2022/09/kate-compton-oatmeal.pdf>):

> I like to call this problem the 10,000 Bowls of Oatmeal problem. I can easily generate 10,000
> bowls of plain oatmeal, with each oat being in a different position and different orientation,
> and mathematically speaking they will all be completely unique. But the user will likely just
> see a lot of oatmeal. **Perceptual uniqueness is the real metric, and it's darn tough.**

She splits the goal into two bars, and the second is the one that matters here:

> **Perceptual differentiation** is the feeling that this piece of content is not identical to
> the last. … **Perceptual uniqueness** is much more difficult. It is the difference between
> being an actor being a face in a crowd scene and a character that is memorable. … **Not
> everyone can be a main character. Instead many artifacts can [be] drab background noise,
> highlighting the few characterful artifacts.**

Her proposed mechanism:

> Humans seem to like perceiving **evidence of process and forces**, like the pushed up soil at
> the base of a tree, or the grass growing in the shelter of a gravestone. These
> structurally-generated subtleties suggest to us that **there is an alive world behind this
> object**. Kevin Lynch's influential 'Image of the City' demonstrates that there are factors
> that make cities memorable and describable.

Three things worth flagging because the essay is routinely mis-cited:

- Compton does **not** say "add more variety." She says most content is *supposed* to be
  background, and the design work is picking the few artifacts that carry character. That is an
  argument for a small number of landmark rooms on a bed of ordinary ones — the exact structure
  issue #2 already reached with its "one or two oversized Cargo holds as a landmark" rule.
- **"Evidence of process and forces" is the mechanism.** The layout should look *caused* — by a
  hull shape, by a power plant aft, by a crew that has to walk somewhere — not sampled.
- Compton herself hands off to Lynch, which is the bridge to §2.4.

A useful formalisation of *why* oatmeal is cheap: *Why Oatmeal is Cheap: Kolmogorov Complexity
and Procedural Generation* **[P]** (<https://arxiv.org/pdf/2305.02131>) argues perceived value
tracks *compressed description length* to a human observer, not raw entropy. Framing worth
keeping: our generator's real output is the sentence a player would use to describe the ship
("narrow nose, fat middle, engines out back"). **If two seeds compress to the same sentence,
they are the same ship**, however different their tile arrays.

### 2.2 Silhouette and hull shaping

**This is the thinnest evidence area in the whole document.** No published postmortem from a
shipped game documents "compose a hull from stacked bilaterally-symmetric sections."

**Extrusion along a spine** is the closest documented analogue. Michael Davies' Blender
*SpaceshipGenerator* is the most-cited open procedural ship generator, algorithm documented by
the author **[P]** (<https://github.com/a1studmuffin/SpaceshipGenerator>): start from a box,
**repeatedly extrude the front/rear faces with random translate/scale/rotate per step**, then
classify faces by orientation and attach engines to rear-facing faces, antennae/turrets to
top faces, then greeble. Two things transfer:

- The hull is a **sequence of sections along a single axis** where each cross-section is a
  scaled/perturbed version of the previous one. Our narrow-fore/wide-mid/medium-aft is the same
  idea with three hand-tuned steps. **Its variety comes from continuity plus perturbation along
  the spine, not from independent sections** — which is a hint about §4.5.
- **Function is attached to the silhouette after the fact, by face orientation.** Engines go on
  rear-facing faces *because* they are rear-facing. Cheap and robust; the interior analogue is
  assigning Roles by which hull section and which hull face a room touches.

**No Man's Sky** composes ships from interchangeable parts on weighted part tables — the same
pipeline as its creatures — per Hello Games' GDC talk *Building Worlds Using Math(s)* **[P/S]**
(<https://www.gdcvault.com/play/1024514/Building-Worlds-Using>) and the shipped-data analysis
**[S]** (<https://www.gamedeveloper.com/programming/what-the-code-of-i-no-man-s-sky-i-says-about-procedural-generation>).
It is the canonical cautionary tale: NMS is the thing that got called "18 quintillion bowls of
oatmeal" in review **[S]** (<https://www.vice.com/en/article/nz7d8q/no-mans-sky-review>).
Part-swapping on a fixed skeleton clears perceptual *differentiation* and misses perceptual
*uniqueness*.

**Comparative evidence on which hull-composition method reads better: none found.** Anyone
claiming stacked sections beat spine growth is asserting taste. Issue #4 is right to settle it
by prototype rather than by argument.

### 2.3 Bilateral symmetry: readability aid or monotony risk?

Both are documented, and the two strongest sources point in **opposite directions**. This is the
most useful tension found.

**For.** Liapis, Yannakakis & Togelius evolved 2D game spaceships using fitness functions
"based on universal properties of visual perception, inspired by psychological and
neurobiological research," explicitly including **symmetry** **[P]** (*Optimizing Visual
Properties of Game Content Through Neuroevolution*, AIIDE 2011,
<https://www.researchgate.net/publication/220978323_Optimizing_Visual_Properties_of_Game_Content_Through_Neuroevolution>;
follow-up *Adapting Models of Visual Aesthetics for Personalized Content Creation*, IEEE TCIAIG
2012). This is the best direct evidence that bilateral symmetry is defensible **for ships
specifically**. Their follow-up finding matters more than the first, though: the weighting over
aesthetic criteria had to be **re-learned per user** via interactive evolution — "symmetric =
good" is one knob among several, not a constant.

**Against, and it is a strong recent empirical result.** *Breaking Rotational Symmetry: Minimal
Landmarks Stabilize Orientation in Screen-Based 3D Games*, CHI 2026 **[P]**
(<https://dl.acm.org/doi/10.1145/3772318.3791522>). In a cue-poor **rotationally symmetric**
environment, participants who noticed the symmetry — "sections … appearing to be mirrored or
rotated" — lost trust in local cues entirely, and navigation "[turned] from a skill-based task
into a game of chance." Adding **one** asymmetric landmark (a half-black/half-white cube) cut
localisation error ~79% and raised pointing accuracy ~64% against a no-landmark baseline. Their
mechanism claim: players anchor on **discontinuities** — edges, corners, a colour boundary —
then triangulate.

Read the caveat before over-applying it: that study is *rotational* symmetry in a first-person
3D forest. Ours is *bilateral* symmetry on a top-down single deck where the fore/aft axis is
itself a visible cue, which is far less disorienting. But it licenses a concrete rule:
**if the two halves are mirror images, port and starboard must be individually distinguishable
by something other than geometry.**

**Deliberate symmetry-breaking on a symmetric frame** is what the Davies generator does:
mirroring is applied "sometimes," and asymmetric cascading extrusions are layered on top
precisely "to prevent repetitive aesthetics" **[P]**. Same pattern in Oskar Stålberg's
Townscaper work — large shapes constrained and predictable, "I get to play around with a lot of
things on the small shapes" **[P, author interview]**
(<https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making>).

Note the hand-authored player ship already does exactly this: its room rects **are** bilaterally
symmetric about x=10, while its doors and props are not
(`scripts/layouts/player_ship.gd`). Symmetric frame, asymmetric contents.

### 2.4 Fore/aft axis and functional zoning

**Honest answer: evidence is weak and mostly community-level. No rigorous source says "zone
rooms by function along an axis and orientation improves."**

- **Space Station 13** mapping documentation is the best available prior art for our exact
  topology (2D single deck, tile grid, rooms, airlocks). The tg/station guide documents zoning
  by **department** — Command, Security, Engineering, Science, Medical, Supply, Service — as the
  organising principle of every map **[L, community wiki]**
  (<https://wiki.tgstation13.org/Guide_to_mapping>, <https://wiki.tgstation13.org/Maps>). Two
  transferable details: departments get a **back/side door to maintenance** so players can escape
  and antagonists can break in; and the "Island" layout (isolated sectors joined by long
  hallways) is flagged as a failure mode. Also documented and directly relevant to us: because
  the viewport is wider than it is tall, **vertically-oriented departments feel more sprawling** —
  perceived layout quality is coupled to camera aspect, not just to the floorplan.
- **Caves of Qud**, GDC 2019 (Grinblat & Bucklew), *End-to-End Procedural Generation* **[P]**
  (<https://media.gdcvault.com/gdc2019/presentations/Grinblat_Jason_End-to-End_Procedural_Generation.pdf>,
  video <https://www.youtube.com/watch?v=jV-DZqdKlnE>). Their village pipeline resolves a fixed
  ordered list of **"Prefabrication Decision Points"** — `1. Building style 2. Important
  buildings 3. Agricultural plants 4. Decorative plants 5. Wild plants 6. Liquids 7. Door style
  8. Wall types` — before any tiles are placed. The transferable structure is not zoning-by-axis
  but **decide identity and the important buildings *first*, then lay out**, with the stated
  meta-lesson "Use abstraction to your advantage."
- **"Bridge fore, engineering aft" is real-world naval and genre convention. No primary game-dev
  source documents it as a tested readability aid.** Assert it as genre literacy, not evidence.

### 2.5 Landmark rooms for orientation

- **Lynch primary**: *The Image of the City* (MIT Press, 1960) — paths, edges, districts, nodes,
  landmarks; the organising concept is **legibility / imageability**. Framework summary **[S]**
  (<https://ecampusontario.pressbooks.pub/studioskills/chapter/analysis-legibility-lynch/>).
- **Canonical application to level design**: Christopher Totten, *An Architectural Approach to
  Level Design* (2nd ed. 2018), which has a chapter literally titled "Organizing the Sandbox:
  Kevin Lynch's Image of the City" **[P, book]**
  (<https://www.routledge.com/Architectural-Approach-to-Level-Design-Second-edition/Totten/p/book/9780815361367>).
  This is the standard citation for the PCG-adjacent use.
- **Application to PCG specifically**: Hervé, Warpefelt & Salge, *Landmarks, Monuments, and
  Beacons: Understanding Generative Calls to Action* **[P]** (<https://arxiv.org/pdf/2509.19030>).
  Their taxonomy, verbatim: "Landmarks are noticeable features in the game that act as
  scaffolding for the gaming experience. **Monuments** are Landmarks with a component of
  evocation. **Beacons** are Monuments with a 'Call to Action'."

  What makes one work — two required properties: "it has to be **perceivable** and **stand out
  from the rest**. … This can be achieved by having the landmark **deviate from another similar
  item in a perceivable value, such as size, colour, pitch, height**."

  Why they orient: "They … provide a structure to the rest, by **providing a sort of coordinate
  system that allows us to mentally relate other components to it**. Like … this building is
  found on the other side of the tower."

  How many — they explicitly reach for Compton to say "not every single artefact has to be a
  Landmark. Minor content serves to build expectation … Landmarks serve as a payoff."

  **Be honest: this paper is theory only.** It states plainly that optimal landmark
  *distribution* is future work — "The concept of Landmarks in itself raises questions, such as
  their optimal distribution." **There is no published number.**
- **The one empirical number available** is the CHI 2026 study above: **one** strongly-featured,
  polarised landmark cut localisation error ~79% in a cue-poor space, and geometry alone
  (edges/corners without a directional feature) helped much less. Translation: a landmark room
  needs a *directional* asymmetry — a feature that reads differently port-vs-starboard or
  fore-vs-aft — not merely a distinctive shape or size.
- **A metric we could actually implement.** Space syntax (visibility graph analysis + axial line
  analysis) has been applied to scoring PCG levels on integration, connectivity and depth
  **[P/S]**
  (<https://www.academia.edu/75209801/Developing_a_Space_Syntax_Based_Evaluation_Method_for_Procedurally_Generated_Game_Levels>).
  Reported finding: smaller room dimensions yielded higher connectivity, i.e. more decision
  points. Useful to us as an automated *comparator* between candidate partitions in the #5
  prototype, rather than as a design prescription.

### 2.6 No-corridor / room-adjacency layouts

Prior art exists and is respectable. So does an explicit critique (§4.4).

- **Ma, Vining, Lefebvre & Sheffer, *Game Level Layout from Design Specification*, Eurographics
  2014 [P]** (<http://www.chongyangma.com/publications/gl/2014_gl_preprint.pdf>, code
  <https://github.com/chongyangma/LevelSyn>). This is **precisely our topology**: blocks are
  placed so that "blocks corresponding to adjacent graph vertices **share a common boundary
  segment**" that is "long enough to place a doorway through." Corridors are not the default —
  a corridor is a *special case* obtained by constraining a block's configuration space "to allow
  contacts only at the two corridor ends," and they note that case "is typical of commonly used
  dungeon level designs." So room-adjacency is the general case and corridors are a constraint
  layered on top. Ten professional developers reviewed the outputs; feedback was "uniformly
  positive," rated "nice and natural."
  **Note especially their doorway-length requirement — it is the same constraint our 3–4 tile
  doors impose (§4.5).**
- **FTL** is room-adjacency with doors and no corridors, but its ship layouts are **hand-authored
  per ship**; only the sector map and events are procedural. Primary source is the Subset Games
  GDC 2013 postmortem *Designing Without a Pitch* **[P]**
  (<https://www.gamedeveloper.com/design/designing-without-a-pitch---an-em-ftl-em-postmortem>).
  No statement by Ma or Davis about *generating* layouts was found. Same story for SS13 — maps
  are hand-mapped **[L]**.
- **Barotrauma** outposts *are* assembled procedurally, from hand-authored modules built in the
  Submarine Editor **[P, dev blog]**
  (<https://barotraumagame.com/gameplay-features/sneak-peek-outposts-unlocked/>; module docs
  <https://regalis11.github.io/BaroModDoc/ContentTypes/OutpostConfig.html>). Its
  community-documented failure mode is the *opposite* of ours: "outpost generation will liberally
  create huge Hallways rather than using a different 'connector' piece" **[L]**
  (<https://github.com/FakeFishGames/Barotrauma/discussions/8615>).
- **Shadows of Doubt, DevBlog 13** **[P]**
  (<https://colepowered.com/shadows-of-doubt-devblog-13-creating-procedural-interiors/>) —
  grid-based (1.8m tiles, 15x15 floors), rooms placed by simulating each candidate position and
  **ranking** it on floor space, "uniform shape … basically how many corners they have," and
  window access; plus rules like "certain rooms can only connect to other certain rooms" and
  "some rooms can have only 1 door (eg bathrooms), while others can have more." The
  **rank-candidates-by-score** pattern is a cheap way to get Role-appropriate placement out of a
  partition we already have.

### 2.7 For our generator, this suggests

1. **Design for perceptual uniqueness, not variety.** Most rooms should be background. Issue
   #2's "one or two oversized Cargo holds as a landmark" is already the right shape; make it a
   rule rather than an exception, and give large ships exactly one or two landmark rooms rather
   than trying to make all 18 distinct.
2. **Landmarks need a *directional* feature, not just a size difference.** The only empirical
   result available says a polarised, high-contrast landmark works and bare geometry mostly
   doesn't. A 300-tile Cargo hold that is merely *big* is weaker than one that reads differently
   from its fore end than its aft end.
3. **Use the compression test as the acceptance criterion for the #4 prototype.** Flip through
   dozens of seeds and write down the one-sentence description of each. If they compress to the
   same sentence, the recipe has failed regardless of how different the tile arrays are.
4. **Steal "attach function by hull face."** Assign Roles from which section and which hull face
   a room touches (aft-facing → engine, fore-tip → bridge, hull-adjacent → hatch candidate)
   rather than from a free roll over leaves. It is what makes the silhouette *predict* the
   interior, which is what issue #1 says the pre-raid view is meant to reward.
5. **Mirror the structure, never the contents.** Bilateral symmetry in the hull and (optionally)
   the partition; never in Role assignment, doors, props or crew. And give port and starboard a
   featural polarity so a mirrored deck stays navigable.
6. **Steal Qud's ordered decision points.** Roll class → roll the signature compartments →
   *then* partition. Both this and issue #2's "mandatory Roles first" are the same idea; make the
   ordering explicit in the spec.
7. **Steal Shadows of Doubt's candidate ranking** for Role assignment over leaves: score each
   leaf on area, corner count, hull adjacency and section, and assign greedily. Cheaper than a
   constraint solver and it gives designers a legible knob.
8. **Steal SS13's maintenance back-door.** Every department having a second, less obvious way in
   or out is documented practice in the only shipped game with our exact topology, and it is a
   direct answer to the connectivity problem in §4.5.

---

## 3. Entry and extraction point placement

Trust in this section skews lower than in §1 and §2: extraction shooters publish patch notes,
not design talks. Game wikis are used for factual counts and labelled as such.

### 3.1 How many, and how spread

| Game | Total on map | Active per match | Spread rule |
| --- | --- | --- | --- |
| **Hunt: Showdown 1896** | pool of predefined locations | **4** — 1 fixed in map centre, 3 drawn randomly from predefined **edge** locations; 2 of the 4 start **locked** | since Update 1.4.8, "one extraction point always being at least **500m** away from the other two" |
| **Escape from Tarkov** (Interchange) | 6 across both factions | varies (conditional/random) | — |
| **DMZ** (Al Mazrah) | **16** exfil stations | **3** highlighted per session | across different POIs |
| **The Cycle: Frontier** (Bright Sands) | **16** evac points | 2 assigned per prospector (3 on Crescent Falls) | — |
| **Marauders** | **2** Escape Gates | 2, plus your own ship's airlock | "on opposite sides of the map close to the map boundaries" |
| **ARC Raiders** | ~4 main per map + 4 key-gated Raider Hatches on Spaceport | all | — |
| **Dark and Darker** | portals emerge "as a set of 3" | 3 | co-located set, sized to the party |
| **Helldivers 2** | **1**, fixed and pre-marked | 1 | player chooses the *drop* freely; the exit does not move |

Sources: Hunt Showdown Wiki – Maps **[WIKI]** (<https://huntshowdown.wiki.gg/wiki/Maps>);
Hunt Update 1.4.8 patch notes **[PRIMARY, via wiki transcription]**
(<https://huntshowdown.fandom.com/wiki/Update_1.4.8>); CoD Wiki – Exfil **[WIKI]**;
The Cycle: Frontier Wiki – Bright Sands **[WIKI]**; ARC Raiders Wiki – Extraction Points
**[WIKI]**; Dark and Darker Wiki – Escape Portal **[WIKI]**; Marauders and Helldivers guides
**[COMMUNITY]**.

**Does the count scale with map size? Only weakly — and it is the *active* count that is tuned,
not the total.** DMZ's huge Al Mazrah has 16 stations and exposes 3; Bright Sands has 16 and
assigns 2; Hunt uses the same 4-point structure on every map; Marauders' small ship interiors use
2. The consistent shipped pattern is **a large pool that scales loosely with map size, plus a
small active set of 2–4 that stays roughly constant.**

### 3.2 Stopping an exit from trivialising the map

Every mechanism below is documented in a shipped game.

- **Randomised active set drawn from a fixed pool.** Hunt draws 3 of 4 each match **[WIKI]**;
  DMZ highlights 3 of 16 **[WIKI]**.
- **Locked / unlockable extracts.** In Hunt, 2 of the 4 start *locked*, and any player can flip
  the locked state with the Chariot Tarot Card, with a 5-minute cooldown **[WIKI]**. **This is
  the most directly transferable mechanism to permanent Hatches** — the hatch exists, but whether
  it is usable is state.
- **Conditional extracts requiring an item, a fee, or a world state.** Tarkov extracts requiring
  keys, per-player payment, or the power turned on; a green flare signals a live extract
  **[COMMUNITY]**. Labs is the extreme: *every* exit requires a secondary objective first. ARC
  Raiders' Raider Hatches require a Raider Hatch Key **[WIKI]**.
- **Single-use / consumed on use.** Tarkov's Dorms V-Ex is single-use, paid, max four players
  **[COMMUNITY]**.
- **Timed windows.** ARC Raiders terminals display a shutdown timer **[WIKI]**; Tarkov's whole
  raid runs on a ~30–60 min Escape Time clock **[COMMUNITY]**.
- **Extraction takes time and is loud.** Helldivers 2: calling Pelican-1 starts a 2-minute
  defence timer inside a 50m radius and the beacon draws enemies **[WIKI]**. DMZ: the exfil
  helicopter makes AI swarm the area **[WIKI]**. Dark and Darker: "any disruptions or enemy
  attacks while activating the portal could thwart your escape" **[WIKI]**.
- **Hide the exit until the player earns the information.** Hunt's Devil's Trail (March 2026):
  "Supply and Extraction Points are hidden at Mission start," revealed by Scout Towers with
  interactive Scouting Maps, by picking up a Bounty Token, by banishing a boss, or via the
  Chariot card **[PRESS quoting PRIMARY]**
  (<https://tech.yahoo.com/gaming/articles/hunt-showdown-keeps-experimenting-extraction-234853592.html>).
  Stated rationale: a bounty holder no longer has "an obvious predetermined escape route visible
  to all players."
- **Reward speed rather than lurking.** Hunt's "Anti-camping Package" added an accolade granting
  extra bounty per minute left on the mission timer when extracting with a token **[PRIMARY, via
  wiki]**.

### 3.3 Relationship between entry and exit

- **Tarkov gates extract availability by which side you spawned on** — on Customs and Woods
  certain PMC extracts are open only to certain spawns, so most raids involve crossing the map.
  Community sources **disagree on the polarity** (some say "your side", some "the opposite
  side"), so the specific rule is **[COMMUNITY, contested]** while the existence of spawn-linked
  extract gating is well attested.
- **Hunt separates spawns *from each other*, not from extracts**: "In Bounty Hunt and Soul
  Survivor, spawn points are selected such that no two teams spawn within 110 meters of each
  other" **[WIKI]**. Same shape of rule as the 500m extract separation, expressed in metres.
- **Marauders** places its two Escape Gates on opposite sides near the map boundaries
  **[COMMUNITY]**.
- **Valve / Left 4 Dead is the strongest primary source here.** Mike Booth's GDC 2009 talk
  defines **Flow Distance**: "Travel distance from the starting safe room to each area in the
  navigation mesh. Following increasing flow gradient always takes you to the exit room.
  'Escape Route' = shortest path from start safe room to exit." Flow distance is then reused to
  populate enemies and loot and to answer "is this spot ahead or behind the group"; bosses are
  "created every N units along 'escape path' +/- random amount" **[PRIMARY]**
  (<https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf>,
  <https://cdn.akamai.steamstatic.com/apps/valve/2009/GDC2009_ReplayableCooperativeGameDesign_Left4Dead.pdf>).
  **This is graph/travel distance over a navmesh, not Euclidean distance** — the direct answer to
  "graph distance vs euclidean", from a shipped AAA system.
- **Roguelike stairs.** DCSS guarantees *connectivity*, not distance: "Dungeon builder guarantees
  that at least one downstair is reachable from the upstair on D:1, unless there is an enclosed
  entry vault" (0.2, 2007) **[PRIMARY]**
  (<https://raw.githubusercontent.com/crawl/crawl/master/crawl-ref/docs/changelog.txt>). An
  explicit *separation* rule appears much later and locally: in trunk, the Slime Pits were
  reworked so "All floors are now fully connected and up and down stairs are placed **further
  apart**." So separation is a per-branch tuning knob, not a global generator rule. RogueBasin's
  *Stairs* article **[COMMUNITY]** (<https://www.roguebasin.com/index.php/Stairs>) describes
  picking random empty squares, and suggests that if you know where the stairs above came down,
  "you may want to start with the stairs and build the map around them" — stairs as generation
  *seeds*. It documents **no** distance constraint. **No authoritative roguelike source
  specifying a minimum up/down stair distance was found; that is folklore, not documented
  practice.**

### 3.4 Stair-dancing and exit-camping: what was actually done

DCSS is the best-documented case, and the important meta-fact is that **DCSS never removed
stair-dancing — it taxed and constrained it**, piecemeal, over 15+ years. All from the official
changelog **[PRIMARY]**:

- **0.19**: "Climbing stairs takes slightly longer, but doesn't penalize EV." (Time cost to use
  the exit.)
- **0.13**: "Branches now have exactly one exit stair (except the Dungeon…)." (Fewer exits =
  commitment.)
- **0.28**: Hell floors 1–6 "are considerably smaller, and place **only one pair of stairs**."
- **0.20**: The Tomb of Ancients now has **one-way escape hatches** with return hatches nearby
  instead of stairs.
- **0.6**: "Some escape hatches are replaced by (single-use) shafts."
- **0.35 trunk (Slime Pits)**: "All staircases in the branch are now slimy and **can no longer be
  climbed back up** until The Royal Jelly is dead" — a conditional, state-gated one-way exit.
- **0.34 (2026), the biggest monster-side fix**: "Monsters left behind on other floors are now
  more consistent about **approaching and encircling the last staircase they saw the player
  use.**" Plus: monsters lured more than three floors from origin return home, and unseen
  monsters skip their first turn after taking stairs.

That **"encircling the last staircase they saw the player use"** rule is the key transferable
idea: the AI remembers which exit you fled through and camps it, so an exit stops being a free
reset.

On the wider attitude, the DCSS devs' brainstorm wiki on the analogous **Pillar Dancing Removal**
**[PRIMARY, dev wiki]**
(<https://crawl.develz.org/wiki/doku.php?id=dcss:brainstorm:gameplay:pillar_dancing>) is worth
reading verbatim: they call it "optimal gameplay" that is nonetheless "tedious and undesirable",
and conclude "**pillar dancing is a symptom of the early-game design, not the problem itself.**"
Their proposed fixes cluster into a clock that punishes stalling, reinforcements summoned by
prolonged evasion, no regeneration while threatened, and fatigue. **The framing lesson: a
degenerate exit strategy usually means the player had no other survivable option, not that the
exit was in the wrong place.**

### 3.5 Documented pitfalls

- **Exits clustered → one region safe, another a death trap. This is the single best-evidenced
  pitfall in the whole body of sources.** Hunt's 1.4.8 patch notes state the reason for the 500m
  rule outright: Crytek acknowledged that "certain randomly generated elements like extraction
  point locations can lead to unfavorable situations for objective play", and the change was to
  "eliminate one of the most extreme cases that limits potential exit strategies" **[PRIMARY, via
  wiki]**. **Random placement without a separation constraint will occasionally produce a
  cluster, and that cluster ruins the round.**
- **Too few exits → the exits become kill zones.** Tarkov players have complained since ~2018
  that Interchange, with effectively two usable exits, makes both "perfect camper-paradises"
  **[COMMUNITY]**. Note: this is player suggestion — **no primary BSG statement acknowledging
  extract camping as a design problem was found.**
- **Players learning exit locations and rushing them.** Booth is blunt about the general form.
  Under "Avoid manually placed scripts/triggers": it "Kills replayability — Players learn all
  script locations quickly; Removes suspense" and "Kills cooperation — … **Becomes a race**"
  **[PRIMARY]**. Hunt's hidden-extraction experiment is the extraction-genre answer.
- **Multiple routes to the same exit should be balanced.** Valve's level-design wiki: when
  multiple routes lead to the same point, especially an exit, "they should be of roughly equal
  levels of hazard/gain" **[PRIMARY-ish, Valve-maintained]**
  (<https://developer.valvesoftware.com/wiki/Loops_(level_design)>). Also: players don't mind
  backtracking "when the goal seems clear or purposeful, and the trek is not overly long".
- **Too many exits making the space feel small — evidence is thin.** No primary source states
  this directly. The closest documented analogue is DCSS deliberately cutting exits to one per
  branch / one pair per Hell floor to make branches feel like a commitment. **Inference, not a
  cited finding.**
- **Symmetric maps making exits predictable — no source found. Do not claim it.** (Note this
  interacts with our bilateral symmetry decision; see §4.7.)

### 3.6 Player-chosen entry vs random spawn

Evidence is real but thin, and mostly from adjacent designs.

- **Helldivers 2 is the clean case**: the player picks the drop freely and the exit is a single
  fixed, pre-marked point. The design calculus moved entirely onto route planning — standard
  advice is to order your objectives so the final leg ends at extraction **[COMMUNITY]**.
  **When entry is chosen, the exit can be fully known and still generate tension, because the
  interesting decision moved to the path.** That is a direct endorsement of our model.
- **Marauders is the closest analogue to our ship**: you arrive by your own ship and its airlock
  is *both* how you enter and one way you leave, alongside two fixed Escape Gates at maximum
  separation **[WIKI/COMMUNITY]**. The entry-is-also-an-exit pattern **has shipped**, and it
  shipped alongside additional exits placed far apart.
- **Tarkov's spawn-linked extract gating is the counter-pattern**: with *random* spawns the
  designer gets spawn identity as a free constraint forcing traversal. **With chosen entry that
  lever disappears** — the player simply picks the entry adjacent to the exit they want (§4.10).

**No developer talk found directly addresses the chosen-entry-vs-random-spawn tradeoff.** Stated
as a gap.

### 3.7 For our generator, this suggests

1. **Hunt's 500m rule is the template for issue #7: random placement from a pool *plus* an
   explicit minimum-separation constraint.** It was added retroactively because clustering
   shipped and ruined rounds — we get to have it from the start. Express it in **graph distance
   (rooms traversed)**, not straight-line hull distance, because on a 4–18 room ship two hatches
   can be metres apart in tile space and still be far apart through the deck (or vice versa).
2. **Adopt a pool-plus-active-set structure.** Hatches are permanent hull features (settled), so
   the *pool* is fixed by the hull — but which ones are usable can vary. A pool of 4–6 with 2–3
   usable matches every shipped extraction shooter's proportions and gives the Hatch-choice
   interaction something to say.
3. **Scale the pool with class, but keep the active set near-constant.** Small 2–3, medium 3–4,
   large 4–6 as the pool; roughly 2–3 usable at any time. Do not let a large ship become easier
   to leave just because it has more hull.
4. **Implement flow distance as a first-class primitive.** Booth's flow distance over our room
   graph, seeded at the chosen boarding Hatch, solves several open tickets at once: hatch
   separation (#7), threat distribution (#9), loot placement (#10), and "is this room ahead of or
   behind the player". It is one function and it is the highest-leverage thing in this section.
   Note it must be recomputed per raid, because the player chooses the entry.
5. **Lockable hatches are the mechanism that keeps extraction interesting.** Hunt locks 2 of 4
   and lets players flip the state. That maps directly onto our already-planned locked-door rules
   (#8) and costs no new geometry — a Hatch is permanent, its usability is not.
6. **Take the DCSS lesson about exit-camping seriously and apply it to crew AI, not layout.**
   DCSS's most effective fix was monsters that remember and encircle the exit you last used. That
   belongs in `scripts/crew.gd`'s behaviour, not in the generator — but the generator should
   surface which room each Hatch opens into so the AI can use it.
7. **Do not rely on distance for tension.** Issue #2 settled that traversal is cheap (~5.2
   tiles/sec, an 18-room ship is "seconds to cross"). Separation therefore buys *route choice*,
   not *time pressure*. If extraction needs tension, it must come from time-to-extract, noise, or
   crew response — the Helldivers/DMZ levers — not from making the player walk further.

---

## 4. What contradicts or complicates the settled decisions

These are ordered roughly by how much they should change what gets written in #4, #5 and #7.
Nothing here asks to reopen a settled decision; each names a cost that the spec has to price in.

### 4.1 The fightable-room floor is internally inconsistent, and axis-dependent

Not from the literature — from our own code. `tests/test_layouts.gd:8-9,360-366`:

```gdscript
const MIN_ROOM_SIZE := Vector2i(8, 6)
const MIN_ROOM_AREA := 60
...
_expect(size.x >= MIN_ROOM_SIZE.x and size.y >= MIN_ROOM_SIZE.y, ...)
_expect(size.x * size.y >= MIN_ROOM_AREA, ...)
```

Two problems:

1. **8 x 6 = 48, which is below the 60-tile area floor.** A room at the stated dimensional
   minimum is *illegal under its own area minimum*. The smallest actually-legal rectangles are
   10x6 (=60), 9x7 (=63) and 8x8 (=64). The spec should either state the true floor or drop one
   of the two constraints. A generator written against "8x6" will emit rooms the test rejects.
2. **The check is not rotation-invariant.** `12x6` (72 tiles) passes; `6x12` (also 72 tiles)
   fails, because 6 < `MIN_ROOM_SIZE.x`. **A splitter that cuts the longer axis — the standard
   remedy from §1.6 — will generate tall-thin leaves that are identical to legal rooms rotated
   90 degrees, and be rejected for it.** Either the test becomes orientation-agnostic
   (`min(size) >= 6 and max(size) >= 8`), or the partitioner must know that width and height are
   not interchangeable. This is exactly the asymmetric-min-size configuration that makes
   libtcod's F6 bug reachable (§1.5).

**Resolve this before writing the #5 spec.** It is a five-minute decision that otherwise
poisons every split rule downstream.

### 4.2 BSP's documented default output *is* the look we are trying to escape

The PCG Book says of BSP that it "allows for a **very structured appearance**", that the strict
form "creates **very symmetric, 'square' dungeons**", and that even the relaxed, stochastic
variant is "still likely to be **very neatly ordered**" **[P]**
(<https://www.pcgbook.com/chapter03.pdf>). Josh Ge calls BSP maps "the most immediately
recognizable" **[P]**.

This does not invalidate the choice — BSP's adjacency and zero waste are exactly what a hull
needs, and the section decomposition is the stated mitigation. But issue #1's phrasing ("loses
the 'one big square' look") is optimistic: **section decomposition changes the outline, not the
interior texture.** Inside a section, the output is textbook BSP with textbook BSP's known
appearance. Issue #5's instruction to "check the room-size spread is varied rather than uniform"
is the right acceptance test, and §1.6's levers (non-uniform depth, gaussian split positions,
soft axis bias) are what to reach for when it fails.

### 4.3 Both of the strongest "feels designed" results in the literature invert our pipeline

**This is the most important single item in this document.**

Joris Dormans' whole argument for **cyclic dungeon generation** is that you generate the
mission/flow graph *first* and the spatial layout second, because that is what makes levels feel
authored. Ludomotion's own dev blog describes starting from low-resolution layouts, "convert[ing]
to graph structures to reason about gameplay logic," and only then adding detail, and states that
cyclic generation is "much better at generating levels with a natural feeling flow than more
typical applications of [procedural] content generation" **[P]**
(<https://www.ludomotion.com/blogs/level-generation/>; technical writeup **[S]**
<https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/>; Dormans' own
framing **[S]** <https://www.gamedeveloper.com/design/unexplored-s-secret-cyclic-dungeon-generation->).

Ma et al. make the same move from the other direction: **the designer supplies the connectivity
graph**, and the algorithm's only job is to realise it geometrically **[P]**.

**Per-section BSP chooses the space first and takes whatever graph falls out.** That is the
opposite of both. The practical consequence is that the room *graph* — which rooms touch which,
where the cycles are, what the player's route options look like — is an accident of the
partition rather than a design object.

Cheapest available reconciliation that does not reopen the decision: **keep BSP for geometry,
but treat the door graph as a separate, designed artifact** rather than reading it off the BSP
tree. The PCG Book supports this directly, recommending rooms be connected "using random or
rule-based processes, **without taking the quadtree into account at all**" **[P]**. That single
change buys most of the flow benefit at none of the architectural cost, and it is a decision that
belongs in issue #8 (locked doors and connectivity) as much as #5.

### 4.4 "No corridors" has an explicit, named objection

Bob Nystrom, author of the Hauberk generator, in *Rooms and Mazes* **[P]**
(<https://journal.stuffwithstuff.com/2014/12/21/rooms-and-mazes/>):

> I want passageways. At the same time, I don't want the dungeon to just be rooms. **There are
> some games that create levels this way where doors directly join room to room. It works OK, but
> I find it a bit monotonous.** I like the player feeling confined part of the time, and having
> narrow corridors that the player can draw monsters into is a key tactic in the game.

Two separable complaints: **(i) aesthetic monotony** and **(ii) tactical** — no chokepoints, no
confinement, no funnel. Given the recent combat work (aim-at-mouse shooting, hostile crew
fighting from cover — commits `ab29165`, `dc53f5d`), **(ii) is the one to take seriously**. A
pure room-adjacency ship is a graph of open boxes joined at doorways, which means every fight is
either an open-room fight or a doorway fight, and there is no third kind of space.

Two things partly defuse it for us. First, our doorways are deliberately **3–4 tiles wide** so a
fight "spills through them instead of queuing single file" (`scripts/data/door_data.gd`,
`player_ship.gd`) — we have already chosen *against* the chokepoint, knowingly. Second, Ma et al.
show room-adjacency is the *general* case in the research literature and corridors are the
special case **[P]**, with professional-developer review calling the outputs "nice and natural".

But Nystrom's other requirement still lands: he explicitly wants the layout to be **imperfect**
(cycle-rich, not a tree), because "when you hit a dead end (which is often), you have to do a lot
of backtracking" and "games are about making decisions from a set of alternatives. At a literal
level, perfect dungeons only give you one path to choose from." **See §4.5 — our pipeline tends
to produce a tree.**

The honest summary for the spec: *no corridors* is well-supported as a layout strategy and
poorly-supported as a combat-space strategy. If large ships turn out to read as warehouses (an
open question already recorded in issue #1), the internal-texture answer is more likely to be
sub-room structure — cover, catwalks, partial partitions inside a Room — than corridors between
Rooms.

### 4.5 Per-section independent BSP concentrates connectivity at the section seams

The PCG Book states that "due to the BSP tree hierarchy, there will typically only be **one
entrance** to the rooms represented by the child nodes of one non-leaf node in the tree" **[P]**.
Applied to three independently-partitioned sections joined afterwards, that predicts
**articulation points at the seams**: the fore/mid boundary becomes a single-door bottleneck,
and the deck reads as three floorplans stapled together. **No source names this failure; it is
inference from the textbook's own statement about BSP connectivity.**

There is also a concrete geometric hazard that is *not* inference. Our doorways are 3–4 tiles
wide, so two rooms need a shared-edge overlap of at least `door_width + 2` ≈ 5–6 tiles for a
legal door. **BSP siblings always share a full edge, so this is safe inside a section. Rooms
either side of a section seam do not** — a fore-section room and a mid-section room can overlap
by one or two tiles, where no legal doorway fits at all. Ma et al. hit the same constraint and
make it explicit in their formulation: adjacent blocks must share a boundary segment "long enough
to place a doorway through" **[P]**.

Mitigations, in increasing order of cost:

- Require a minimum shared-edge overlap when deciding cross-seam adjacency, and treat pairs below
  it as non-adjacent.
- Do not derive doors from the BSP tree at all (§4.3), and deliberately add cross-seam and
  cycle-closing doors — this also answers §4.4.
- Steal SS13's maintenance back-door convention: a second, less obvious connection per zone
  **[L]**.
- Align section boundaries to a shared coordinate so that seam-crossing leaves line up by
  construction — cheapest structurally, but it makes the seam *more* visible, not less.

Note also that Davies' spaceship generator gets its coherence from **continuity plus perturbation
along the spine** — each section derived from the previous one **[P]** — whereas independent
per-section BSP has no continuity term at all. That is the mechanism behind the seam intuition.

### 4.6 Elongated, same-axis rectangles bias the layout — Ma et al. warn about this specifically

From the same Eurographics paper **[P]**:

> some shapes may induce a **directivity in the layout** because they offer a simpler or longer
> edge interface on one side. Therefore, **a good guideline for designers is to provide a
> sufficient variety of shapes, globally having wall interfaces in all directions.** This limits
> biases during the layout process.

and:

> whenever the graph is made of **nested cycles**, using **shapes elongated along the same axis**
> will make the layout more challenging, as their aspect ratio limits the available area enclosed
> by a cycle.

Our ship is axis-aligned rectangles inside sections that are themselves elongated along the
fore/aft axis, with a floor (8x6) that is itself elongated along x. **That is precisely the
"elongated along the same axis" case**: it will bias adjacency toward one axis and make loops
harder to close, reinforcing both §4.4 and §4.5. It is also a second, independent argument for
making the elongation ratio (§1.6) an explicit, tuned parameter rather than a default.

### 4.7 Bilateral symmetry can actively break orientation

CHI 2026 **[P]** (<https://dl.acm.org/doi/10.1145/3772318.3791522>): participants who realised a
space was mirrored stopped trusting local cues and navigation collapsed into "a game of chance."
The strong caveat from §2.3 applies — that was *rotational* symmetry in a cue-poor first-person
3D forest, and a top-down deck with a visible fore/aft axis is a much friendlier case.

But `RoomFog` means our player is *not* looking at the whole deck: unexplored rooms are blacked
out (`scripts/ship/room_fog.gd`), and at `TILE_SIZE = 32` with the player camera at `zoom = 1.5`
(`scenes/player.tscn`) a 1920x1080 viewport shows roughly 40x22 tiles — **a large-class hull will
never fit on screen during a raid.** So in-raid, the player *is* in a locally cue-poor space,
which is the condition the study describes. The mitigation is cheap and specific: **give port and
starboard a featural polarity** — some consistent, perceivable difference that is not geometry —
so a mirrored deck stays navigable.

### 4.8 Room-count bands versus BSP leaf arithmetic

Issue #2's bands are 4–6, 8–11, 14–18. Uniform-depth BSP yields at most 2^d leaves — 4, 8, 16 —
so **only the bottom of each band is reachable by depth alone**, and §1.5 F3 says even that is
not reliable because the size guard truncates branches unevenly. Three independently-partitioned
sections are what buy the non-power-of-two totals (4+4+4=12, 6+8+4=18), which is a genuine
argument *for* the section decomposition that issue #1 did not make.

Combined with §1.7: **the room count must be driven by a split *budget*, not a depth parameter.**
`N-1` largest-leaf splits gives exactly `N` leaves when the area allows, and the failure mode is a
short ship rather than a wrong-sized one — which issue #2's "mandatory Roles satisfied first"
already handles gracefully.

Sanity arithmetic for #4's silhouette sizing: at ~150 tiles/room, large-class floor area is
2100–2700 tiles plus walls, i.e. a hull bounding box on the order of 50x60 tiles. The
hand-authored player ship is 5 rooms in 21x41 with 788 floor tiles (`player_ship.gd`), which is
the right per-room scale but roughly a third of a large ship's footprint.

### 4.9 "Reading the silhouette to guess where the Armory sits" constrains how random BSP may be

Issue #1 settled that pre-raid the pirate sees only the silhouette and Hatch positions, and that
"reading a ship's shape to guess where the Armory sits is the skill being rewarded." That makes
the **silhouette to interior mapping a learnable function**, which is a real constraint on the
partitioner: if Role assignment is a free roll over leaves, there is nothing to learn and the
pre-raid view is decoration.

Davies' "attach function by face orientation" **[P]** and Qud's ordered decision points **[P]**
(both §2) are the two documented patterns that make function follow form. The compression framing
from §2.1 is the acceptance test: **if the player's one-sentence description of the silhouette
does not narrow down where the Armory is, the recipe has failed.**

### 4.10 Player-chosen entry removes the standard extraction-shooter constraint lever

Tarkov uses spawn identity to gate which extracts are legal, forcing traversal **[COMMUNITY,
contested on polarity]**. **With chosen entry, that lever is gone** — a player who wants a short
raid picks the Hatch next to the loot and leaves through the same one. Issue #7 calls Hatch
spread "what turns a Raid into a route decision rather than an out-and-back", and this is exactly
the pressure against that.

Two things push back, and both are worth writing into #7. First, Helldivers 2 shows chosen entry
plus a fully known exit still generates tension **[COMMUNITY]** — the decision just moves to
route planning. Second, Marauders ships the entry-is-also-an-exit pattern, alongside additional
exits at maximum separation **[WIKI/COMMUNITY]**. But note that in Helldivers the *objectives*
are scattered and mandatory, which is what forces the route; the equivalent for us is that Loot
and Role placement (#10, #6) must be what makes an out-and-back unattractive. **Hatch spread
alone will not do it, especially given traversal is cheap (§3.7 item 7).**

### 4.11 Single deck: no evidence against, one cost worth naming

**No source was found arguing that single-deck is limiting**, and the two most-cited
ship-interior games (FTL, SS13) are effectively single-deck. Ma et al. treat multi-floor as a
constraint layered on the 2D case, not as a different problem **[P]**. **Do not let anyone claim
single-deck is a documented weakness — that claim has no support.**

The one real cost: vertical circulation is a classic source of landmark-ness, and we give it up.
Barotrauma's community complains about ladders precisely because they are so salient **[L]**.
That puts more weight on §2.5's landmark rooms to carry orientation on their own.

### 4.12 Where the evidence is genuinely thin

Stated plainly so nobody over-reads this document:

- **Hull silhouette composition methods** — no comparative evidence at all, from anyone. Craft
  consensus only. Issue #4 is right to decide by prototype.
- **Post-pass merging of undersized BSP leaves** — no primary source found for the technique at
  all. Untested folklore.
- **Exact room count from BSP** — one hobby implementation, plus a derivation. No article, wiki,
  textbook or talk documents it.
- **Sliver failure mode** — no primary source names and analyses it; the evidence is that every
  serious implementation carries a mitigation.
- **Fore/aft functional zoning as an orientation aid** — no primary game-dev source. SS13's
  community wiki is the best available, and it is low-trust.
- **Number of landmarks** — explicitly open in the literature. One empirical data point (n=20, 3D
  forest) says one strong polarised landmark transforms a cue-poor space.
- **"Per-section BSP produces visible seams"** — nobody says this in print. §4.5 is inference from
  the PCG Book's statement about BSP connectivity, plus a concrete door-width argument that is
  not inference.
- **Minimum up-stair/down-stair distance in roguelikes** — folklore. DCSS guarantees connectivity,
  not distance; separation appears only as a per-branch tuning note.
- **"Too many exits makes a space feel small"** — no primary source. Inference from DCSS reducing
  exit counts for other stated reasons.
- **"Symmetric maps make exits predictable"** — no source at all. Do not claim it.
- **Chosen-entry vs random-spawn tradeoff** — no developer talk addresses it directly.
- **Extract camping as an acknowledged design problem** — player complaints only; no primary
  developer statement from BSG.
- **Symmetry in generated ship *interiors*** — the Liapis work is about 2D ship *exteriors*; the
  CHI work is about 3D navigation. Neither is our exact case.

---

## 5. Shortlist for the specs

For **#4 (silhouette)**: decide by prototype, because no comparative evidence exists (§2.2,
§4.12). Use the one-sentence compression test as the pass/fail criterion (§2.1). Steal
continuity-plus-perturbation along the spine rather than independent sections (§2.2, §4.5), and
attach function by hull face (§2.7 item 4, §4.9).

For **#5 (BSP)**: fix the floor's self-inconsistency first (§4.1). Copy libtcod's axis cascade
(§1.2c, §1.8 item 1). Use the BSP *interiors* variant so rooms fill their leaves (§1.5 F4).
Drive room count from an `N-1` split budget over the largest leaf, not from depth (§1.7, §4.8).
Expect the default output to look like textbook BSP and budget the variety levers accordingly
(§1.6, §4.2).

For **#7 (hatches)**: pool-plus-active-set, pool scaling with class and active set near-constant
(§3.7 items 2–3). Minimum separation expressed in graph distance, Hunt's 500m rule as the
template (§3.7 item 1). Implement flow distance as a shared primitive (§3.7 item 4). Lockable
hatches as the tension mechanism (§3.7 item 5). And accept that hatch spread alone will not make
a raid a route decision — Loot and Role placement have to carry that (§4.10).

For **#8 (doors and connectivity)**: this is where §4.3's reconciliation lands. Do not read the
door graph off the BSP tree; design it, add cycles, and handle the section seams explicitly
(§4.5).
