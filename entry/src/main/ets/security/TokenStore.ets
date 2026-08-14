import { asset } from '@kit.AssetStoreKit'
import { util } from '@kit.ArkTS'
import { MobileSession } from '../models/MobileSession'

export interface TokenStore {
  load(): Promise<MobileSession | null>
  save(session: MobileSession): Promise<void>
  clear(): Promise<void>
}

export class InMemoryTokenStore implements TokenStore {
  private session: MobileSession | null = null

  async load(): Promise<MobileSession | null> {
    return this.session
  }

  async save(session: MobileSession): Promise<void> {
    this.session = session
  }

  async clear(): Promise<void> {
    this.session = null
  }
}

export class AssetTokenStore implements TokenStore {
  private readonly alias: Uint8Array =
    util.TextEncoder.create().encodeInto('sle-id-mobile-session')

  async load(): Promise<MobileSession | null> {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    query.set(asset.Tag.ALIAS, this.alias)
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    let results: asset.AssetMap[]
    try {
      results = await asset.query(query)
    } catch (error) {
      throw new Error('Unable to read secure mobile session')
    }
    if (results.length === 0) {
      return null
    }
    const secret: asset.Value | undefined = results[0].get(asset.Tag.SECRET)
    if (!(secret instanceof Uint8Array)) {
      return null
    }
    const serialized: string = util.TextDecoder.create('utf-8').decodeToString(secret)
    try {
      return JSON.parse(serialized) as MobileSession
    } catch (error) {
      return null
    }
  }

  async save(session: MobileSession): Promise<void> {
    const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    attributes.set(asset.Tag.ALIAS, this.alias)
    attributes.set(
      asset.Tag.SECRET,
      util.TextEncoder.create().encodeInto(JSON.stringify(session))
    )
    attributes.set(
      asset.Tag.ACCESSIBILITY,
      asset.Accessibility.DEVICE_FIRST_UNLOCKED
    )
    attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER)
    attributes.set(
      asset.Tag.CONFLICT_RESOLUTION,
      asset.ConflictResolution.OVERWRITE
    )
    try {
      await asset.add(attributes)
    } catch (error) {
      throw new Error('Unable to save secure mobile session')
    }
  }

  async clear(): Promise<void> {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    query.set(asset.Tag.ALIAS, this.alias)
    try {
      const results: asset.AssetMap[] = await asset.query(query)
      if (results.length > 0) {
        await asset.remove(query)
      }
    } catch (error) {
      throw new Error('Unable to clear secure mobile session')
    }
  }
}
