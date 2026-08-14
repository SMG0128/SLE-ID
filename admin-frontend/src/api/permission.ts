import request from './request'
import type { License, CreateLicenseForm } from '@/types/license'

/** 获取许可列表 */
export function getLicenses(): Promise<License[]> {
  return request.get<never, License[]>('/licenses')
}

/** 创建许可（组合策略） */
export function createLicense(form: CreateLicenseForm, creator: string): Promise<License> {
  return request.post<never, License>('/licenses', { ...form, creator })
}

/** 吊销许可 */
export function revokeLicense(id: string): Promise<void> {
  return request.post<never, void>(`/licenses/${encodeURIComponent(id)}/revoke`)
}

export function deployLicense(id: string, organizationId = 100): Promise<Record<string, unknown>> {
  return request.post<never, Record<string, unknown>>(`/licenses/${encodeURIComponent(id)}/deploy`, { organizationId })
}
