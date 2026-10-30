import Hub

extension Draft {
    var unsignedBody: String {
        guard let signed else { return body }
        return SignatureEngine.removed(signed, from: body) ?? body
    }

    mutating func resign(to signature: MailboxSignature?, explicit: Bool = false) {
        let target = signatureOff || !(explicit || signature?.onNew == true) ? nil : signature?.block
        guard target != signed else { return }
        if let signed {
            let next: String?
            var nextHTML = bodyHTML
            if let target {
                next = SignatureEngine.replaced(signed, with: target, in: body)
                nextHTML = bodyHTML.flatMap { SignatureEngine.htmlReplaced(signed, with: target, in: $0) }
            } else {
                next = SignatureEngine.removed(signed, from: body)
                nextHTML = bodyHTML.flatMap { SignatureEngine.htmlRemoved(signed, from: $0) }
            }
            guard let next, bodyHTML == nil || nextHTML != nil else { return }
            body = next
            bodyHTML = nextHTML
        } else if let target {
            body = SignatureEngine.inserted(target, into: body, aboveQuote: signature?.aboveQuote ?? false)
            bodyHTML = bodyHTML.map { SignatureEngine.htmlInserted(target, into: $0) }
        }
        signed = target
    }
}
