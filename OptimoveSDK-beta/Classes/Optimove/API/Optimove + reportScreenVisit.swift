//
//  Optimove + reportScreenVisit.swift
//  OptimoveSDK

import Foundation

// MARK: report screen visit

extension Optimove
{
    @objc public func setScreenVisit(screenTitle: String, screenPathArray: [String], category: String? = nil)
    {
        OptiLogger.logReportScreen()
        guard !screenTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            OptiLogger.logReportScreenWithEmptyTitleError()
            return
        }
        let path = screenPathArray.joined(separator: "/")
        setScreenVisit(screenTitle: screenTitle, screenPath: path,category: category)
    }

    @objc public func setScreenVisit(screenTitle: String, screenPath: String, category: String? = nil)
    {
        let screenTitle = screenTitle.trimmingCharacters(in: .whitespaces)
        let screenPath = screenPath.trimmingCharacters(in: .whitespaces)
        guard !screenTitle.isEmpty else {
            OptiLogger.logReportScreenWithEmptyTitleError()
            return
        }
        guard !screenPath.isEmpty else {
            OptiLogger.logReportScreenWithEmptyScreenPath()
            return
        }

        if let customUrl = removeUrlProtocol(path: screenPath).lowercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            var path = customUrl.last != "/" ? "\(customUrl)/" : "\(customUrl)"
            path = "\(Bundle.main.bundleIdentifier!)/\(path)".lowercased()

            if RunningFlagsIndication.isComponentRunning(.optiTrack) {
                optiTrack.reportScreenEvent(screenTitle: screenTitle, screenPath: path, category: category)
            }
            if RunningFlagsIndication.isComponentRunning(.realtime) {
                realTime.reportScreenEvent(customURL: path, pageTitle: screenTitle, category: category)
            }
        }
    }

    private func removeUrlProtocol(path: String) -> String {
        var result = path
        for prefix in ["https://www.", "http://www.", "https://", "http://"] {
            if (result.hasPrefix(prefix)) {
                result.removeFirst(prefix.count)
                break
            }
        }
        return result
    }
}
