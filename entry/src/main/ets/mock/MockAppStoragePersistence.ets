import { MockPersistenceService } from '../services/MockPersistenceService'

export class MockAppStoragePersistence implements MockPersistenceService {
  private readonly invitationStorageKey: string = 'slekeyMockConsumedInvitationCodes'
  private readonly physicalCardStorageKey: string = 'slekeyMockPhysicalCardState'

  constructor() {
    PersistentStorage.persistProp(this.invitationStorageKey, '')
    PersistentStorage.persistProp(this.physicalCardStorageKey, '')
  }

  loadConsumedInvitationCodes(): string[] {
    const storedValue: string | undefined =
      AppStorage.get<string>(this.invitationStorageKey)
    if (!storedValue) {
      return []
    }
    return storedValue.split('|').filter((code: string) => code.length > 0)
  }

  saveConsumedInvitationCodes(codes: string[]): void {
    AppStorage.set<string>(this.invitationStorageKey, codes.join('|'))
  }

  loadPhysicalCardState(): string {
    return AppStorage.get<string>(this.physicalCardStorageKey) || ''
  }

  savePhysicalCardState(serializedState: string): void {
    AppStorage.set<string>(this.physicalCardStorageKey, serializedState)
  }
}
