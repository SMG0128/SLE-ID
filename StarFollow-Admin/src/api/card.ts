import request from './request'
import type { Card, CardListResponse, CardAction } from '@/types/card'

/** 获取卡片列表 */
export function getCardList(): Promise<CardListResponse> {
  return request.get<never, CardListResponse>('/cards')
}

/** 卡片操作：撤销/冻结/挂失/恢复 */
export function performCardAction(cardId: string, action: CardAction): Promise<Card | undefined> {
  return request.post<never, Card | undefined>(`/cards/${encodeURIComponent(cardId)}/actions`, { action })
}
