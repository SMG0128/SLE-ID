<template>
  <div class="dashboard">
    <!-- 状态卡片 -->
    <el-row :gutter="16" class="status-row">
      <el-col :span="6">
        <StatusCard icon="Cpu" label="设备总数" :value="deviceStats.total" color="#409eff" />
      </el-col>
      <el-col :span="6">
        <StatusCard icon="VideoCamera" label="今日事件" :value="'128'" color="#67c23a" />
      </el-col>
      <el-col :span="6">
        <StatusCard icon="Bell" label="活跃报警" :value="alarmStats.highUrgent" color="#e6a23c" />
      </el-col>
      <el-col :span="6">
        <StatusCard icon="Connection" label="WS63 在线" :value="deviceStats.online" unit="/ {{ deviceStats.total }}" color="#909399" />
      </el-col>
    </el-row>

    <!-- 图表区域 -->
    <el-row :gutter="16" class="chart-row">
      <el-col :span="14">
        <el-card shadow="hover">
          <template #header><span>24小时事件趋势</span></template>
          <div ref="trendChartRef" class="chart"></div>
        </el-card>
      </el-col>
      <el-col :span="10">
        <el-card shadow="hover">
          <template #header><span>设备状态分布</span></template>
          <div ref="deviceChartRef" class="chart"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 最近报警 -->
    <el-row :gutter="16" class="alarm-row">
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header><span>最近报警</span></template>
          <AlarmPanel :alarms="alarmList" />
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header><span>最新事件</span></template>
          <EventTable :events="eventList" />
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick, markRaw } from 'vue'
import * as echarts from 'echarts'
import StatusCard from '@/components/StatusCard.vue'
import AlarmPanel from '@/components/AlarmPanel.vue'
import EventTable from '@/components/EventTable.vue'
import { mockDeviceList } from '@/mock/device'
import { mockAlarmList } from '@/mock/alarm'
import { mockEventList } from '@/mock/event'
import type { DeviceListResponse } from '@/types/device'
import type { AlarmRecord } from '@/types/alarm'
import type { SensingEvent } from '@/types/event'

const trendChartRef = ref<HTMLElement>()
const deviceChartRef = ref<HTMLElement>()

const deviceStats = ref({ total: 0, online: 0, offline: 0, abnormal: 0, maintenance: 0 })
const alarmList = ref<AlarmRecord[]>([])
const alarmStats = ref({ highUrgent: 0 } as { highUrgent: number })
const eventList = ref<SensingEvent[]>([])

onMounted(() => {
  // Mock 数据
  const deviceRes: DeviceListResponse = mockDeviceList({ page: 1, pageSize: 1 })
  deviceStats.value = deviceRes.stats

  const alarmRes = mockAlarmList({ page: 1, pageSize: 5 })
  alarmList.value = alarmRes.list
  alarmStats.value = alarmRes.stats

  const eventRes = mockEventList({ page: 1, pageSize: 5 })
  eventList.value = eventRes.list

  nextTick(() => {
    renderTrendChart()
    renderDeviceChart()
  })
})

function renderTrendChart() {
  if (!trendChartRef.value) return
  const chart = markRaw(echarts.init(trendChartRef.value))
  const hours = Array.from({ length: 24 }, (_, i) => `${String(i).padStart(2, '0')}:00`)
  chart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['事件数', '报警数'], bottom: 0 },
    grid: { left: 40, right: 20, top: 20, bottom: 40 },
    xAxis: { type: 'category', data: hours, boundaryGap: false },
    yAxis: { type: 'value' },
    series: [
      {
        name: '事件数',
        type: 'line',
        smooth: true,
        data: hours.map(() => Math.floor(Math.random() * 30 + 5)),
        areaStyle: { opacity: 0.15 },
        lineStyle: { color: '#409eff' },
        itemStyle: { color: '#409eff' },
      },
      {
        name: '报警数',
        type: 'line',
        smooth: true,
        data: hours.map(() => Math.floor(Math.random() * 10)),
        areaStyle: { opacity: 0.15 },
        lineStyle: { color: '#f56c6c' },
        itemStyle: { color: '#f56c6c' },
      },
    ],
  })
}

function renderDeviceChart() {
  if (!deviceChartRef.value) return
  const chart = markRaw(echarts.init(deviceChartRef.value))
  chart.setOption({
    tooltip: { trigger: 'item' },
    legend: { orient: 'vertical', right: 10, top: 'center' },
    series: [
      {
        type: 'pie',
        radius: ['50%', '75%'],
        center: ['40%', '50%'],
        label: { show: false },
        data: [
          { value: deviceStats.value.online, name: '在线', itemStyle: { color: '#67c23a' } },
          { value: deviceStats.value.offline, name: '离线', itemStyle: { color: '#c0c4cc' } },
          { value: deviceStats.value.abnormal, name: '异常', itemStyle: { color: '#f56c6c' } },
          { value: deviceStats.value.maintenance, name: '维护', itemStyle: { color: '#e6a23c' } },
        ],
      },
    ],
  })
}
</script>

<style scoped>
.dashboard {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.status-row {
  margin: 0;
}

.chart-row {
  margin: 0;
}

.alarm-row {
  margin: 0;
}

.chart {
  width: 100%;
  height: 300px;
}
</style>
