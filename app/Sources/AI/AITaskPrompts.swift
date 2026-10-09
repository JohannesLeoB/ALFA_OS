/// The fixed system texts and limits of the tasks. They are in English, as the model reads them best.
enum AITaskPrompts {
    static let codeMaxTokens = 8192
    static let shortMaxTokens = 1024

    /// The rules that every task shares.
    static let commonRules = """
        Do not write keys, tokens or passwords. \
        Do not write network addresses except these hosts: cdnjs.cloudflare.com, unpkg.com, \
        cdn.jsdelivr.net, cdn.tailwindcss.com, fonts.googleapis.com, fonts.gstatic.com. \
        Do not use eval.
        """

    static let codeSystem = """
        You change the design code of one card in a design app. \
        Answer only in the agreed format: for each file that you change or create, one block \
        that starts with a line ```datei:<file name> and ends with a line ```. \
        Put one short note line after the blocks. \
        \(commonRules)
        """

    static let htmlSystem = """
        You write one HTML page that fits the CSS in the user message. \
        Answer only in the agreed format: one block that starts with a line ```datei:index.html \
        and ends with a line ```. Put one short note line after the block. \
        \(commonRules)
        """

    static let namesSystem = """
        You name design tokens. Answer only with JSON of this form and nothing else: \
        {"names":[{"id":"<id>","name":"<name>"}]}. \
        A name is short, lower case, and uses hyphens. It must not contain dots or braces, and it must not be empty. \
        \(commonRules)
        """

    static let explainSystem = """
        You explain a piece of code in a few short sentences of plain English. \
        Answer only with the explanation. \
        \(commonRules)
        """
}
