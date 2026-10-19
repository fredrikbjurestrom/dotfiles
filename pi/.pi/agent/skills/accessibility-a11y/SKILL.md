---
name: accessibility-a11y
description: Use when building, reviewing, or testing web interfaces for accessibility, WCAG 2.2 AA, semantic HTML, keyboard navigation, screen readers, forms, focus management, contrast, responsive behavior, or inclusive UX.
license: Apache-2.0
---

# Accessibility (a11y)

Apply accessibility as an interaction and information-design requirement, not as a final cosmetic pass. Prefer native HTML and platform behavior; use ARIA only where semantics or state are otherwise missing. Treat automated results as evidence, not proof of complete WCAG conformance.

## Workflow

1. **Understand the context**: identify the framework, design system, supported browsers, user journeys, and existing accessibility tooling. Follow the project's conventions.
2. **Inspect before editing**: read the relevant components, styles, tests, and package scripts. Identify the actual interaction model and states.
3. **Cover the journey**: check the default, loading, empty, error, success, disabled, validation, responsive, and permission states that users can encounter.
4. **Implement the smallest semantic fix**: use native elements first; preserve existing behavior and styling where it does not conflict with accessibility.
5. **Verify in layers**: run the project's existing checks, then perform keyboard and visual checks. Use axe, Lighthouse, or browser accessibility inspection when available.
6. **Report residual risk**: distinguish automated findings, manual findings, untested assistive technology combinations, and known limitations.

## Non-negotiable principles

- Every function must be usable with a keyboard alone unless the interaction genuinely depends on a non-keyboard input, and an equivalent alternative must then exist.
- Every interactive control needs a programmatically determinable name, role, state, and value.
- Focus must be visible, logical, and managed when the UI changes context.
- Information must not depend on color, sound, hover, or motion alone.
- Errors and status changes must be perceivable without relying on sight or timing alone.
- Do not claim “accessible” or “WCAG compliant” from an automated scan alone.

## Semantic HTML

Use the element whose built-in meaning and behavior match the intent:

- `<button>` for actions; `<a href="...">` for navigation.
- `<header>`, `<nav>`, `<main>`, `<aside>`, `<footer>`, `<article>`, and `<section>` for meaningful page regions.
- A logical heading outline, normally one page-level `<h1>` followed by appropriately nested headings. Do not choose headings for visual size.
- Lists for lists, `<table>` with headers and an appropriate caption for tabular data, and `<fieldset>`/`<legend>` for related form controls.
- Native `<dialog>`, `<details>`, `<summary>`, `<select>`, and form controls where their behavior fits.

Do not make a `<div>` or `<span>` clickable when a native control is available. Do not add `role="button"` to a native `<button>`, and do not use positive `tabindex` values. Avoid duplicate or conflicting roles and labels.

## Names, labels, and instructions

