export interface MockPersistenceService {
  loadConsumedInvitationCodes(): string[]
  saveConsumedInvitationCodes(codes: string[]): void
  loadPhysicalCardState(): string
  savePhysicalCardState(serializedState: string): void
}
