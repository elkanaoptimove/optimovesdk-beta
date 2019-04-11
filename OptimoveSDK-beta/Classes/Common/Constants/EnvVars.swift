//
//  EnvVars.swift
//  OptimoveSDK


import Foundation

class EnvVars {

   static var isClientStgEnv: Bool {
    return getEnvVar(for: "OPTIMOVE_CLIENT_STG_ENV", defaultValue: false)!
    }

    static var minLogLevel: LogLevel? {
        guard let levelStr: String? = getEnvVar(for: "OPTIMOVE_MIN_LOG_LEVEL") else { return nil }
        switch levelStr!.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "debug":
            return LogLevel(rawValue: 0)
        case "info":
            return LogLevel(rawValue: 1)
        case "warn":
            return LogLevel(rawValue: 2)
        case "error":
            return LogLevel(rawValue: 3)
        default:
            return nil
        }
    }

    private static func getEnvVar<T>(for key: String, defaultValue: T? = nil) -> T? {
        return (Bundle.main.object(forInfoDictionaryKey: key) as? T) ?? defaultValue
    }
}
