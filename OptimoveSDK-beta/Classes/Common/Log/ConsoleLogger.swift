import Foundation

class OptiConsoleLog: NSObject, OptiLoggerOutputStream {
    
    func log(level:LogLevel, fileName: String, methodName: String, logModule: String?, message: String) {
        optiLog(fileName: fileName, methodName: methodName, logModule: logModule, message: message)
    }


    var isVisibleToClient: Bool {
        return true
    }

    private func optiLog(fileName: String, methodName: String, logModule: String?, message: String) {
        print("\(fileName):\(methodName) \(message)")
    }
}
