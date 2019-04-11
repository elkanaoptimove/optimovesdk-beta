//
//  MobileLogServiceLogger.swift
//  OptimoveSDK

import Foundation

class MobileLogServiceLoggerStream: OptiLoggerOutputStream {
   

    private let tenantId: Int
    private let appNs: String
    private let sdkEnv: SdkEnv
    private let sdkPlatform: SdkPlatform
    private let destination: URL

    var isVisibleToClient: Bool {
        return false
    }

    init(tenantId: Int, sdkEnv: SdkEnv) {
        self.tenantId = tenantId
        self.sdkEnv = sdkEnv
        self.sdkPlatform = .ios
        self.appNs = Bundle.main.bundleIdentifier!
        self.destination = URL(string: "https://us-central1-appcontrollerproject-developer.cloudfunctions.net/reportLog")!
    }

    func log(level:LogLevel,fileName: String, methodName: String, logModule:String? ,message: String)
    {
        let data = OptimoveLogServiceBody(tenantId: self.tenantId,
                                          appNs: self.appNs,
                                          sdkEnv: self.sdkEnv,
                                          sdkPlatform: self.sdkPlatform,
                                          level: level,
                                          logModule:"",
                                          logFileName: fileName,
                                          logMethodName: methodName,
                                          message: message)
        if let request = self.buildLogRequest(data) {
            let task =  URLSession.shared.dataTask(with: request) { (data, response, error) in

            }
            task.resume()
        }
    }


    private func buildLogRequest(_ data: OptimoveLogServiceBody) -> URLRequest? {
        if let logBody = try? JSONEncoder().encode(data) {
            var request = URLRequest(url: self.destination)
            request.httpBody = logBody
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return request
        } else {
            return nil
        }
    }
}
