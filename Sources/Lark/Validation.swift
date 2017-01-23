import Alamofire
import Foundation


extension DataRequest {
    func validateSOAP() -> Self {
        return validate { _, response, data in
            switch response.statusCode {
            case 200: return .success
            case 500:
                do {
                    let document = try XMLDocument(data: data!, options: 0)
                    let envelope = Envelope(document: document)
                    let fault = try Fault(deserialize: envelope.body.elements(forLocalName: "Fault", uri: NS_SOAP).first!)
                    return .failure(fault)
                } catch {
                    return .failure(error)
                }
            default:
                fatalError("Unexpected status code \(response.statusCode). Verify that validate(statusCode:) is called before this validation.")
            }
        }
    }
}


/// Typed error message returned by the server.
///
/// If the message was received by the server, but could somehow not be 
/// processed, it will return a `Fault`. The issue could for example that the
/// provided data is invalid, some object could not be deserialized, the
/// server performed an illegal operation.
public struct Fault: Error, CustomStringConvertible, XMLDeserializable {

    /// Provides an algorithmic mechanism for identifying the fault.
    public let faultcode: QualifiedName

    /// Provides a human readable explanation of the fault and is not intended for algorithmic processing.
    public let faultstring: String

    /// Provides information about who caused the fault to happen within the message path.
    public let faultactor: URL?

    /// Carries application specific error information related to the Body element.
    public let detail: [XMLNode]

    /// A textual representation of this Fault instance.
    public var description: String {
        let actor = faultactor?.absoluteString ?? "nil"
        let detail = self.detail.map({ $0.xmlString }).joined(separator: ", ")
        return "Fault(code=\(faultcode), actor=\(actor), string=\(faultstring), detail=\(detail))"
    }

    /// Deserializes a `<soap:fault/>` into a `Fault` instance.
    ///
    /// - Parameter element: the `<soap:fault/>` node
    /// - Throws: errors when a typed property cannot be deserialized
    public init(deserialize element: XMLElement) throws {
        guard let faultcode = element.elements(forName: "faultcode").first?.stringValue else {
            fatalError("Missing faultcode")
        }
        self.faultcode = try QualifiedName(type: faultcode, inTree: element)
        faultstring = element.elements(forName: "faultstring").first!.stringValue!
        faultactor = try element.elements(forName: "faultactor").first.map(URL.init(deserialize:))
        detail = element.elements(forName: "detail").first?.children ?? []
    }

    // MARK:- Internal API

    init(faultcode: QualifiedName, faultstring: String, faultactor: URL?, detail: [XMLNode]) {
        self.faultcode = faultcode
        self.faultstring = faultstring
        self.faultactor = faultactor
        self.detail = detail
    }

    func serialize(_ element: XMLElement) {
        let faultcodePrefix = element.resolveOrAddPrefix(forNamespaceURI: faultcode.uri)
        element.addChild(XMLElement(name: "faultcode", stringValue: "\(faultcodePrefix):\(faultcode.localName)"))

        element.addChild(XMLElement(name: "faultstring", stringValue: faultstring))
        element.addChild(XMLElement(name: "faultactor", stringValue: faultactor?.absoluteString))

        let detailNode = XMLElement(name: "detail")
        for child in detail {
            detailNode.addChild(child)
        }
    }
}
