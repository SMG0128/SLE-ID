export interface CardFields {
  id: string
  name: string
  issuer: string
  cardNumber: string
  twoFactorEnabled: boolean
  nickname: string
  detail: string
  category: string
  enabled: boolean
}

export interface CardModel extends CardFields {
  icon: Resource
  accentColor: string
}
