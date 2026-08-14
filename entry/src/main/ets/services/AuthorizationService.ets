import { Authorization } from '../models/Authorization'

export interface AuthorizationService {
  listAllAuthorizations(): Promise<Authorization[]>
  listAuthorizations(digitalCardId: string): Promise<Authorization[]>
  getAuthorization(authorizationId: string): Promise<Authorization | null>
}
