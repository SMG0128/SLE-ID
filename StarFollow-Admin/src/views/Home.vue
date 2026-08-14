<template>
  <div class="dashboard">
    <!-- 系统状态头 -->
    <el-card shadow="hover" class="status-bar">
      <div class="status-bar__inner">
        <div class="status-bar__title">
          <h2>星闪检测系统</h2>
          <el-tag :type="serial.detectorBReady ? 'success' : 'warning'" size="large" effect="dark">
            <el-icon class="pulse-icon"><CircleCheckFilled /></el-icon> {{ serial.detectorBReady ? '硬件在线' : '等待 Detector B' }}
          </el-tag>
        </div>
        <div class="status-bar__meta">
          <span>网关: <strong>{{ serial.detectorBReady ? '心跳正常' : '未就绪' }}</strong></span>
          <el-divider direction="vertical" />
          <span>串口: <strong :style="{ color: serial.connected ? '#67c23a' : '#f56c6c' }">{{ serial.connected ? `${serial.port} 已连接` : '未连接' }}</strong></span>
          <el-divider direction="vertical" />
          <span>数据库: <strong style="color:#67c23a">正常</strong></span>
        </div>
      </div>
    </el-card>

    <!-- 数据卡片 -->
    <el-row :gutter="16" class="card-row">
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-card--total">
          <div class="stat-card__icon"><el-icon :size="28"><TrendCharts /></el-icon></div>
          <div class="stat-card__body">
            <div class="stat-card__label">今日事件</div>
            <div class="stat-card__value">{{ eventTotal }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-card--success">
          <div class="stat-card__icon"><el-icon :size="28"><CircleCheck /></el-icon></div>
          <div class="stat-card__body">
            <div class="stat-card__label">成功</div>
            <div class="stat-card__value">{{ successCount }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-card--danger">
          <div class="stat-card__icon"><el-icon :size="28"><WarningFilled /></el-icon></div>
          <div class="stat-card__body">
            <div class="stat-card__label">异常</div>
            <div class="stat-card__value">{{ failureCount }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-card--info">
          <div class="stat-card__icon"><el-icon :size="28"><Cpu /></el-icon></div>
          <div class="stat-card__body">
            <div class="stat-card__label">在线设备</div>
            <div class="stat-card__value">{{ onlineDeviceCount }}</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 最近事件 -->
    <el-card shadow="hover" class="recent-events">
      <template #header>
        <div class="card-header">
          <h3>最近事件</h3>
          <el-button text type="primary" @click="$router.push('/realtime-events')">查看全部</el-button>
        </div>
      </template>
      <el-table :data="recentEvents" stripe>
        <el-table-column prop="time" label="时间" width="180" />
        <el-table-column prop="eventId" label="事件ID" width="110" />
        <el-table-column prop="device" label="检测端" width="140" />
        <el-table-column prop="cardId" label="匿名卡ID" width="130" />
        <el-table-column label="结果" width="90">
          <template #default="{ row }">
            <el-tag size="small" :type="row.result === '成功' ? 'success' : row.result === '失败' ? 'danger' : 'info'">{{ row.result }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" min-width="120" show-overflow-tooltip />
      </el-table>
    </el-card>

    <!-- ECharts 图表区 -->
    <el-row :gutter="16" class="chart-row">
      <el-col :span="14">
        <el-card shadow="hover">
          <template #header><h3>今日事件趋势</h3></template>
          <div ref="trendChartRef" class="chart-box"></div>
        </el-card>
      </el-col>
      <el-col :span="10">
        <el-card shadow="hover">
          <template #header><h3>异常统计</h3></template>
          <div ref="anomalyChartRef" class="chart-box"></div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts/core'
import { LineChart, PieChart } from 'echarts/charts'
import { GridComponent, LegendComponent, TooltipComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import { CircleCheckFilled, CircleCheck, TrendCharts, WarningFilled, Cpu } from '@element-plus/icons-vue'
import { getEventList } from '@/api/event'
import { getSerialStatus, getDeviceList } from '@/api/device'
import { getAlarmList } from '@/api/alarm'
import type { EventLogItem } from '@/types/event'
import type { SerialStatus } from '@/types/device'
import type { AlarmStats } from '@/types/alarm'

echarts.use([LineChart, PieChart, GridComponent, LegendComponent, TooltipComponent, CanvasRenderer])

// ---- 最近事件（真实 REST API）----
const recentEvents = ref<EventLogItem[]>([])
const eventTotal = ref(0)
const successCount = ref(0)
const failureCount = ref(0)
const onlineDeviceCount = ref(0)
const dashboardEvents = ref<EventLogItem[]>([])
const alarmStats = ref<AlarmStats>({ severe: 0, high: 0, normal: 0, total: 0, unhandled: 0 })

// ---- 系统状态（串口/数据库）----
const serial = ref<SerialStatus>({ connected: false, port: '-', baudRate: 0, autoReconnect: false, lastFrameAt: null, frameCount: 0, errorCount: 0 })

// ---- ECharts 实例 ----
const trendChartRef = ref<HTMLDivElement>()
const anomalyChartRef = ref<HTMLDivElement>()
let trendChart: echarts.ECharts | null = null
let anomalyChart: echarts.ECharts | null = null

function initTrendChart() {
  if (!trendChartRef.value) return
  trendChart = echarts.init(trendChartRef.value)

  const hours = ['00:00','02:00','04:00','06:00','08:00','10:00','12:00','14:00','16:00','18:00','20:00','22:00']
  const successData = Array<number>(12).fill(0)
  const anomalyData = Array<number>(12).fill(0)
  for (const item of dashboardEvents.value) {
    const hour = Number(item.time.slice(0, 2))
    if (!Number.isInteger(hour) || hour < 0 || hour > 23) continue
    const bucket = Math.floor(hour / 2)
    if (item.result === '成功') successData[bucket] += 1
    else if (item.result === '失败') anomalyData[bucket] += 1
  }

  trendChart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['成功', '异常'], bottom: 0 },
    grid: { top: 10, right: 20, bottom: 40, left: 50 },
    xAxis: { type: 'category', data: hours, boundaryGap: false },
    yAxis: { type: 'value' },
    series: [
      {
        name: '成功', type: 'line', smooth: true,
        data: successData, lineStyle: { color: '#67c23a' },
        itemStyle: { color: '#67c23a' },
        areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: 'rgba(103,194,58,0.3)' },
          { offset: 1, color: 'rgba(103,194,58,0.02)' },
        ])},
      },
      {
        name: '异常', type: 'line', smooth: true,
        data: anomalyData, lineStyle: { color: '#f56c6c' },
        itemStyle: { color: '#f56c6c' },
        areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: 'rgba(245,108,108,0.3)' },
          { offset: 1, color: 'rgba(245,108,108,0.02)' },
        ])},
      },
    ],
  })
}

