// Catalog of the starter cards: the upstream component of each card and where it comes from.
// The table is data. The sources themselves are resources under ALFAcolor/App/Resources/Starter/source.

/// The cards of the starter document, by room.
public enum StarterCatalog {
    /// Cards of the room Bewegung: motion-primitives, components/core, with a demo from app/docs where one exists.
    public static let motion: [StarterCard] = [
        StarterCard(name: "accordion", render: "AccordionBasic", demo: "accordion-basic.tsx", extraRuntime: []),
        StarterCard(name: "animated-background", render: "AnimatedCardBackgroundHover", demo: "animated-card-background-hover.tsx", extraRuntime: []),
        StarterCard(name: "animated-group", render: "AnimatedGroupCustomVariants2", demo: "animated-group-custom-variants-2.tsx", extraRuntime: []),
        StarterCard(name: "animated-number", render: "AnimatedNumberBasic", demo: "animated-number-basic.tsx", extraRuntime: []),
        StarterCard(name: "border-trail", render: "BorderTrailCard1", demo: "border-trail-card-1.tsx", extraRuntime: []),
        StarterCard(name: "carousel", render: "CarouselBasic", demo: "carousel-basic.tsx", extraRuntime: []),
        StarterCard(name: "cursor", render: "Cursor1", demo: "cursor-1.tsx", extraRuntime: []),
        StarterCard(name: "dialog", render: "DialogBasic", demo: "dialog-basic.tsx", extraRuntime: []),
        StarterCard(name: "disclosure", render: "DisclosureBasic", demo: "disclosure-basic.tsx", extraRuntime: []),
        StarterCard(name: "dock", render: "AppleStyleDock", demo: "apple-style-dock.tsx", extraRuntime: []),
        StarterCard(name: "glow-effect", render: "GlowEffectButton", demo: "glow-effect-button.tsx", extraRuntime: []),
        StarterCard(name: "image-comparison", render: "ImageComparisonBasic", demo: "image-comparison-basic.tsx", extraRuntime: []),
        StarterCard(name: "in-view", render: "InViewBasicMultiple", demo: "in-view-basic-multiple.tsx", extraRuntime: []),
        StarterCard(name: "infinite-slider", render: "InfiniteSliderBasic", demo: "infinite-slider-basic.tsx", extraRuntime: []),
        StarterCard(name: "magnetic", render: "MagneticBasic", demo: "magnetic-basic.tsx", extraRuntime: []),
        StarterCard(name: "morphing-dialog", render: "MorphingDialogBasicOne", demo: "morphing-dialog-basic-1.tsx", extraRuntime: []),
        StarterCard(name: "morphing-popover", render: "MorphingPopoverBasic", demo: "morphing-popover-basic.tsx", extraRuntime: ["runtime/ui.tsx"]),
        StarterCard(name: "progressive-blur", render: "ProgressiveBlurBasic", demo: "progressive-blur-basic.tsx", extraRuntime: []),
        StarterCard(name: "scroll-progress", render: "ScrollProgressBasic1", demo: "scroll-progress-basic-1.tsx", extraRuntime: []),
        StarterCard(name: "sliding-number", render: "SlidingNumberBasic", demo: "sliding-basic.tsx", extraRuntime: []),
        StarterCard(name: "spinning-text", render: "SpinningTextBasic", demo: "spinning-text-basic.tsx", extraRuntime: []),
        StarterCard(name: "spotlight", render: "SpotlightBasic", demo: "spotlight-basic.tsx", extraRuntime: []),
        StarterCard(name: "text-effect", render: "TextEffectWithCustomDelay", demo: "text-effect-custom-delay.tsx", extraRuntime: []),
        StarterCard(name: "text-loop", render: "TextLoopBasic", demo: "text-loop-basic.tsx", extraRuntime: []),
        StarterCard(name: "text-morph", render: "TextMorphButton", demo: "text-morph-button.tsx", extraRuntime: []),
        StarterCard(name: "text-roll", render: "TextRollBasic", demo: "text-roll-basic.tsx", extraRuntime: []),
        StarterCard(name: "text-scramble", render: "TextScrambleBasic", demo: "text-scramble-basic.tsx", extraRuntime: []),
        StarterCard(name: "text-shimmer-wave", render: "TextShimmerWaveBasic", demo: "text-shimmer-wave-basic.tsx", extraRuntime: []),
        StarterCard(name: "text-shimmer", render: "TextShimmerBasic", demo: "text-shimmer-basic.tsx", extraRuntime: []),
        StarterCard(name: "tilt", render: "TiltCard1", demo: "tilt-card-1.tsx", extraRuntime: []),
        StarterCard(name: "toolbar-dynamic", render: "ToolbarDynamic", demo: nil, extraRuntime: []),
        StarterCard(name: "toolbar-expandable", render: "ToolbarExpandable", demo: nil, extraRuntime: []),
        StarterCard(name: "transition-panel", render: "TransitionPanelCard", demo: "transition-panel-card.tsx", extraRuntime: []),
    ]

    /// Origin of the motion-primitives cards, with the licence text of the repository.
    public static let motionOrigin = StarterOrigin(
        repository: "https://github.com/ibelick/motion-primitives",
        author: "ibelick",
        licence: """
        MIT License

        Copyright (c) 2024 ibelick

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
        """
    )
}
