struct HttpStatus: Error, Equatable, Sendable {
    let code: Int

    static func of(_ error: any Error) -> HttpStatus? {
        if let status = error as? HttpStatus { return status }
        if let reporting = error as? any StatusErrorPort { return HttpStatus(code: reporting.status) }
        return nil
    }

    static func isShape(_ error: any Error) -> Bool {
        error is any ShapeErrorPort
    }

    var kind: FailureKind {
        switch code {
        case 401, 403: .signIn
        case 408, 425, 429, 500...599: .transient
        default: .rejected
        }
    }
}
