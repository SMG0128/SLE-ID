<template>
  <div class="event-monitor">
    <!-- 统计卡片：纯 HTML/CSS，不依赖 el-statistic -->
    <div class="stats-row">
      <div class="stat-card">
        <div class="stat-card__label">活跃检测</div>
        <div class="stat-card__value color-primary">{{ activeCount }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-card__label">区域内</div>
        <div class="stat-card__value color-warning">{{ inZoneCount }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-card__label">已完成</div>
        <div class="stat-card__value color-success">{{ completedCount }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-card__label">更新间隔</div>
        <div class="stat-card__value color-info">5<span class="unit">秒</span></div>
      </div>
    </div>

    <!-- 控制栏 -->
    <div class="control-bar">
      <span class="control-bar__title">实时检测 — 星闪主动感知</span>
      <el-switch v-model="autoRefresh" active-text="自动刷新" inactive-text="暂停" />
      <el-tag :type="autoRefresh ? 'success' : 'info'" effect="dark">
        {{ autoRefresh ? '● 实时监控中' : '○ 已暂停' }}
      </el-tag>
    </div>

    <!-- 状态图例 -->
    <div class="legend">
      <span class="legend__title">状态流转：</span>
      <span v-for="s in statusOrder" :key="s" class="legend__item">
        <i class="legend__dot" :style="{ background: statusDotColor(s) }"></i>{{ statusLabel(s) }}
      </span>
    </div>

    <!-- 事件表格：纯 HTML 表格，避免 el-table 实时重渲染故障 -->
    <div class="table-card">
      <table class="rt-table">
        <thead>
          <tr>
            <th>事件ID</th>
            <th>卡片ID</th>
            <th>检测端</th>
            <th>当前状态</th>
            <th>认证结果</th>
            <th>时间</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in events" :key="row.eventId">
            <td class="mono">{{ row.eventId }}</td>
            <td><span class="card-tag">{{ row.cardId }}</span></td>
            <td>{{ row.device }}</td>
            <td><span class="status-pill" :style="statusPillStyle(row.status)">{{ statusLabel(row.status) }}</span></td>
            <td>
              <span v-if="row.authResult" class="status-pill" :style="authPillStyle(row.authResult)">{{ row.authResult }}</span>
              <span v-else class="muted">—</span>
            </td>
            <td class="mono muted">{{ row.time }}</td>
          </tr>
          <tr v-if="!events.length">
            <td colspan="6" class="empty-tip">暂无检测事件，等待实时数据产生…</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'

type Status = 'IDLE' | 'APPROACHING' | 'IN_ZONE' | 'COMPLETED' | 'COOLDOWN'
type AuthResult = '' | '成功' | '失败'

interface RealtimeEvent {
  eventId: string
  cardId: string
  device: string
  status: Status
  authResult: AuthResult
  time: string
}

const cardPool = ['CARD001', 'CARD002', 'CARD003', 'CARD004', 'CARD005', 'CARD006', 'CARD007', 'CARD008', 'CARD009', 'CARD010']
const devicePool = ['正门检测端', '走廊检测端', '机房检测端', '车库检测端', '会议室检测端', '仓库检测端']
const statusOrder: Status[] = ['IDLE', 'APPROACHING', 'IN_ZONE', 'COMPLETED', 'COOLDOWN']

const events = ref<RealtimeEvent[]>([])
const autoRefresh = ref(true)
const eventCounter = ref(1)

const activeCount = computed(() => events.value.filter(e => e.status !== 'COOLDOWN' && e.status !== 'COMPLETED').length)
const inZoneCount = computed(() => events.value.filter(e => e.status === 'IN_ZONE').length)
const completedCount = computed(() => events.value.filter(e => e.status === 'COMPLETED' || e.status === 'COOLDOWN').length)

function now() {
  return new Date().toLocaleString('zh-CN')
}

// 模拟引擎：每 5 秒推进一次生命周期（不可变更新，稳定可靠）
function tick() {
  const next = events.value
    .map(event => {
      const idx = statusOrder.indexOf(event.status)
      if (idx < 0 || idx >= statusOrder.length - 1) return event
      const nextStatus = statusOrder[idx + 1]
      return {
        ...event,
        status: nextStatus,
        authResult: nextStatus === 'COMPLETED' ? (Math.random() > 0.1 ? '成功' : '失败') as AuthResult : event.authResult,
        time: now(),
      }
    })
    .filter(event => event.status !== 'COOLDOWN')

  if (autoRefresh.value) {
    const count = Math.random() > 0.4 ? 1 : 2
    for (let i = 0; i < count; i += 1) {
      next.push({
        eventId: `EV-${String(eventCounter.value).padStart(6, '0')}`,
        cardId: cardPool[Math.floor(Math.random() * cardPool.length)],
        device: devicePool[Math.floor(Math.random() * devicePool.length)],
        status: 'IDLE',
        authResult: '',
        time: now(),
      })
      eventCounter.value += 1
    }
  }

  events.value = next.slice(-20)
}

// ---- 辅助 ----
function statusLabel(s: Status) {
  const map: Record<Status, string> = { IDLE: '待命中', APPROACHING: '接近中', IN_ZONE: '区域内', COMPLETED: '已完成', COOLDOWN: '冷却中' }
  return map[s]
}
function statusDotColor(s: Status) {
  const map: Record<Status, string> = { IDLE: '#909399', APPROACHING: '#409eff', IN_ZONE: '#e6a23c', COMPLETED: '#67c23a', COOLDOWN: '#c0c4cc' }
  return map[s]
}
function statusPillStyle(s: Status) {
  const c = statusDotColor(s)
  return { color: c, background: c + '1a', border: `1px solid ${c}40` }
}
function authPillStyle(r: AuthResult) {
  const c = r === '成功' ? '#67c23a' : '#f56c6c'
  return { color: c, background: c + '1a', border: `1px solid ${c}40` }
}

let timer: ReturnType<typeof setInterval> | null = null

onMounted(() => {
  tick()
  timer = setInterval(tick, 5000)
})

onUnmounted(() => {
  if (timer) {
    clearInterval(timer)
    timer = null
  }
})
</script>

<style scoped>
.event-monitor {
  max-width: 1400px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* 统计卡片 */
.stats-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}
.stat-card {
  background: #fff;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}
.stat-card__label {
  font-size: 13px;
  color: #909399;
  margin-bottom: 8px;
}
.stat-card__value {
  font-size: 30px;
  font-weight: 700;
  line-height: 1.2;
}
.stat-card__value .unit {
  font-size: 14px;
  font-weight: 400;
  margin-left: 4px;
}
.color-primary { color: #409eff; }
.color-warning { color: #e6a23c; }
.color-success { color: #67c23a; }
.color-info { color: #606266; }

/* 控制栏 */
.control-bar {
  background: #fff;
  border-radius: 8px;
  padding: 14px 20px;
  display: flex;
  align-items: center;
  gap: 16px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}
.control-bar__title {
  font-size: 16px;
  font-weight: 600;
  margin-right: auto;
}

/* 状态图例 */
.legend {
  background: #fff;
  border-radius: 8px;
  padding: 10px 20px;
  display: flex;
  align-items: center;
  gap: 18px;
  flex-wrap: wrap;
  font-size: 13px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}
.legend__title { color: #606266; font-weight: 600; }
.legend__item { display: inline-flex; align-items: center; gap: 6px; color: #606266; }
.legend__dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; }

/* 表格 */
.table-card {
  background: #fff;
  border-radius: 8px;
  padding: 16px 20px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
  overflow-x: auto;
}
.rt-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}
.rt-table th,
.rt-table td {
  text-align: left;
  padding: 10px 12px;
  border-bottom: 1px solid #ebeef5;
  white-space: nowrap;
}
.rt-table th {
  background: #fafafa;
  color: #606266;
  font-weight: 600;
  border-bottom: 1px solid #dcdfe6;
}
.rt-table tbody tr:hover {
  background: #f5f7fa;
}
.mono { font-family: monospace; }
.card-tag {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 4px;
  background: #303133;
  color: #fff;
  font-size: 12px;
  font-family: monospace;
}
.status-pill {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 10px;
  font-size: 12px;
  white-space: nowrap;
}
.muted { color: #c0c4cc; }
.empty-tip {
  padding: 40px 0;
  text-align: center;
  color: #909399;
  font-size: 14px;
}
</style>
