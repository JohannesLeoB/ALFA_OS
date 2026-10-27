import Assistant
import Foundation
import Hub
import XCTest
@testable import Shipping

private final class Script: @unchecked Sendable {
    private let lock = NSLock()
    private var replies: [(Int, String)]
    private var sent: [URLRequest] = []

    init(_ replies: [(Int, String)]) { self.replies = replies }

    func next(_ request: URLRequest) -> (Int, String) {
        lock.lock(); defer { lock.unlock() }
        sent.append(request)
        return replies.isEmpty ? (200, "{}") : replies.removeFirst()
    }

    var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return sent
    }
}

private struct FakeHttp: HttpPort {
    let script: Script
    var failure: (any Error)?

    init(_ replies: [(Int, String)] = [], failure: (any Error)? = nil) {
        script = Script(replies)
        self.failure = failure
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (status, body) = script.next(request)
        if let failure { throw failure }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        throw ShippingFailure.transport("lines")
    }
}

private struct FakeText: TextPort {
    func text(_ key: String, _ arguments: [String]) -> String { key }
}

private struct FakeTracking: TrackingPort {
    var result: Result<Shipment, ShippingFailure>

    func track(_ shipment: Shipment) async throws -> Shipment {
        var tracked = try result.get()
        tracked.trackingNumber = shipment.trackingNumber
        return tracked
    }
}

private final class FakeLabel: LabelPort, @unchecked Sendable {
    private let lock = NSLock()
    private var orders: [LabelOrder] = []
    var result: Result<LabelResult, ShippingFailure> = .success(LabelResult(trackingNumber: "T1", labelBase64: "b64", statusText: nil))

    var received: [LabelOrder] { lock.withLock { orders } }

    func createLabel(_ order: LabelOrder) async throws -> LabelResult {
        lock.withLock { orders.append(order) }
        return try result.get()
    }
}

private let sender = Address(name1: "Studio", street: "Weg", houseNumber: "1", postalCode: "10115", city: "Berlin")
private let recipient = Address(name1: "Ann", name2: "  ", street: "Allee", houseNumber: "2a", postalCode: "80331", city: "Munich")

private func order(_ change: (inout LabelOrder) -> Void = { _ in }) -> LabelOrder {
    var value = LabelOrder(sender: sender, recipient: recipient, weightGrams: 1500, billingNumber: "1234 5678 9012 34")
    change(&value)
    return value
}

private let credentials = LabelCredentials(
    apiKey: "key", apiSecret: "se cret&", user: "user", password: "pw", billingNumber: "12345678901234", sender: sender)

final class ShippingTests: XCTestCase {
    func testCarrierDetection() {
        XCTAssertEqual(CarrierEngine.detect("JJD014600006"), .dhl)
        XCTAssertEqual(CarrierEngine.detect(" gm 123 "), .dhl)
        XCTAssertEqual(CarrierEngine.detect("LX1"), .dhl)
        XCTAssertEqual(CarrierEngine.detect("123456789012"), .dhl)
        XCTAssertEqual(CarrierEngine.detect("1234567890"), .unknown)
        XCTAssertEqual(CarrierEngine.detect("H12345678"), .hermes)
        XCTAssertEqual(CarrierEngine.detect("H123"), .unknown)
        XCTAssertEqual(CarrierEngine.detect("  "), .unknown)
        XCTAssertEqual(CarrierEngine.normalize(" ab 1 "), "AB1")
    }

    func testStatusMapping() {
        XCTAssertEqual(StatusEngine.status(code: "pre-transit"), .registered)
        XCTAssertEqual(StatusEngine.status(code: "TRANSIT"), .inTransit)
        XCTAssertEqual(StatusEngine.status(code: "delivered"), .delivered)
        XCTAssertEqual(StatusEngine.status(code: "failure"), .exception)
        XCTAssertEqual(StatusEngine.status(code: "other"), .unknown)
        XCTAssertEqual(StatusEngine.status(code: "transit", text: "Out for Delivery"), .outForDelivery)
        XCTAssertEqual(StatusEngine.status(code: "transit", text: "In Zustellung"), .outForDelivery)
        XCTAssertEqual(TrackingStatus.delivered.key, "shipping.status.delivered")
    }

