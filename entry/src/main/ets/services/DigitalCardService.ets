import { DigitalCard } from '../models/DigitalCard'

export interface DigitalCardService {
  listDigitalCards(): Promise<DigitalCard[]>
  getDigitalCard(cardId: string): Promise<DigitalCard | null>
  saveDigitalCard(card: DigitalCard): Promise<DigitalCard>
  removeDigitalCard(cardId: string): Promise<void>
}
