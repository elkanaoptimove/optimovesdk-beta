//
//  OptimoveLogServiceBody.swift
//  OptimoveSDK

import Foundation

struct OptimoveLogServiceBody
{
    let tenantId: Int
    let appNs: String
    let sdkEnv: SdkEnv
    let sdkPlatform: SdkPlatform
    let level: LogLevel
    let logModule: String?
    let logFileName: String?
    let logMethodName: String?
    let message: String
}

extension OptimoveLogServiceBody:Codable {}
