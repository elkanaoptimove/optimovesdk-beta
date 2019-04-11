import Foundation

class RealTime: OptimoveComponent {
	var metaData: RealtimeMetaData!

	private let realTimeQueue = DispatchQueue(label: "com.optimove.realtime")

	override func performInitializationOperations() {
		super.performInitializationOperations()
		setFirstTimeVisitIfNeeded()
	}

	func reportScreenEvent(customURL: String, pageTitle: String, category: String?) {
		let event = OptimoveEventDecorator(event: PageVisitEvent(customURL: customURL, pageTitle: pageTitle, category: category))
		guard let config = Optimove.shared.eventWarehouse?.getConfig(ofEvent: event) else {
			OptiLogger.logConfigForEventMissing(eventName: event.name)
			return
		}
		event.processEventConfig(config)
		self.report(originalEvent: event, withConfigs: config)
	}

	func report(originalEvent: OptimoveEvent, withConfigs config: OptimoveEventConfig) {
		let event = OptimoveCustomEventDecorator(event: originalEvent, config: config)
		event.normalizeParameters(config)

		for (name, value) in originalEvent.parameters {
			let truncatedValue = (String(describing: value).trimmingCharacters(in: .whitespaces))
			event.parameters[name] = truncatedValue
		}

		//Verify that failed set_user_id is dispatched before failed set_email and before any custom event
		if event.name == OptimoveKeys.Configuration.setUserId.rawValue {
			self.setUserId(event, withConfig: config)
			return
		}
		if OptimoveUserDefaults.shared.realtimeSetUserIdFailed {
			let setUserId = SetUserId(originalVistorId: InitialVisitorID,
					userId: CustomerID!,
					updateVisitorId: VisitorID)
			if let config = Optimove.shared.eventWarehouse?.getConfig(ofEvent: setUserId) {
				self.setUserId(setUserId, withConfig: config)
			}
		}

		if event.name == OptimoveKeys.Configuration.setEmail.rawValue {
			self.setEmail(event, withConfig: config)
			return
		}
		if OptimoveUserDefaults.shared.realtimeSetEmailFailed {
			let setEmail = SetEmailEvent(email: UserEmail!)
			if let config = Optimove.shared.eventWarehouse?.getConfig(ofEvent: setEmail) {
				self.setEmail(setEmail, withConfig: config)
			}
		}

		guard isEnable else {
			OptiLogger.logRealtimeDisable(eventName: event.name)
			return
		}

		realTimeQueue.async {
			let rtEvent = RealtimeEvent(tid: self.metaData.realtimeToken, cid: OptimoveUserDefaults.shared.customerID, visitorId: VisitorID, eid: String(config.id), context: event.parameters)

			self.deviceStateMonitor.getStatus(of: .internet) { (online) in
				guard online else {
					OptiLogger.logOfflineStatusForrealtime(eventName: event.name)
					return
				}
				let json = JSONEncoder()
				do {
					let data = try json.encode(rtEvent)
					let json = String(decoding: data, as: UTF8.self)
					OptiLogger.logRealtimeReportEvent(json: json)

					NetworkManager.post(toUrl: URL(string: Optimove.shared.realTime.metaData.realtimeGateway + "reportEvent")!, json: data) { (response, error) in
						guard error == nil else {
							OptiLogger.logRealtimeRequestFailure(errorDescription: error.debugDescription)
							return
						}
						OptiLogger.logRealtimeReportStatus(json: String(decoding: response!, as: UTF8.self))
					}
				} catch {
					OptiLogger.logRealtimeSetUSerIdEncodeFailure()
					return
				}
			}
		}
	}

	private func setUserId(_ event: OptimoveEvent, withConfig config: OptimoveEventConfig) {
		realTimeQueue.async {
			let eventDecorator = OptimoveEventDecorator(event: event, config: config)
			let rtEvent = RealtimeEvent(tid: self.metaData.realtimeToken,
					cid: CustomerID,
					visitorId: InitialVisitorID,
					eid: "\(config.id)",
					context: eventDecorator.parameters)
			self.deviceStateMonitor.getStatus(of: .internet) { (online) in
				guard online else {
					OptiLogger.logSkipSetUserIdForRealtime()
					OptimoveUserDefaults.shared.realtimeSetUserIdFailed = true
					return
				}
				let json = JSONEncoder()
				do {
					let data = try json.encode(rtEvent)
					OptiLogger.logRealtimeSetUserIdReport(json: String(decoding: data, as: UTF8.self))
					NetworkManager.post(toUrl: URL(string: Optimove.shared.realTime.metaData.realtimeGateway + "reportEvent")!, json: data) { (data, error) in
						if error != nil {
							OptimoveUserDefaults.shared.realtimeSetUserIdFailed = true
						} else {
							OptimoveUserDefaults.shared.realtimeSetUserIdFailed = false
							OptiLogger.logRealtimeSetUserIdStatus(status: String(decoding: data!, as: UTF8.self))
						}
					}
				} catch {
					OptimoveUserDefaults.shared.realtimeSetUserIdFailed = true
					OptiLogger.logRealtimeSetUserIDEncodeFailure()
					return
				}
			}
		}
	}

	private func setEmail(_ event: OptimoveEvent, withConfig config: OptimoveEventConfig) {
		realTimeQueue.async {
			let eventDecorator = OptimoveEventDecorator(event: event, config: config)
			let rtEvent = RealtimeEvent(tid: self.metaData.realtimeToken,
					cid: CustomerID,
					visitorId: VisitorID,
					eid: "\(config.id)",
					context: eventDecorator.parameters)
			self.deviceStateMonitor.getStatus(of: .internet) { (online) in
				guard online else {
					OptiLogger.logSkipSetEmailForRealtime()
					OptimoveUserDefaults.shared.realtimeSetEmailFailed = true
					return
				}
				let json = JSONEncoder()
				do {
					let data = try json.encode(rtEvent)
					OptiLogger.logRealtimeSetEmailReport(json: String(decoding: data, as: UTF8.self))
					NetworkManager.post(toUrl: URL(string: Optimove.shared.realTime.metaData.realtimeGateway + "reportEvent")!, json: data) { (data, error) in
						if error != nil {
							OptimoveUserDefaults.shared.realtimeSetEmailFailed = true
						} else {
							OptimoveUserDefaults.shared.realtimeSetEmailFailed = false
							OptiLogger.logRealtimeSetEmailStatus(status: String(decoding: data!, as: UTF8.self))
						}
					}
				} catch {
					OptimoveUserDefaults.shared.realtimeSetEmailFailed = true
					OptiLogger.logRealtimeSetEmailEncodeFailure()
					return
				}
			}
		}
	}

	private func setFirstTimeVisitIfNeeded() {
		if OptimoveUserDefaults.shared.firstVisitTimestamp == 0 {
			OptimoveUserDefaults.shared.firstVisitTimestamp = Int(Date().timeIntervalSince1970) //Realtime server asked to get it in seconds
		}
	}
}
