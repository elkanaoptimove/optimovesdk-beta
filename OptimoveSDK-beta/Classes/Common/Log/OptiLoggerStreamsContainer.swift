@objc public final class OptiLoggerStreamsContainer: NSObject {
    static let isClientStgEnv = EnvVars.isClientStgEnv //Bool(ProcessInfo.processInfo.environment["OPTIMOVE_CLIENT_STG_ENV"] ?? "false" ) ?? false
    static let sdkEnv: SdkEnv = .dev

    static var minLogLevelToShow: LogLevel =  getMinLogLevelToShow()

    private static var outputStreams: [ObjectIdentifier: OptiLoggerOutputStream] = [:]
    private static let logQueue = DispatchQueue(label: "com.optimove.sdk.log")

    public static func log(level:LogLevel,
                           fileName: String?,
                           methodName: String?,
                           logModule:String?,
                           _ message: String)
    {
        logQueue.async {
            outputStreams.values.forEach {
                if $0.isVisibleToClient {
                    if minLogLevelToShow <= level {
                        $0.log(level: level,
                               fileName: fileName?.components(separatedBy: "/").last ?? "",
                               methodName: methodName ?? "",
                               logModule: logModule,
                               message: message)
                    }
                } else {
                    $0.log(level: level,
                           fileName: fileName?.components(separatedBy: "/").last ?? "",
                           methodName: methodName ?? "",
                           logModule: logModule,
                           message: message)
                }
            }
        }
    }

    @objc public static func add(stream: OptiLoggerOutputStream) {
        outputStreams[ObjectIdentifier(stream)] = stream
    }
    @objc public static func remove(stream: OptiLoggerOutputStream) {
        outputStreams.removeValue(forKey: ObjectIdentifier(stream))
    }

    private static func getMinLogLevelToShow() -> LogLevel
    {
        if EnvVars.minLogLevel != nil
        {
            return EnvVars.minLogLevel!
        }

        return !EnvVars.isClientStgEnv && sdkEnv == .prod ? LogLevel.warn : LogLevel.debug
    }
}
