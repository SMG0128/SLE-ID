import domainContractsTest from './DomainContracts.test'
import mobileCoreTest from './MobileCore.test'
import confirmationFlowTest from './ConfirmationFlow.test'
import cardProvisioningTest from './CardProvisioning.test'

export default function testsuite() {
  domainContractsTest()
  mobileCoreTest()
  confirmationFlowTest()
  cardProvisioningTest()
}
