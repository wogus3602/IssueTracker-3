//
//  APIConfiguration.swift
//  IssueTracker
//
//  Created by 송민관 on 2020/10/28.
//

import Foundation
import Alamofire

protocol APIConfiguration: URLRequestConvertible {
    var method: HTTPMethod { get }
    var path: String { get }
    var parameters: RequestParams { get }
}

enum IssueTrackerServer {
    static let baseURL = "http://api.boostcamp.com"
}

// TODO: API명세서 맞추기
enum HTTPHeader: String {
    case authentication = "Authorization"
    case contentType = "Content-Type"
    case acceptType = "Accept"
    case acceptEncoding = "Accept-Encoding"
    case string = "String"
}

enum ContentType: String {
    case json = "Application/json"
    case formEncode = "application/x-www-form-urlencoded"
}

enum RequestParams {
    case body(_: Parameters)
    case url(_: Parameters)
    
    /*
     case body(_: Codable)
     case url(_: URL)
    */
}
