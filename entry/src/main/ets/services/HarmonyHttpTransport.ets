import { http } from '@kit.NetworkKit'
import {
  MobileHttpRequest,
  MobileHttpResponse,
  MobileHttpTransport
} from './MobileApiContracts'

export class HarmonyHttpTransport implements MobileHttpTransport {
  private readonly baseUrl: string

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl.endsWith('/') ?
      baseUrl.substring(0, baseUrl.length - 1) : baseUrl
  }

  async send(request: MobileHttpRequest): Promise<MobileHttpResponse> {
    const client: http.HttpRequest = http.createHttp()
    try {
      const header: Map<string, string> = new Map<string, string>()
      header.set('Content-Type', 'application/json')
      header.set('Accept', 'application/json')
      if (request.accessToken.length > 0) {
        header.set('Authorization', `Bearer ${request.accessToken}`)
      }
      const response: http.HttpResponse = await client.request(
        `${this.baseUrl}${request.path}`,
        {
          method: request.method as http.RequestMethod,
          header: header as Object,
          extraData: request.body,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 10000,
          readTimeout: 15000,
          usingCache: false
        }
      )
      return {
        statusCode: response.responseCode as number,
        body: response.result as string
      }
    } catch (error) {
      throw new Error('Mobile backend network request failed')
    } finally {
      client.destroy()
    }
  }
}