- Give every control a meaningful accessible name. Prefer visible text or an associated `<label>` over an `aria-label`.
- Associate labels with controls using matching `for`/`id` (or the framework's equivalent). Do not use placeholder text as the only label.
- Use `aria-labelledby` when a visible heading or label already exists; use `aria-describedby` for help, constraints, and error text.
- Make link text meaningful out of context. Include the destination or action; avoid “click here” and repeated ambiguous “Read more” links.
- Make required fields and input formats explicit before submission. Use suitable input types, `autocomplete`, `inputmode`, and `name` attributes.
- Preserve user-entered values and focus when validation fails.

## Keyboard and focus

- Keep the natural tab order. Use `tabindex="-1"` only to make a non-tab-stop programmatically focusable; use `tabindex="0"` only when a custom control truly must enter the natural order.
- Never create a keyboard trap. Every custom widget must document and implement its expected keyboard model.
- Native buttons, links, and inputs already support their activation keys; do not add redundant click/key handlers. Do not use deprecated `keypress` patterns.
- Provide a clearly visible `:focus-visible` style with sufficient contrast. Do not remove outlines without an equally strong replacement.
- When opening a modal, move focus into it, keep focus within it while open, provide an accessible name, and return focus to the invoking control on close. Prefer native `<dialog>` where supported by the project.
- When navigating to a new view or replacing a region, place focus at the new context's meaningful heading or first useful control, without stealing focus during ordinary typing.
- Ensure sticky headers, popovers, and overlays do not obscure the focused element.
- For composite widgets such as tabs, menus, listboxes, grids, and carousels, implement the established WAI-ARIA keyboard pattern rather than inventing one.

## Forms and errors

- Group related controls with `<fieldset>` and `<legend>` when appropriate.
- Keep instructions available before the field is used. Do not rely only on color or an icon to indicate an error.
- Connect errors with `aria-describedby` and identify the invalid control with `aria-invalid="true"` only while it is invalid.
- Provide an error summary for multi-field forms when useful. Make each summary item link to its field.
- Announce asynchronous validation or submission results through an appropriately scoped live region; do not make the entire page `aria-live`.
- Do not clear a form or time out a session without warning and a way to recover where the task requires it.

Example:

```html
<label for="email">Email address</label>
<input
  id="email"
  name="email"
  type="email"
  autocomplete="email"
  aria-describedby="email-help email-error"
  aria-invalid="true"
/>
<p id="email-help">Use the address associated with your account.</p>
<p id="email-error" role="alert">Enter a valid email address.</p>
```

## ARIA: use the minimum necessary

1. Use native HTML semantics.
2. Add ARIA only to express a missing name, relationship, or state.
3. Ensure every referenced ID exists and every state reflects the actual UI.
4. Test the result with a screen reader or accessibility tree.

Common patterns:

- `aria-expanded` on the control that opens or closes a disclosure, with `aria-controls` only when the relationship is real.
- `aria-current="page"` for the current navigation item.
- `aria-selected`/`aria-controls` for tabs implemented according to the tabs pattern.
- `aria-hidden="true"` for purely decorative content that is not focusable and conveys no information.
- `aria-live="polite"` for non-urgent status updates; use assertive announcements sparingly.

Never use `aria-hidden="true"` on focusable content or an ancestor of a focused control. Do not use ARIA to repair an incorrect semantic structure when changing the HTML is practical.

## Visual, content, and media accessibility

- For WCAG 2.2 AA, target at least 4.5:1 contrast for normal text and 3:1 for large text. Important non-text UI and graphical objects generally need at least 3:1 against adjacent colors. Check disabled or intentionally exempt states carefully rather than assuming all muted text is exempt.
- Never use color as the sole distinction. Pair it with text, shape, pattern, position, or an accessible state.
- Provide useful alternative text for informative images. Use `alt=""` for decorative images. Do not repeat nearby text or expose a filename as alt text.
- Give videos captions and meaningful controls; provide transcripts or equivalent text for audio. Do not autoplay media with sound.
- Respect `prefers-reduced-motion`; avoid essential information conveyed only through animation. Also consider reduced transparency, forced colors, high contrast, and light/dark color schemes where the product supports them.
- Use readable line length, adequate spacing, and relative text units where appropriate. Content should remain usable at 200% text resize and at 400% zoom/reflow without loss of information or functionality, subject to the WCAG exceptions.
- Support portrait and landscape orientation unless a specific orientation is essential.
- Make touch targets comfortably usable. WCAG 2.2 AA's target-size minimum is generally 24×24 CSS pixels with exceptions; 44×44 is a useful design target but is not itself the universal AA threshold.
- Ensure hover-only content has a keyboard and touch equivalent and can be dismissed without moving the pointer or focus unexpectedly.

## Responsive and dynamic UI

Check narrow and wide layouts, zoom, text expansion, localization-length strings, and forced-colors mode when relevant. Do not hide essential content solely because a breakpoint is reached.

For dynamic updates:

- expose the update's meaning, not implementation details;
- preserve focus unless the user's context genuinely changes;
- avoid focus or live-region churn;
- provide a pause, stop, or hide mechanism for moving or auto-updating content when required;
- ensure dialogs, menus, popovers, toasts, and route changes have correct names, focus behavior, escape behavior, and dismissal behavior.

## Verification

Use the strongest checks available in the project without assuming new dependencies are installed:

### Automated

- Run existing lint, typecheck, unit, integration, and end-to-end commands.
- Run the project's configured axe-core, Lighthouse, or equivalent accessibility checks.
- Inspect the browser accessibility tree for names, roles, states, relationships, and hidden content.
- Treat zero automated violations as a useful baseline, not as a conformance certificate.

### Manual

- Complete the primary flows with keyboard only: Tab, Shift+Tab, Enter, Space, arrows, Escape, and form submission.
- Confirm focus is always visible, order is sensible, and no trap or unexpected jump occurs.
- Test at 200% text resize and 400% browser zoom where the environment permits.
- Test representative flows with a screen reader available on the platform, such as NVDA, VoiceOver, or TalkBack.
- Check reduced motion, forced colors/high contrast, dark mode, and color-vision limitations when relevant.
- Test loading, empty, error, success, disabled, validation, and timeout states—not only the happy path.

When reporting an audit finding, include: severity, affected user journey, file and location, observed behavior, applicable WCAG success criterion when known, concrete remediation, and how it was verified.

## Common mistakes

| Mistake | Better approach |
|---|---|
| Adding ARIA to everything | Start with native HTML and add only the missing semantic relationship or state |
| Using a clickable `<div>` | Use `<button>` for actions or `<a href>` for navigation |
| Removing the focus outline | Keep it or replace it with a clearly visible, high-contrast indicator |
| Treating placeholder text as a label | Use a persistent associated `<label>` |
| Announcing the whole page after every update | Scope a live region to the status that changed |
| Testing only Lighthouse | Combine automated checks with keyboard, zoom, accessibility-tree, and screen-reader checks |
| Declaring WCAG compliance after one scan | Report evidence, coverage, remaining risks, and untested combinations |
| Using color alone for errors or status | Add text and an accessible state or relationship |

## Source and adaptation

Adapted from Mindrally's `accessibility-a11y` skill in `Mindrally/skills`, licensed under Apache License 2.0. This Pi adaptation adds Pi-oriented inspection and verification guidance and updates the recommendations for WCAG 2.2 AA terminology.
