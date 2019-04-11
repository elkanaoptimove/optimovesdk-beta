import Foundation

class OptiPushConfigurator: OptimoveComponentConfigurator<OptiPush> {

    required init(component: OptiPush) {
        super.init(component: component)
    }

    override func setEnabled(from tenantConfig: TenantConfig) {
        component.isEnable = tenantConfig.enableOptipush
    }

    override func getRequirements() -> [OptimoveDeviceRequirement] {
        return [.userNotification, .internet]
    }

    override func executeInternalConfigurationLogic(from tenantConfig: TenantConfig, didComplete:@escaping ResultBlockWithBool) {
       OptiLogger.logConfigureOptipush()
        guard let optipushMetadata = tenantConfig.optipushMetaData,
            let firebaseProjectKeys = tenantConfig.firebaseProjectKeys,
            let clientsServiceProjectKeys = tenantConfig.clientsServiceProjectKeys else {
                OptiLogger.logOptipushConfigurationFailure()
                didComplete(false)
                return
        }
        setMetaData(optipushMetadata)
        component.setup(firebaseMetaData: firebaseProjectKeys,
                        clientFirebaseMetaData: clientsServiceProjectKeys,
                        optipushMetaData: optipushMetadata )
        OptiLogger.logOptipushConfigurationSuccess()
        didComplete(true)
    }

    private func setMetaData(_ optipushMetadata: OptipushMetaData) {
        component.metaData = optipushMetadata
    }

}