function initAnomalyChart() {
  if (!anomalyChartRef.value) return
  anomalyChart = echarts.init(anomalyChartRef.value)

  anomalyChart.setOption({
    tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
    legend: { orient: 'vertical', right: 10, top: 'center' },
    series: [{
      type: 'pie',
      radius: ['50%', '75%'],
      avoidLabelOverlap: false,
      itemStyle: { borderRadius: 4, borderColor: '#fff', borderWidth: 2 },
      label: { show: false },
      emphasis: { label: { show: true, fontSize: 16 } },
      data: alarmStats.value.total > 0 ? [
        { value: alarmStats.value.severe, name: '严重', itemStyle: { color: '#f56c6c' } },
        { value: alarmStats.value.high, name: '高', itemStyle: { color: '#e6a23c' } },
        { value: alarmStats.value.normal, name: '普通', itemStyle: { color: '#409eff' } },
      ].filter(item => item.value > 0) : [{ value: 1, name: '暂无报警', itemStyle: { color: '#dcdfe6' } }],
    }],
  })
}

// ---- 生命周期 ----
onMounted(async () => {
  const now = new Date()
  const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
  const [events, successes, failures, alarms, serialState, devices] = await Promise.all([
    getEventList({ page: 1, pageSize: 200, dateStart: today, dateEnd: today }),
    getEventList({ page: 1, pageSize: 1, dateStart: today, dateEnd: today, result: '成功' }),
    getEventList({ page: 1, pageSize: 1, dateStart: today, dateEnd: today, result: '失败' }),
    getAlarmList({ page: 1, pageSize: 1 }),
    getSerialStatus(),
    getDeviceList(),
  ])
  dashboardEvents.value = events.list
  recentEvents.value = events.list.slice(0, 6)
  eventTotal.value = events.total
  successCount.value = successes.total
  failureCount.value = failures.total
  alarmStats.value = alarms.stats
  serial.value = serialState
  onlineDeviceCount.value = devices.list.filter(device => device.status === '在线').length

  await nextTick()
  initTrendChart()
  initAnomalyChart()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  trendChart?.dispose()
  anomalyChart?.dispose()
})

function handleResize() {
  trendChart?.resize()
  anomalyChart?.resize()
}
</script>

<style scoped>
.dashboard {
  max-width: 1400px;
}
h3 { margin: 0; }

/* 状态头 */
.status-bar {
  margin-bottom: 16px;
}
.status-bar__inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.status-bar__title {
  display: flex;
  align-items: center;
  gap: 16px;
}
.status-bar__title h2 {
  margin: 0;
  font-size: 20px;
  color: #303133;
}
.pulse-icon {
  animation: pulse 2s infinite;
}
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}
.status-bar__meta {
  display: flex;
  align-items: center;
  color: #606266;
  font-size: 13px;
}

/* 数据卡片 */
.card-row {
  margin: 0 0 16px 0 !important;
}
.stat-card {
  --card-color: #409eff;
}
.stat-card--total  { --card-color: #409eff; }
.stat-card--success { --card-color: #67c23a; }
.stat-card--danger  { --card-color: #f56c6c; }
.stat-card--info    { --card-color: #909399; }

.stat-card :deep(.el-card__body) {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
}
.stat-card__icon {
  width: 52px; height: 52px;
  display: flex; align-items: center; justify-content: center;
  border-radius: 12px;
  color: var(--card-color);
  background: var(--card-color);
  background: color-mix(in srgb, var(--card-color) 15%, #fff 85%);
}
.stat-card__label {
  font-size: 13px; color: #909399;
}
.stat-card__value {
  font-size: 30px; font-weight: 700; color: var(--card-color); line-height: 1.2;
}

/* 最近事件 */
.recent-events { margin-bottom: 16px; }
.card-header {
  display: flex; align-items: center; justify-content: space-between;
}

/* 图表区 */
.chart-row { margin: 0 !important; }
.chart-box {
  width: 100%;
  height: 320px;
}
</style>
