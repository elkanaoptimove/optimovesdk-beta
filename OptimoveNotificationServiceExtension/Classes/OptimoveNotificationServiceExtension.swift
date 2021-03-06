import Foundation
import UserNotifications

@objc public class OptimoveNotificationServiceExtension: NSObject {

    private let appBundleId:String
    private let tenantInfo: NotificationExtensionTenantInfo
    private let sharedDefaults:UserDefaults
    private var _isHandledByOptimove:Bool

    private var bestAttemptContent: UNMutableNotificationContent?
    private var contentHandler: ((UNNotificationContent) -> Void)?
    
    @objc public init(appBundleId: String) {
        self.appBundleId = appBundleId
        sharedDefaults  = UserDefaults(suiteName: "group.\(appBundleId).optimove")!
        self.tenantInfo = NotificationExtensionTenantInfo(sharedUserDefaults: sharedDefaults)

        _isHandledByOptimove = false
    }
    
    @objc public var isHandledByOptimove: Bool
    {
        return _isHandledByOptimove
    }
    
    // Returns true if the message was consumed by Optimove
    @objc public func didReceive(_ request: UNNotificationRequest,
                                 withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) -> Bool
    {
        guard isForOptimove(request) else {
            return false
        }
        _isHandledByOptimove = true
        self.contentHandler = contentHandler
        createBestAttemptBaseContent(request)
        
        let group = DispatchGroup()
        group.enter()
        group.enter()
        fetchConfigurations { (parsedConfigurations) in
            guard let configs = parsedConfigurations else {
                group.leave()
                group.leave()
                return
            }
            let userInfo = request.content.userInfo
            self.extractDeepLink(from: userInfo) { deepLink in
                guard var dl = deepLink?.absoluteString else { group.leave(); return }
                if let personalizationTags = self.extractPersonaliztionTags(from: userInfo) {
                    for (key,value) in personalizationTags {
                        dl = dl.replacingOccurrences(of: key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!, with: value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "optimove_ignore_parameter")
                    }
                }
                self.bestAttemptContent?.userInfo["dynamic_link"] = dl
                group.leave()
            }

            self.reportNotificationDelivered(using: configs, and: userInfo) {
                group.leave()
            }
        }

        group.notify(queue: DispatchQueue.main) {
            contentHandler(self.bestAttemptContent!)
        }
        return true
    }

    @objc public func serviceExtensionTimeWillExpire()
    {
        if let bestAttemptContent = bestAttemptContent , let contentHandler = contentHandler {
            contentHandler(bestAttemptContent)
        }
    }


    private func isForOptimove(_ request: UNNotificationRequest) -> Bool
    {
        return request.content.userInfo["is_optipush"] as? String == "true"
    }

    private func fetchConfigurations(_ completionHandler: @escaping (OptimoveConfigForExtension?) -> Void)
    {
        handleFetchConfigFromRemoteEndpoint { [weak self] (configurations) in
            if configurations != nil {
                completionHandler(configurations)
            } else {
                self?.handleFetchConfigFromLocalFileSystem(completionHandler: { (configurations) in
                    completionHandler(configurations)
                })
            }
        }
    }
    private func handleFetchConfigFromRemoteEndpoint(completionHandler:@escaping(OptimoveConfigForExtension?)->Void)
    {
        guard let configsUrl = URL(string:"\(tenantInfo.endpoint)\(tenantInfo.token)/\(tenantInfo.version).json") else {
            completionHandler(nil)
            return
        }
        let task = URLSession.shared.dataTask(with: configsUrl) { (data, reponse, error) in
            if let error = error {
                print("configuration fetched from network failed with error: \(error.localizedDescription)")
                completionHandler(nil)
                return
            }

            print("configurations:\(String(describing: String(data:data!,encoding:.utf8)))")
            guard let optimoveConfigs = try? JSONDecoder().decode(OptimoveConfigForExtension.self, from: data!) else {
                print("failed to parse configuration file")
                completionHandler(nil)
                return
            }
            print("Configs parsed successfully")
            completionHandler(optimoveConfigs)
        }
        task.resume()
    }

