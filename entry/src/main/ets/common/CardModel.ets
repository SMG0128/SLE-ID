import { DigitalCard, DigitalCardVisualStyle } from '../models/DigitalCard'
import * as Theme from './Theme'

export function cardIcon(card: DigitalCard): Resource {
  if (card.visualStyle === DigitalCardVisualStyle.IDENTITY) {
    return $r('sys.symbol.lock_shield')
  }
  if (card.visualStyle === DigitalCardVisualStyle.ACCESS) {
    return $r('sys.symbol.key')
  }
  return $r('sys.symbol.creditcard')
}

export function cardAccentColor(card: DigitalCard): string {
  if (card.visualStyle === DigitalCardVisualStyle.IDENTITY) {
    return Theme.PRIMARY
  }
  if (card.visualStyle === DigitalCardVisualStyle.ACCESS) {
    return Theme.TERTIARY
  }
  return Theme.SECONDARY
}
