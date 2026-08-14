<template>
  <div class="confirmation-center">
    <el-row :gutter="16">
      <el-col :span="8"><el-card shadow="hover"><el-statistic title="待确认" :value="list.length" /></el-card></el-col>
      <el-col :span="8"><el-card shadow="hover"><el-statistic title="即将超时（≤10秒）" :value="urgentCount" /></el-card></el-col>
      <el-col :span="8"><el-card shadow="hover"><el-statistic title="实时连接" :value="socketConnected ? '已连接' : '重连中'" /></el-card></el-col>
    </el-row>

    <el-card shadow="hover">
      <template #header>
        <div class="toolbar">
          <span>管理端二次确认</span>
          <el-button :loading="loading" @click="loadData">刷新</el-button>
        </div>
      </template>
      <el-alert v-if="!list.length" type="success" :closable="false" show-icon title="当前没有等待处理的确认请求" />
      <el-table v-else :data="list" stripe border v-loading="loading">
        <el-table-column prop="eventId" label="事件" width="90" />
        <el-table-column prop="cardId" label="卡片" width="150" />
        <el-table-column prop="permissionId" label="许可ID" width="100" />
        <el-table-column prop="receivedAt" label="收到时间" min-width="180">
          <template #default="{ row }">{{ formatTime(row.receivedAt) }}</template>
        </el-table-column>
        <el-table-column label="剩余时间" width="120">
          <template #default="{ row }"><el-tag :type="remainingMs(row) <= 10000 ? 'danger' : 'warning'">{{ remainingText(row) }}</el-tag></template>
        </el-table-column>
        <el-table-column label="操作" width="190" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="success" :loading="sendingId === row.id" @click="decide(row, 'approve')">允许</el-button>
            <el-button size="small" type="danger" :loading="sendingId === row.id" @click="decide(row, 'reject')">拒绝</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { decideConfirmation, getPendingConfirmations } from '@/api/confirmation'
import { onEventMessage, onSocketState } from '@/api/websocket'
import type { PendingConfirmation } from '@/types/confirmation'

const list = ref<PendingConfirmation[]>([])
const loading = ref(false)
const sendingId = ref('')
const socketConnected = ref(false)
const now = ref(Date.now())
const urgentCount = computed(() => list.value.filter(item => remainingMs(item) <= 10000).length)

async function loadData() {
  loading.value = true
  try { list.value = await getPendingConfirmations() } finally { loading.value = false }
}

async function decide(row: PendingConfirmation, decision: 'approve' | 'reject') {
  const verb = decision === 'approve' ? '允许' : '拒绝'
  try {
    await ElMessageBox.confirm(`确定${verb}卡片 ${row.cardId} 的本次请求？`, `${verb}执行`, { type: decision === 'approve' ? 'warning' : 'error' })
    sendingId.value = row.id
    const result = await decideConfirmation(row.id, decision)
    if (!result.success) throw new Error(`硬件返回状态 ${result.status}`)
    list.value = list.value.filter(item => item.id !== row.id)
    ElMessage.success(`${verb}结果已由 Detector B 接收`)
  } catch (error) {
    if (error !== 'cancel' && error !== 'close') await loadData()
  } finally { sendingId.value = '' }
}

function remainingMs(row: PendingConfirmation) { return Math.max(0, Date.parse(row.expiresAt) - now.value) }
function remainingText(row: PendingConfirmation) { return `${Math.ceil(remainingMs(row) / 1000)} 秒` }
function formatTime(value: string) { return new Date(value).toLocaleString('zh-CN', { hour12: false }) }

let clock: ReturnType<typeof setInterval> | null = null
let unsubscribeMessage: (() => void) | null = null
let unsubscribeState: (() => void) | null = null
onMounted(() => {
  loadData()
  clock = setInterval(() => {
    now.value = Date.now()
    if (list.value.some(item => remainingMs(item) === 0)) loadData()
  }, 1000)
  unsubscribeState = onSocketState(connected => { socketConnected.value = connected })
  unsubscribeMessage = onEventMessage(message => {
    if (message.topic === 'confirmation.pending' || message.topic === 'confirmation.resolved') loadData()
  })
})
onUnmounted(() => {
  if (clock) clearInterval(clock)
  unsubscribeMessage?.()
  unsubscribeState?.()
})
</script>

<style scoped>
.confirmation-center { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.toolbar { display: flex; align-items: center; justify-content: space-between; font-weight: 600; }
</style>