    private func handleFetchConfigFromLocalFileSystem(completionHandler: @escaping (OptimoveConfigForExtension?)->Void)
    {
        let fileManager = FileManager.default
        let containerAppllicationUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.\(self.appBundleId).optimove")

        guard let urls = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: containerAppllicationUrl , create: true) else {
            completionHandler(nil)
            return
        }
        let optimovePath = urls.appendingPathComponent("OptimoveSDK")

        let fileUrl = optimovePath.appendingPathComponent("\(self.tenantInfo.version).json")

        if FileManager.default.fileExists(atPath: fileUrl.path) {
            if let data =  try? Data(contentsOf: fileUrl), let optimoveConfigs = try? JSONDecoder().decode(OptimoveConfigForExtension.self, from: data) {
                completionHandler(optimoveConfigs)
                return
            } else {
                completionHandler(nil)
                return
            }
        } else {
            completionHandler(nil)
            return
        }
    }
}

//MARK: - Notification content modification
extension OptimoveNotificationServiceExtension
{

    private func createBestAttemptBaseContent(_ request: UNNotificationRequest )
    {
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)


        let userInfo = request.content.userInfo
        let category = UNNotificationCategory(identifier: "dismiss",
                                              actions: [],
                                              intentIdentifiers: [],
                                              options: [.customDismissAction])
        UNUserNotificationCenter.current().setNotificationCategories([category]) //Need to be removed before testing
        bestAttemptContent?.categoryIdentifier = "dismiss"
        bestAttemptContent?.title = userInfo["title"] as! String
        bestAttemptContent?.body = userInfo["content"] as! String
    }
}

