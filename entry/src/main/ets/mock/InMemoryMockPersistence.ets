import { MockPersistenceService } from '../services/MockPersistenceService'

export class InMemoryMockPersistence implements MockPersistenceService {
  private consumedInvitationCodes: string[] = []
  private physicalCardState: string = ''
  failNextPhysicalCardSave: boolean = false

  loadConsumedInvitationCodes(): string[] {
    return this.consumedInvitationCodes.slice()
  }

  saveConsumedInvitationCodes(codes: string[]): void {
    this.consumedInvitationCodes = codes.slice()
  }

  loadPhysicalCardState(): string {
    return this.physicalCardState
  }

  savePhysicalCardState(serializedState: string): void {
    if (this.failNextPhysicalCardSave) {
      this.failNextPhysicalCardSave = false
      throw new Error('Mock persistence failure')
    }
    this.physicalCardState = serializedState
  }
}
