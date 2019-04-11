import Foundation

class RealTimeConfigurator: OptimoveComponentConfigurator<RealTime> {
    override func setEnabled(from tenantConfig: TenantConfig) {
        component.isEnable = tenantConfig.enableRealtime
    }
    override func getRequirements() -> [OptimoveDeviceRequirement] {
        return [.internet]
    }
    override func executeInternalConfigurationLogic(from tenantConfig: TenantConfig,
                                                    didComplete: @escaping ResultBlockWithBool) {
        OptiLogger.logConfigrureRealtime()

        guard let realtimeMetadata = tenantConfig.realtimeMetaData else {
            OptiLogger.logRealtimeConfiguirationFailure()
            didComplete(false)
            return
        }
        setMetaData(realtimeMetadata)

        OptiLogger.logRealtimeCOnfigurationSuccess()
        didComplete(true)
    }

    private func setMetaData(_ realtimeMetaData: RealtimeMetaData) {
        component.metaData = realtimeMetaData
    }
}
