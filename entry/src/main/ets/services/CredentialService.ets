import { Authorization } from '../models/Authorization'
import { Credential } from '../models/Credential'

export interface CredentialService {
  listCredentials(physicalCardId: string): Promise<Credential[]>
  getCredential(credentialId: string): Promise<Credential | null>
  translateCredential(authorization: Authorization, physicalCardId: string): Credential | null
  verifyCredential(
    credential: Credential,
    authorization: Authorization,
    physicalCardId: string
  ): boolean
}
