import Design

extension Appearance {
    func stackStep(_ level: Int) -> StackStep {
        let steps = dark ? Tokens.stackDark : Tokens.stackLight
        return steps[max(0, min(level, steps.count - 1))]
    }
}