    func testOrderValidation() {
        XCTAssertEqual(LabelOrderEngine.issues(order()), [])
        XCTAssertEqual(LabelOrderEngine.issues(order { $0.recipient.name1 = "" }), [.recipientName])
        XCTAssertEqual(LabelOrderEngine.issues(order { $0.recipient.street = "" }), [.recipientStreet])
        XCTAssertEqual(LabelOrderEngine.issues(order { $0.recipient.postalCode = "1011" }), [.recipientPostalCode])
        XCTAssertEqual(LabelOrderEngine.issues(order { $0.recipient.city = "" }), [.recipientCity])
        XCTAssertEqual(LabelOrderEngine.issues(order { $0.sender.postalCode = "abcde" }), [.senderIncomplete])
        XCTAssertEqual(LabelOrderEngine.issues(order { $0.weightGrams = 0 }), [.weight])
        XCTAssertEqual(LabelOrderEngine.issues(order { $0.billingNumber = "123" }), [.billingNumber])
        XCTAssertTrue(LabelOrderEngine.isValidPostalCode("10 115"))
        XCTAssertEqual(LabelOrderIssue.weight.key, "shipping.issue.weight")
    }

    func testReferenceStripsNumberPrefixAndTruncates() {
        XCTAssertEqual(ReferenceEngine.commission(fromProjectName: "2024_012_Kueche__Berlin"), "Kueche Berlin")
        XCTAssertEqual(ReferenceEngine.commission(fromProjectName: "2024-05-Bad"), "Bad")
        XCTAssertEqual(ReferenceEngine.reference(projectNumber: "P1", projectName: "2024_012_Kueche"), "Kueche \u{00B7} P1")
        XCTAssertEqual(ReferenceEngine.reference(projectNumber: " ", projectName: nil), nil)
        XCTAssertEqual(ReferenceEngine.reference(projectNumber: "P1", projectName: nil), "P1")
        let long = ReferenceEngine.reference(projectNumber: "P1", projectName: String(repeating: "x", count: 80))
        XCTAssertEqual(long?.count, ReferenceEngine.maxLength)
    }

    func testAddressParsingSplitsStreetAndTrimsSecondLine() {
        let parsed = Address.parsed(name: " Ann ", line: "Hauptstr. 12a", postalCode: " 10115 ", city: "Berlin ")
        XCTAssertEqual(parsed.name1, "Ann")
        XCTAssertEqual(parsed.street, "Hauptstr.")
        XCTAssertEqual(parsed.houseNumber, "12a")
        XCTAssertEqual(parsed.postalCode, "10115")
        XCTAssertEqual(parsed.streetLine, "Hauptstr. 12a")
        XCTAssertEqual(Address.parsed(name: "x", line: nil, postalCode: nil, city: nil).streetLine, "")
        XCTAssertNil(recipient.name2)
        XCTAssertEqual(Address(name1: "a", name2: " b ", street: "s", houseNumber: "", postalCode: "", city: "").name2, "b")
    }

    func testRequestMappingOmitsEmptyServices() throws {
        let plain = LabelRequestEngine.request(order { $0.reference = "ref" })
        let shipment = plain.shipments[0]
        XCTAssertEqual(plain.profile, "STANDARD_GRUPPENPROFIL")
        XCTAssertEqual(shipment.product, "V01PAK")
        XCTAssertEqual(shipment.billingNumber, "12345678901234")
        XCTAssertEqual(shipment.refNo, "ref")
        XCTAssertEqual(shipment.consignee.addressStreet, "Allee 2a")
        XCTAssertEqual(shipment.details.weight, LabelRequestEngine.Weight(uom: "g", value: 1500))
        XCTAssertNil(shipment.details.dim)
        XCTAssertNil(shipment.services)

        let rich = LabelRequestEngine.request(order {
            $0.parcel = Parcel(lengthCm: 30, widthCm: 20, heightCm: 10)
            $0.insuranceValue = 99.5
            $0.namedPersonOnly = true
            $0.signature = true
        }).shipments[0]
        XCTAssertEqual(rich.details.dim, LabelRequestEngine.Dimension(uom: "cm", length: 30, width: 20, height: 10))
        XCTAssertEqual(rich.services?.additionalInsurance, LabelRequestEngine.Money(currency: "EUR", value: 99.5))
        XCTAssertEqual(rich.services?.namedPersonOnly, true)
        XCTAssertEqual(rich.services?.signedForByRecipient, true)
        XCTAssertNil(rich.services?.bulkyGoods)

        let partial = LabelRequestEngine.request(order { $0.parcel = Parcel(lengthCm: 30, widthCm: 0, heightCm: 10) }).shipments[0]
        XCTAssertNil(partial.details.dim)
        let zeroInsurance = LabelRequestEngine.request(order { $0.insuranceValue = 0 }).shipments[0]
        XCTAssertNil(zeroInsurance.services)
    }

