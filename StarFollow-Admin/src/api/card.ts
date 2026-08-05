import { mockCardList, mockCardAction } from '@/mock/card'
import { mockDelay } from './request'
import type { Card, CardListResponse, CardAction } from '@/types/card'

/** 获取卡片列表 */
export function getCardList(): Promise<CardListResponse> {
  return mockDelay(mockCardList())
}

/** 卡片操作：撤销/冻结/挂失/恢复 */
export function performCardAction(cardId: string, action: CardAction): Promise<Card | undefined> {
  return mockDelay(mockCardAction(cardId, action), 100)
}
