//
//  GlobalProperties.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/1.
//

import Alamofire
import Foundation

var globalRequestHeaders: HTTPHeaders {
    var headers: HTTPHeaders = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3.1 Safari/605.1.15"
    ]
    let accountToken = UserDefaults.standard.string(forKey: "AccountToken") ?? ""
    if !accountToken.isEmpty {
        headers.add(name: "Authorization", value: "Bearer \(accountToken)")
    }
    return headers
}
