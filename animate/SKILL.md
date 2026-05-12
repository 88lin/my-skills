---
name: animate
description: Review a feature and enhance it with purposeful animations, micro-interactions, and motion effects that improve usability and delight. Use when the user mentions adding animation, transitions, micro-interactions, motion design, hover effects, or making the UI feel more alive.
user-invocable: true
argument-hint: "[target]"
---

## Preparation

这是局部任务，**不要默认 invoke /frontend-design**。只需要确认：(1) 动效是 brand surface 还是 product UI；(2) 性能预算；(3) 是否需要支持 prefers-reduced-motion。

仅当需要重新规划整体交互/动效方向时，才加载 frontend-design 的 motion reference。

---

Analyze a feature and strategically add animations and micro-interactions that enhance understanding, provide feedback, and create delight.

## Register

Brand: orchestrated page-load sequences, staggered reveals, and scroll-driven animation. Motion is part of the voice; one well-rehearsed entrance beats scattered micro-interactions.

Product: 150-250ms on most transitions. Motion conveys state: feedback, reveal, loading, and transitions between views. No page-load choreography; users are in a task and will not wait for it.

## Assess Animation Opportunities

Analyze where motion would improve the experience:

1. **Identify static areas**:
   - Missing feedback: actions without visual acknowledgment.
   - Jarring transitions: instant state changes that feel abrupt.
   - Unclear relationships: spatial or hierarchical relationships that are not obvious.
   - Lack of delight: functional but joyless interactions.
   - Missed guidance: opportunities to direct attention or explain behavior.

2. **Understand the context**:
   - What is the personality? Playful vs serious, energetic vs calm.
   - What is the performance budget? Mobile-first? Complex page?
   - Who is the audience? Motion-sensitive users? Power users who want speed?
   - What matters most? One hero animation vs many micro-interactions?

If any of these are unclear from the codebase, ask the user before implementation.

**CRITICAL**: Respect `prefers-reduced-motion`. Always provide non-animated alternatives for users who need them.

## Plan Animation Strategy

Create a purposeful animation plan:

- **Hero moment**: What is the ONE signature animation?
- **Feedback layer**: Which interactions need acknowledgment?
- **Transition layer**: Which state changes need smoothing?
- **Delight layer**: Where can we surprise and delight?

One well-orchestrated experience beats scattered animations everywhere. Focus on high-impact moments.

## Implement Animations

### Entrance Animations
- Page load choreography: stagger element reveals with 100-150ms delays.
- Hero section: dramatic entrance for primary content.
- Content reveals: scroll-triggered animations with Intersection Observer.
- Modal/drawer entry: smooth slide and fade, backdrop fade, focus management.

### Micro-Interactions
- Button feedback: hover scale/color/shadow, click press, loading state.
- Form interactions: focus transitions, validation animation, success confirmation.
- Toggles and choices: smooth slide/color transition, checkmark animation.
- Favorite/like: scale, rotation, particle effects when contextually appropriate.

### State Transitions
- Show/hide: fade + slide, not instant.
- Expand/collapse: use grid-template-rows, FLIP, or measured transitions rather than animating `height` casually.
- Loading states: skeleton fades, spinner/progress, optimistic transitions.
- Success/error: color transitions, icon animation, gentle scale pulse.

### Navigation & Flow
- Page transitions: crossfade or shared element transitions when supported.
- Tabs: slide indicator and content fade/slide.
- Carousel/slider: smooth transforms, snap points, momentum.
- Scroll effects: parallax layers, sticky headers, scroll progress indicators.

## Technical Implementation

### Timing & Easing

- 100-150ms: instant feedback.
- 200-300ms: state changes.
- 300-500ms: layout changes.
- 500-800ms: entrance animation.
- Exit animations are faster than entrances, around 75% of enter duration.

Use exponential ease-out curves, not CSS defaults:

```css
--ease-out-quart: cubic-bezier(0.25, 1, 0.5, 1);
--ease-out-quint: cubic-bezier(0.22, 1, 0.36, 1);
--ease-out-expo: cubic-bezier(0.16, 1, 0.3, 1);
```

### Performance
- Use transform/opacity for reliable movement.
- Use blur, filters, masks, shadows, and color shifts when they materially improve the effect and remain smooth.
- Avoid casual animation of layout-driving properties (`width`, `height`, `top`, `left`, margins).
- Add `will-change` sparingly for known expensive animations.
- Keep blur/filter/shadow areas bounded and isolated.
- Verify 60fps on target devices.

### Accessibility

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

**NEVER**:
- Use bounce or elastic easing curves.
- Animate layout properties casually when transform, FLIP, or grid-based techniques would work.
- Use durations over 500ms for feedback.
- Animate without purpose.
- Ignore `prefers-reduced-motion`.
- Animate everything.
- Block interaction during animations unless intentional.

## Verify Quality

- Smooth at 60fps.
- Easing feels natural.
- Timing is not jarring or laggy.
- Reduced motion works.
- Users can interact during and after animation.
- Motion makes the interface clearer or more delightful.

Remember: Motion should enhance understanding and provide feedback, not just add decoration.