//MARK: - Report notificaiton delivered event
extension OptimoveNotificationServiceExtension
{
    private func reportNotificationDelivered(using configurations: OptimoveConfigForExtension,and userInfo:[AnyHashable:Any], complete: @escaping () -> ())
    {
        let optitrackMetadata = configurations.optitrackMetaData
        let eventConfigs = configurations.events

        guard let campaignDetails = CampaignDetails.extractCampaignDetails(from: userInfo) else {
            complete()
            return
        }

        guard let eventConfig = eventConfigs["notification_delivered"] else {return}
        let notificationEvent = NotificationDelivered(bundleId: self.appBundleId, campaignDetails: campaignDetails, currentDeviceOS: "iOS \(ProcessInfo().operatingSystemVersionOnlyString)")
        let queryItems = buildQueryItems(notificationEvent, eventConfig, optitrackMetadata)
        var reportEventUrl = URLComponents(string: optitrackMetadata.optitrackEndpoint)!
        reportEventUrl.queryItems = queryItems.filter { $0.value != nil }
        let reportEventRequest = URLRequest(url: reportEventUrl.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        URLSession.shared.dataTask(with: reportEventRequest, completionHandler: { (data, response, error) in
            if let error = error {
                print("Notification delivered report failed with error \(error.localizedDescription)")
            }
            complete()

        }).resume()
    }

    private func buildQueryItems(_ notificationEvent:NotificationDelivered,
                                 _ eventConfig:OptimoveEventConfig,
                                 _ optitrackMetadata: OptitrackMetadata) -> [URLQueryItem] {
        let date = Date()



        let currentUserAgent = sharedDefaults.string(forKey: "userAgent")!

        let userId = sharedDefaults.string(forKey: "customerID")
        let visitorId = sharedDefaults.string(forKey: "visitorID")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "idsite", value: String(describing:optitrackMetadata.siteId)),
            URLQueryItem(name: "rec", value: "1"),
            URLQueryItem(name: "api", value: "1"),
            // Visitor
            URLQueryItem(name: "_id", value: visitorId),
            URLQueryItem(name: "uid", value: userId),
            // Session
            URLQueryItem(name: "lang", value: Locale.httpAcceptLanguage),
            URLQueryItem(name: "ua", value: currentUserAgent),
            URLQueryItem(name: "h", value: DateFormatter.hourDateFormatter.string(from: date)),
            URLQueryItem(name: "m", value: DateFormatter.minuteDateFormatter.string(from: date)),
            URLQueryItem(name: "s", value: DateFormatter.secondsDateFormatter.string(from: date)),

            //screen resolution
            URLQueryItem(name: "res", value:String(format: "%1.0fx%1.0f", self.sharedDefaults.double(forKey: "deviceResolutionWidth"), self.sharedDefaults.double(forKey: "deviceResolutionHeight"))),

            URLQueryItem(name: "e_c", value: optitrackMetadata.eventCategoryName),
            URLQueryItem(name: "e_a", value: "notification_delivered"),
            ]
        queryItems.append(URLQueryItem(name: "dimension\(optitrackMetadata.eventIdCustomDimensionId)", value:eventConfig.id.description))
        queryItems.append(URLQueryItem(name: "dimension\(optitrackMetadata.eventNameCustomDimensionId)", value:notificationEvent.name))
        appendPluginFlags(from: sharedDefaults.string(forKey: "initialVisitorId")!, to: &queryItems)
        for (paramKey, paramConfig) in eventConfig.parameters {
            guard let paramValue = notificationEvent.parameters[paramKey] else { continue }
            queryItems.append(URLQueryItem(name: "dimension\(paramConfig.optiTrackDimensionId)", value: "\(paramValue)"))
        }
        return queryItems
    }

    private func appendPluginFlags(from visitorId:String, to queryItems: inout [URLQueryItem]) {
        let pluginFlags = ["fla", "java", "dir", "qt", "realp", "pdf", "wma", "gears"]
        let pluginValues = visitorId.splitedBy(length: 2).map {Int($0,radix:16)!/2}.map { $0.description}
        for i in 0..<pluginFlags.count {
            let pluginFlag = pluginFlags[i]
            let pluginValue = pluginValues[i]
            queryItems.append(URLQueryItem(name: pluginFlag, value: pluginValue))
        }
    }
}

//MARK: - Dynamic Link Parsing
extension OptimoveNotificationServiceExtension
{

    private func extractDeepLink(from userInfo: [AnyHashable:Any],complete:  @escaping (URL?) -> ())
    {
        if let dynamicLink = extractDynamicLink(from: userInfo) {
            DynamicLinkParser(parsingCallback: complete).parse(dynamicLink)
        } else {
            complete(nil)
        }
    }
    private func extractDynamicLink(from userInfo:[AnyHashable : Any] ) -> URL?
    {
        if let dl           = userInfo["dynamic_links"] as? String ,
            let data        = dl.data(using: .utf8),
            let json        = try? JSONSerialization.jsonObject(with: data, options:[.allowFragments]) as? [String:Any],
            let ios         = json?["ios"] as? [String:Any],
            let deepLink    = ios[self.appBundleId.replacingOccurrences(of: ".", with: "_")] as? String
        {
            return URL(string: deepLink)
        }
        return nil
    }

    private func extractPersonaliztionTags(from userInfo:[AnyHashable : Any] ) -> [String:String]?
    {
        guard let dl           = userInfo["deep_link_personalization_values"] as? String,
            let data        = dl.data(using: .utf8),
            let json        = try? JSONSerialization.jsonObject(with: data, options:[.allowFragments]) as? [String:String]
            else { return nil }
        return json
    }
}

extension ProcessInfo
{
    var operatingSystemVersionOnlyString:String {
        get {
            return "\(self.operatingSystemVersion.majorVersion).\(self.operatingSystemVersion.minorVersion).\(self.operatingSystemVersion.patchVersion)"
        }
    }
}