    func testTrackingRequestAndMapping() async throws {
        let http = FakeHttp([(200, #"{"shipments":[{"status":{"statusCode":"transit","status":"unterwegs"},"estimatedTimeOfDelivery":"morgen"}]}"#)])
        let tracked = try await TrackingClient(apiKey: "k", http: http).track(
            Shipment(trackingNumber: "JJD1", carrier: .dhl, label: "L", projectNumber: "P"))
        XCTAssertEqual(tracked.status, .inTransit)
        XCTAssertEqual(tracked.statusText, "morgen")
        XCTAssertEqual(tracked.label, "L")
        XCTAssertEqual(tracked.projectNumber, "P")
        let request = http.script.requests[0]
        XCTAssertEqual(request.value(forHTTPHeaderField: "DHL-API-Key"), "k")
        XCTAssertEqual(request.url?.absoluteString, "https://api-eu.dhl.com/track/shipments?trackingNumber=JJD1&language=de")
    }

    func testTrackingFailuresAreTyped() async {
        let shipment = Shipment(trackingNumber: "JJD1", carrier: .dhl, label: "")
        let cases: [(TrackingClient, Shipment, ShippingFailure)] = [
            (TrackingClient(apiKey: nil, http: FakeHttp()), shipment, .noKey),
            (TrackingClient(apiKey: "", http: FakeHttp()), shipment, .noKey),
            (TrackingClient(apiKey: "k", http: FakeHttp()), Shipment(trackingNumber: "H1", carrier: .hermes, label: ""), .unsupported),
            (TrackingClient(apiKey: "k", http: FakeHttp([(401, "")])), shipment, .http(401)),
            (TrackingClient(apiKey: "k", http: FakeHttp([(500, "")])), shipment, .http(500)),
            (TrackingClient(apiKey: "k", http: FakeHttp([(200, "{}")])), shipment, .parse("noShipment")),
        ]
        for (api, input, expected) in cases {
            do {
                _ = try await api.track(input)
                XCTFail("expected failure")
            } catch { XCTAssertEqual(error as? ShippingFailure, expected) }
        }
        do {
            _ = try await TrackingClient(apiKey: "k", http: FakeHttp(failure: URLError(.timedOut))).track(shipment)
            XCTFail("expected failure")
        } catch let failure as ShippingFailure {
            if case .transport = failure {} else { XCTFail("expected transport") }
        } catch { XCTFail("unexpected error") }
    }

    func testShipmentPortDetectsCarrierAndLocalisesStatus() async throws {
        let tracked = Shipment(trackingNumber: "x", carrier: .dhl, label: "", status: .delivered, statusText: "ok")
        let port = ShipmentClient(tracking: FakeTracking(result: .success(tracked)), text: FakeText())
        let status = try await port.track(number: "JJD1")
        XCTAssertEqual(status, ShipmentStatus(number: "JJD1", statusLabel: "shipping.status.delivered", detail: "ok"))

        let missing = ShipmentClient(tracking: FakeTracking(result: .failure(.noKey)), text: FakeText())
        do {
            _ = try await missing.track(number: "JJD1")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? PortFailure, .notConnected) }

        let broken = ShipmentClient(tracking: FakeTracking(result: .failure(.http(500))), text: FakeText())
        do {
            _ = try await broken.track(number: "JJD1")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? PortFailure, .failed("http 500")) }
    }

    func testConnectionCheckInterpretsTheProbe() async throws {
        let values = KeyValues(values: ["key": "k"])
        let probe = FakeHttp([(404, "")])
        let accepted = try await ConnectionCheck(http: probe).check(values)
        XCTAssertNil(accepted)
        XCTAssertTrue(probe.script.requests[0].url!.absoluteString.contains(ConnectionCheck.probeNumber))
        XCTAssertEqual(probe.script.requests[0].value(forHTTPHeaderField: "DHL-API-Key"), "k")

        let unreadable = try await ConnectionCheck(http: FakeHttp([(200, "{}")])).check(values)
        XCTAssertNil(unreadable)

        for code in [401, 403, 500] {
            do {
                _ = try await ConnectionCheck(http: FakeHttp([(code, "")])).check(values)
                XCTFail("expected failure")
            } catch let error as any StatusErrorPort { XCTAssertEqual(error.status, code) }
        }
        do {
            _ = try await ConnectionCheck(http: FakeHttp(failure: URLError(.timedOut))).check(values)
            XCTFail("expected failure")
        } catch { XCTAssertEqual((error as? URLError)?.code, .networkConnectionLost) }
        XCTAssertEqual(ConnectionCheck(http: probe).integration, "dhl")
    }

    func testLabelCreationFetchesTokenThenPostsOrder() async throws {
        let http = FakeHttp([
            (200, #"{"access_token":"tok"}"#),
            (200, #"{"items":[{"shipmentNo":"340434","label":{"b64":"AAA"},"sstatus":{"title":"Created"}}]}"#),
        ])
        let result = try await LabelClient(credentials: credentials, http: http).createLabel(order())
        XCTAssertEqual(result, LabelResult(trackingNumber: "340434", labelBase64: "AAA", statusText: "Created"))
        let sent = http.script.requests
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent[0].url?.absoluteString, "https://api-eu.dhl.com/parcel/de/account/auth/ropc/v1/token")
        XCTAssertEqual(String(decoding: sent[0].httpBody ?? Data(), as: UTF8.self),
                       "grant_type=password&client_id=key&client_secret=se%20cret%26&username=user&password=pw")
        XCTAssertEqual(sent[0].value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(sent[1].url?.absoluteString, "https://api-eu.dhl.com/parcel/de/shipping/v2/orders")
        XCTAssertEqual(sent[1].value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        let body = try JSONDecoder().decode(LabelRequestEngine.Request.self, from: sent[1].httpBody ?? Data())
        XCTAssertEqual(body, LabelRequestEngine.request(order()))
    }

    func testLabelCreationFailures() async {
        let missing = LabelCredentials(apiKey: "", apiSecret: "s", user: "u", password: "p", billingNumber: "")
        let cases: [(LabelClient, LabelOrder, ShippingFailure)] = [
            (LabelClient(credentials: credentials, http: FakeHttp()), order { $0.weightGrams = 0 }, .incomplete([.weight])),
            (LabelClient(credentials: nil, http: FakeHttp()), order(), .noCredentials),
            (LabelClient(credentials: missing, http: FakeHttp()), order(), .noCredentials),
            (LabelClient(credentials: credentials, http: FakeHttp([(401, "")])), order(), .http(401)),
            (LabelClient(credentials: credentials, http: FakeHttp([(200, "{}")])), order(), .parse("noAccessToken")),
            (LabelClient(credentials: credentials, http: FakeHttp([(200, #"{"access_token":"t"}"#), (400, "")])), order(), .http(400)),
            (LabelClient(credentials: credentials, http: FakeHttp([(200, #"{"access_token":"t"}"#), (200, "{}")])), order(), .parse("noShipmentNumber")),
        ]
        for (api, input, expected) in cases {
            do {
                _ = try await api.createLabel(input)
                XCTFail("expected failure")
            } catch { XCTAssertEqual(error as? ShippingFailure, expected) }
        }
        XCTAssertEqual(ShippingFailure.incomplete([.weight, .billingNumber]).detail, "incomplete weight,billingNumber")
    }

    @MainActor
    func testLabelStateBuildsTheOrderFromTheForm() async {
        let label = FakeLabel()
        let state = LabelState(label: label, credentials: credentials)
        XCTAssertEqual(state.billingNumber, "12345678901234")
        XCTAssertEqual(state.validate(), [.recipientName, .recipientStreet, .recipientPostalCode, .recipientCity])
        state.setProject(number: "P1", title: "2024_001_Kueche")
        XCTAssertEqual(state.referenceText, "Kueche \u{00B7} P1")
        state.recipientName = "Ann"
        state.recipientStreet = "Allee"
        state.recipientHouseNumber = "2"
        state.recipientPostalCode = "80331"
        state.recipientCity = "Munich"
        state.lengthCm = 10
        state.widthCm = 10
        state.heightCm = 10
        state.insuranceValue = 50
        XCTAssertEqual(state.validate(), [])
        await state.createLabel()
        XCTAssertEqual(state.phase, .created)
        XCTAssertEqual(state.result?.trackingNumber, "T1")
        let sent = label.received[0]
        XCTAssertEqual(sent.reference, "Kueche \u{00B7} P1")
        XCTAssertEqual(sent.parcel, Parcel(lengthCm: 10, widthCm: 10, heightCm: 10))
        XCTAssertEqual(sent.insuranceValue, 50)
        XCTAssertNil(sent.recipient.name2)
    }

    @MainActor
    func testLabelStateReportsMissingSenderIssuesAndFailures() async {
        let label = FakeLabel()
        let state = LabelState(label: label)
        await state.createLabel()
        XCTAssertEqual(state.phase, .failed("noCredentials"))
        XCTAssertEqual(state.issues, [])

        state.sender = sender
        await state.createLabel()
        XCTAssertEqual(state.phase, .failed("incomplete recipientName,recipientStreet,recipientPostalCode,recipientCity,billingNumber"))
        XCTAssertTrue(label.received.isEmpty)

        state.recipientName = "Ann"
        state.recipientStreet = "Allee"
        state.recipientPostalCode = "80331"
        state.recipientCity = "Munich"
        state.billingNumber = "12345678901234"
        state.referenceText = String(repeating: "r", count: 60)
        label.result = .failure(.http(500))
        await state.createLabel()
        XCTAssertEqual(state.phase, .failed("http 500"))
        XCTAssertNil(state.result)
        XCTAssertEqual(label.received[0].reference?.count, ReferenceEngine.maxLength)
    }
}
