import Foundation
import Network
import Darwin

class UPnPPortMapper {
    var logger: ((String) -> Void)?
    private func log(_ message: String) { logger?(message) }

    func addPortMapping(port: UInt16, completion: @escaping (Bool) -> Void) {
        discoverControlURL { url in
            guard let url else {
                completion(false)
                return
            }
            self.sendAddPortMapping(controlURL: url, port: port, completion: completion)
        }
    }

    private func discoverControlURL(completion: @escaping (URL?) -> Void) {
        let message = """
M-SEARCH * HTTP/1.1\r
HOST:239.255.255.250:1900\r
MAN:\"ssdp:discover\"\r
MX:1\r
ST:urn:schemas-upnp-org:service:WANIPConnection:1\r
\r
"""
        let connection = NWConnection(host: "239.255.255.250", port: 1900, using: .udp)
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                connection.send(content: message.data(using: .utf8), completion: .contentProcessed { error in
                    if let error {
                        self?.log("SSDP send failed: \(error)")
                        completion(nil)
                        return
                    }
                    connection.receiveMessage { data, _, _, error in
                        guard let data, error == nil,
                              let response = String(data: data, encoding: .utf8) else {
                            self?.log("SSDP receive failed")
                            completion(nil)
                            return
                        }
                        let lines = response.split(separator: "\r\n")
                        guard let locationLine = lines.first(where: { $0.lowercased().hasPrefix("location:") }) else {
                            self?.log("No LOCATION header in SSDP response")
                            completion(nil)
                            return
                        }
                        let locationString = locationLine.dropFirst("location:".count).trimmingCharacters(in: .whitespaces)
                        guard let url = URL(string: locationString) else {
                            self?.log("Invalid LOCATION URL")
                            completion(nil)
                            return
                        }
                        self?.fetchControlURL(from: url, completion: completion)
                    }
                })
            } else if case .failed(let error) = state {
                self?.log("SSDP connection failed: \(error)")
                completion(nil)
            }
        }
        connection.start(queue: .global())
    }

    private func fetchControlURL(from url: URL, completion: @escaping (URL?) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data, error == nil,
                  let xml = String(data: data, encoding: .utf8) else {
                self?.log("Failed to fetch device description")
                completion(nil)
                return
            }
            if let controlURL = self?.parseControlURL(xml: xml, base: url) {
                completion(controlURL)
            } else {
                self?.log("No controlURL found in device description")
                completion(nil)
            }
        }.resume()
    }

    private func parseControlURL(xml: String, base: URL) -> URL? {
        guard let serviceRange = xml.range(of: "<serviceType>urn:schemas-upnp-org:service:WANIPConnection:1</serviceType>") else {
            return nil
        }
        guard let controlStart = xml.range(of: "<controlURL>", range: serviceRange.upperBound..<xml.endIndex),
              let controlEnd = xml.range(of: "</controlURL>", range: controlStart.upperBound..<xml.endIndex) else {
            return nil
        }
        let path = String(xml[controlStart.upperBound..<controlEnd.lowerBound])
        return URL(string: path, relativeTo: base)
    }

    private func sendAddPortMapping(controlURL: URL, port: UInt16, completion: @escaping (Bool) -> Void) {
        guard let localIP = localIPAddress() else {
            log("Could not determine local IP address")
            completion(false)
            return
        }
        let body = """
<?xml version=\"1.0\"?>
<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
 <s:Body>
  <u:AddPortMapping xmlns:u=\"urn:schemas-upnp-org:service:WANIPConnection:1\">
   <NewRemoteHost></NewRemoteHost>
   <NewExternalPort>\(port)</NewExternalPort>
   <NewProtocol>TCP</NewProtocol>
   <NewInternalPort>\(port)</NewInternalPort>
   <NewInternalClient>\(localIP)</NewInternalClient>
   <NewEnabled>1</NewEnabled>
   <NewPortMappingDescription>weave</NewPortMappingDescription>
   <NewLeaseDuration>0</NewLeaseDuration>
  </u:AddPortMapping>
 </s:Body>
</s:Envelope>
"""
        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.addValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.addValue("\"urn:schemas-upnp-org:service:WANIPConnection:1#AddPortMapping\"", forHTTPHeaderField: "SOAPAction")
        request.httpBody = body.data(using: .utf8)
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let error {
                self?.log("AddPortMapping failed: \(error)")
                completion(false)
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                self?.log("Port mapping added")
                completion(true)
            } else {
                self?.log("Port mapping request returned unexpected response")
                completion(false)
            }
        }.resume()
    }

    private func localIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = Int32(interface.ifa_addr.pointee.sa_family)
                if addrFamily == AF_INET {
                    let name = String(cString: interface.ifa_name)
                    if name != "lo0" {
                        var addr = interface.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        let result = getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        if result == 0 {
                            address = String(cString: hostname)
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
