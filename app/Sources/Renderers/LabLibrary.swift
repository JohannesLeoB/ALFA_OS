/// A library that the lab knows: the pattern of the code that calls it, the text that its script tag holds,
/// and the script tag that loads it with a fixed version from cdnjs.
struct LabLibrary: Equatable, Sendable {
    let name: String
    /// A regular expression for the calls in the code, such as `gsap.`.
    let usage: String
    /// Text that the source of a script tag holds when the tag loads this library.
    let marker: String
    /// The script tag with the cdnjs address.
    let tag: String

    /// The libraries of the lab. Each address is an exact version, and each version is older than two weeks.
    /// Sources, checked on cdnjs:
    /// - GSAP 3.12.5, file gsap.min.js, header "GSAP 3.12.5", copyright 2024.
    /// - Three.js r128, file build/three.min.js, header "Copyright 2010-2021 Three.js Authors".
    /// - lottie-web 5.12.2, file lottie.min.js.
    /// - anime.js 3.2.2, file anime.min.js, header "anime.js v3.2.2", copyright 2023.
    /// - Chart.js 4.4.1, file chart.umd.min.js.
    /// - D3 7.8.5, file d3.min.js, header "d3js.org v7.8.5", copyright 2023.
    static let all: [LabLibrary] = [
        LabLibrary(name: "GSAP", usage: #"(?<![\w.])gsap\."#, marker: "gsap",
                   tag: script("https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js")),
        LabLibrary(name: "Three.js", usage: #"(?<![\w.])THREE\."#, marker: "three",
                   tag: script("https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js")),
        LabLibrary(name: "Lottie", usage: #"(?<![\w.])lottie\."#, marker: "lottie",
                   tag: script("https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js")),
        LabLibrary(name: "Anime.js", usage: #"(?<![\w.])anime[.(]"#, marker: "anime",
                   tag: script("https://cdnjs.cloudflare.com/ajax/libs/animejs/3.2.2/anime.min.js")),
        LabLibrary(name: "Chart.js", usage: #"new\s+Chart\s*\("#, marker: "chart",
                   tag: script("https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js")),
        LabLibrary(name: "D3", usage: #"(?<![\w.])d3\."#, marker: "d3",
                   tag: script("https://cdnjs.cloudflare.com/ajax/libs/d3/7.8.5/d3.min.js")),
    ]

    /// The script tag for an address.
    static func script(_ address: String) -> String {
        "<script src=\"\(address)\"></script>"
    }
}
