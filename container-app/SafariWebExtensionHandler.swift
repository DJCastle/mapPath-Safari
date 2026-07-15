//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Native side of the popup's address finder. The popup (user-initiated)
//  sends the current page's visible text; we run Apple's data detectors
//  over it on-device and return structured postal addresses. The text is
//  scanned and discarded — nothing is stored, logged, or transmitted.
//

import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let message: [String: Any]?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey] as? [String: Any]
        } else {
            message = request?.userInfo?["message"] as? [String: Any]
        }

        var payload: [String: Any] = ["ok": false]
        if let message,
           message["command"] as? String == "findAddresses",
           let text = message["text"] as? String {
            payload = Self.findAddresses(in: text)
        } else {
            os_log(.error, "Map Path: unrecognized native message")
        }

        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: payload]
        } else {
            response.userInfo = ["message": payload]
        }
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    /// Scans page text for postal addresses using the same on-device data
    /// detectors that power Mail and Messages. Returns deduplicated matches
    /// in page order with their structured components, capped defensively.
    private static func findAddresses(in text: String) -> [String: Any] {
        // Mirrors the content script's own payload cap; a hostile page can't
        // make this expensive.
        let capped = String(text.prefix(200_000))
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.address.rawValue
        ) else {
            return ["ok": false]
        }

        let range = NSRange(capped.startIndex..., in: capped)
        var seen = Set<String>()
        var addresses: [[String: String]] = []

        detector.enumerateMatches(in: capped, options: [], range: range) { match, _, stop in
            guard let match, let r = Range(match.range, in: capped) else { return }
            let full = capped[r]
                .replacingOccurrences(of: "\n", with: ", ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !full.isEmpty, seen.insert(full.lowercased()).inserted else { return }

            var entry: [String: String] = ["full": full]
            if let components = match.addressComponents {
                entry["street"] = components[.street]
                entry["city"] = components[.city]
                entry["state"] = components[.state]
                entry["zip"] = components[.zip]
                entry["country"] = components[.country]
            }
            addresses.append(entry)
            if addresses.count >= 50 { stop.pointee = true }
        }

        return ["ok": true, "addresses": addresses]
    }
}
