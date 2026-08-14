/** 卡片状态 */
export type CardStatus = '正常' | '已冻结' | '已挂失' | '已撤销'

/** 数字卡片（文档 4.4 卡片/许可管理） */
export interface Card {
  id: string
  cardId: string          // 匿名卡标识
  owner: string           // 持有人
  licenseId: string
  licenseName: string
  status: CardStatus
  keyVersion: number      // 密钥版本
  lastSync: string        // 最后同步时间
  createdAt: string
}

/** 卡片列表响应 */
export interface CardListResponse {
  total: number
  list: Card[]
}

/** 卡片操作类型 */
export type CardAction = 'revoke' | 'freeze' | 'report_lost' | 'restore'
