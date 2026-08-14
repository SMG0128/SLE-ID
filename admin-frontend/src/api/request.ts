/** StarFollow 后端 Axios 实例。 */
import axios, { type AxiosInstance, type AxiosResponse, type InternalAxiosRequestConfig } from 'axios'
import { ElMessage } from 'element-plus'

const TOKEN_KEY = 'starfollow.apiToken'

export function getAccessToken(): string {
  return localStorage.getItem(TOKEN_KEY)?.trim() || import.meta.env.VITE_STARFOLLOW_API_TOKEN?.trim() || ''
}

export function setAccessToken(token: string): void {
  const value = token.trim()
  if (value) localStorage.setItem(TOKEN_KEY, value)
  else localStorage.removeItem(TOKEN_KEY)
}

const service: AxiosInstance = axios.create({
  baseURL: '/api',
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
})

service.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = getAccessToken()
    if (token) config.headers.Authorization = `Bearer ${token}`
    return config
  },
  (error) => Promise.reject(error),
)

service.interceptors.response.use(
  (response: AxiosResponse) => {
    const { data } = response
    if (data.code !== 0) {
      ElMessage.error(data.message || '请求失败')
      return Promise.reject(new Error(data.message))
    }
    return data.data
  },
  (error) => {
    const message = error.response?.data?.message || (error.response?.status === 401 ? '访问令牌无效或未配置' : error.message) || '网络异常'
    ElMessage.error(message)
    return Promise.reject(error)
  },
)

export default service
