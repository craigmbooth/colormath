# Accessibility probes

The colormath suite runs an `a11y` gate (html-validate over templates), so
structural HTML errors are already caught on every PR. That gate is a floor,
not a ceiling: it validates markup, and most real accessibility failures are
behavioral — a control you can't reach by keyboard, a state change nobody
announces, an error message only conveyed by turning a border red.

So don't re-run the linter and call it done. Drive the feature the way someone
who can't use a mouse or a screen would.

## Keyboard: the highest-yield pass

Put the mouse down and complete the feature's primary task using only Tab,
Shift-Tab, Enter, Space, Escape, and arrows. Almost every serious issue shows
up in this one pass.

- **Reachable**: can you get to every interactive control? Custom controls
  built from `div`/`span` with click handlers are the usual miss — they take
  no focus and no keypress.
- **Operable**: does Enter/Space activate what you focused? A `div` with an
  `onclick` looks fine and does nothing from the keyboard.
- **Visible focus**: can you see where you are at every step? A global
  `outline: none` with nothing replacing it makes the whole flow unusable.
- **Order**: does focus follow the visual order? Positive `tabindex` values
  and CSS reordering both break this.
- **Escapable**: in a modal or menu — does focus move into it, stay trapped
  while open, return to the trigger on close, and does Escape dismiss it? A
  trap with no exit is a hard stop.
- **Skippable**: is there a way past repeated navigation to the main content?

## Semantics and naming

- **Every input has a label** — a real `<label for>`, or `aria-label` /
  `aria-labelledby`. Placeholder text is not a label; it vanishes on typing
  and is often unreadable.
- **Buttons and links say what they do** out of context. "Click here", "View",
  and an icon-only button with no accessible name are all opaque when a
  screen reader lists controls.
- **Headings are a real outline** — one `h1`, no skipped levels, chosen for
  structure rather than font size.
- **Images**: meaningful ones need `alt`; decorative ones need `alt=""` so
  they're skipped. An SVG used as UI needs a title or an `aria-hidden` plus a
  text label.
- **Tables**: real `<th>` with `scope`, and a caption. Data tables built from
  `div`s are unnavigable.
- **Landmarks**: `main`, `nav`, `header` present so users can jump.

## Dynamic state

This is where template-linting gates see nothing at all, and it's where
Alpine/htmx-style progressive interfaces tend to fail.

- **Async results**: when content loads, filters apply, or a row is saved, is
  it announced? A polite `aria-live` region for status, assertive for errors.
  Silent success is indistinguishable from a dead button.
- **Errors**: tied to their field with `aria-describedby` and `aria-invalid`,
  not signalled by color alone. Check the error is *reachable* — focus should
  land on or near it after a failed submit.
- **Expandables**: `aria-expanded` on the trigger, and it actually flips.
- **Loading and disabled**: `aria-busy` where relevant; a control that's
  disabled mid-request shouldn't strand focus.

## Visual

- **Contrast**: body text ≥ 4.5:1, large text and meaningful UI boundaries
  ≥ 3:1. In a token-based design system, check the *tokens* — one bad token
  fails everywhere it's used, and fixing it there fixes the whole app. Muted
  secondary text on a tinted background is the usual offender.
- **Color is never the only channel** — status, validity, and required-ness
  need text or an icon too.
- **Zoom to 200%** and reflow to a narrow viewport: does content survive
  without horizontal scrolling or clipped controls?
- **Respect `prefers-reduced-motion`** for anything animated.
- **Target size**: comfortable tap targets on touch, adequately spaced.

## Tooling

Run the repo's own gate first (`make a11y`, or the html-validate npm script)
so you're not reporting what CI already catches. Beyond that, an in-page
automated check (axe via the browser console) catches contrast and ARIA misuse
quickly.

Be honest about the ceiling: automated tooling catches roughly a third of WCAG
issues, and essentially none of the keyboard and announcement problems above.
If you couldn't drive a browser this run, say the keyboard pass didn't happen
rather than implying the feature is clean.
