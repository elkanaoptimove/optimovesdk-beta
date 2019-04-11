import Foundation

struct OptimoveEventConfigsWarehouse {

    private let eventsConfigs: [String: OptimoveEventConfig]

    init(from tenantConfig: TenantConfig) {
        OptiLogger.logEventsWarehouseInitializtionStart()
        eventsConfigs = tenantConfig.events
        OptiLogger.logEventsWarehouseInitializtionFinish()
    }

    func getConfig(ofEvent event: OptimoveEvent) -> OptimoveEventConfig? {
        return eventsConfigs[event.name]
    }
}
