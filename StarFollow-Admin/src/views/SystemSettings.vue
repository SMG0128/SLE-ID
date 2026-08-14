<template>
  <div class="system-settings">
    <el-row :gutter="16">
      <el-col :span="12">
        <!-- 串口设置 -->
        <el-card shadow="hover" class="setting-card">
          <template #header><h3>USB 串口设置（WS63-B）</h3></template>
          <el-form :model="form.serial" label-width="110px">
            <el-form-item label="串口">
              <el-select v-model="form.serial.port" style="width:100%">
                <el-option v-for="p in portOptions" :key="p.name" :label="`${p.name} (${p.desc})`" :value="p.name" />
              </el-select>
            </el-form-item>
            <el-form-item label="波特率">
              <el-select v-model="form.serial.baudRate" style="width:100%">
                <el-option v-for="b in BAUD_RATE_OPTIONS" :key="b" :label="`${b}`" :value="b" />
              </el-select>
            </el-form-item>
            <el-form-item label="自动重连">
              <el-switch v-model="form.serial.autoReconnect" />
              <span class="desc">USB 断开后自动重连，网页不崩溃</span>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" @click="saveSerial">保存串口配置</el-button>
            </el-form-item>
          </el-form>
        </el-card>

        <!-- 管理员与保密 -->
        <el-card shadow="hover" class="setting-card">
          <template #header><h3>管理端访问令牌</h3></template>
          <el-form label-width="110px">
            <el-form-item label="管理员账号"><el-input v-model="form.adminName" disabled /></el-form-item>
            <el-form-item label="访问令牌"><el-input v-model="accessToken" type="password" show-password placeholder="与后端 STARFOLLOW_API_TOKEN 一致" /></el-form-item>
            <el-form-item>
              <el-button type="primary" @click="saveAccessToken">保存并重连</el-button>
            </el-form-item>
          </el-form>
        </el-card>
      </el-col>

      <el-col :span="12">
        <!-- 数据库 -->
        <el-card shadow="hover" class="setting-card">
          <template #header><h3>本地数据库</h3></template>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="数据库大小">{{ (db.sizeKB / 1024).toFixed(2) }} MB</el-descriptions-item>
            <el-descriptions-item label="事件记录">{{ db.eventCount }} 条</el-descriptions-item>
            <el-descriptions-item label="许可数量">{{ db.licenseCount }} 个</el-descriptions-item>
            <el-descriptions-item label="最后备份">{{ db.lastBackup || '从未备份' }}</el-descriptions-item>
          </el-descriptions>
          <div class="db-actions">
            <el-button type="success" @click="backupDb">立即备份</el-button>
            <el-tooltip content="当前后端未提供安全的数据库下载接口"><el-button disabled>导出数据库</el-button></el-tooltip>
          </div>
        </el-card>

        <!-- 服务器同步预留 -->
        <el-card shadow="hover" class="setting-card">
          <template #header><h3>第二版：服务器同步（预留）</h3></template>
          <el-form label-width="110px">
            <el-form-item label="启用同步">
              <el-switch v-model="syncEnabled" @change="saveSync" />
            </el-form-item>
          </el-form>
          <el-alert type="info" :closable="false" show-icon title="第二版将后端/同步模块部署至服务器，扩展多地点管理。本版通过 ServerAdapter 抽象接口与同步队列预留，不影响本地第一版。" />
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getSystemSettings, updateSerialConfig, updateServerSync, getSerialPortOptions, backupDatabase } from '@/api/system'
import { getAccessToken, setAccessToken } from '@/api/request'
import { reconnectEventSocket } from '@/api/websocket'
import { BAUD_RATE_OPTIONS, type SystemSettings, type SerialPortOption } from '@/types/system'

const form = reactive<SystemSettings>({
  serial: { port: 'COM3', baudRate: 115200, autoReconnect: true },
  db: { sizeKB: 0, eventCount: 0, licenseCount: 0, lastBackup: null },
  serverSyncEnabled: false,
  adminName: '',
  adminSecret: '',
})
const portOptions = ref<SerialPortOption[]>([])
const syncEnabled = ref(false)
const accessToken = ref(getAccessToken())

// 用于展示的数据库信息
const db = reactive({ sizeKB: 0, eventCount: 0, licenseCount: 0, lastBackup: null as string | null })

onMounted(async () => {
  const [settings, ports] = await Promise.all([getSystemSettings(), getSerialPortOptions()])
  Object.assign(form, settings)
  Object.assign(db, settings.db)
  syncEnabled.value = settings.serverSyncEnabled
  portOptions.value = ports
})

async function saveSerial() {
  const updated = await updateSerialConfig({ ...form.serial })
  form.serial = updated
  ElMessage.success('串口配置已保存')
}

function saveAccessToken() {
  setAccessToken(accessToken.value)
  reconnectEventSocket()
  ElMessage.success('访问令牌已保存，实时链路正在重连')
}

async function backupDb() {
  const result = await backupDatabase() as { createdAt?: string }
  db.lastBackup = result.createdAt || new Date().toISOString()
  ElMessage.success('数据库备份完成')
}

async function saveSync() {
  await updateServerSync(syncEnabled.value)
  ElMessage.success(syncEnabled.value ? '服务器同步已启用（预留）' : '服务器同步已关闭')
}
</script>

<style scoped>
.system-settings { max-width: 1400px; }
.setting-card { margin-bottom: 16px; }
.setting-card h3 { margin: 0; }
.desc { margin-left: 8px; color: #909399; font-size: 12px; }
.db-actions { margin-top: 16px; display: flex; gap: 12px; }
</style>
