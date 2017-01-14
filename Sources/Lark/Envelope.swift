import Alamofire
import Foundation

let NS_SOAP = "http://schemas.xmlsoap.org/soap/envelope/"

public struct Envelope {
    let document: XMLDocument

    init() {
        let root = XMLElement.element(withName: "soap:Envelope", uri: NS_SOAP) as! XMLElement
        root.addNamespace(XMLElement.namespace(withName: "soap", stringValue: NS_SOAP) as! XMLNode)
        let body = XMLElement.element(withName: "soap:Body", uri: NS_SOAP) as! XMLElement
        root.addChild(body)
        document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.characterEncoding = "utf-8"
        document.isStandalone = true
    }

    init(document: XMLDocument) {
        self.document = document
    }

    var root: XMLElement {
        return document.rootElement()!
    }

    public var header: XMLElement {
        if let header = root.elements(forLocalName: "Header", uri: NS_SOAP).first {
            return header
        }
        let header = XMLElement.element(withName: "soap:Header", uri: NS_SOAP) as! XMLElement
        root.insertChild(header, at: 0)
        return header
    }

    public var body: XMLElement {
        return root.elements(forLocalName: "Body", uri: NS_SOAP).first!
    }
}


struct EnvelopeDeserializer: DataResponseSerializerProtocol {
    typealias SerializedObject = Envelope
    var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Alamofire.Result<Envelope> = {
        if let error = $3 {
            return .failure(error)
        }
        do {
            if let data = $2 {
                let document = try XMLDocument(data: data, options: 0)
                return .success(Envelope(document: document))
            }
        } catch {
            return .failure(error)
        }
        abort()
    }
}


