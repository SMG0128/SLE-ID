<template>
  <div class="event-table">
    <el-table
      :data="events"
      stripe
      border
      style="width: 100%"
      @row-click="(row: SensingEvent) => emit('rowClick', row)"
    >
      <el-table-column prop="title" label="事件标题" min-width="180" show-overflow-tooltip />
      <el-table-column prop="deviceName" label="设备" width="140" />
      <el-table-column prop="location" label="位置" width="120" />
      <el-table-column label="类型" width="110">
        <template #default="{ row }">
          <el-tag size="small" type="info">{{ EventTypeLabel[row.type as EventType] }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="严重性" width="90">
        <template #default="{ row }">
          <el-tag size="small" :type="severityTagType(row.severity)">
            {{ SeverityLabel[row.severity as EventSeverity] }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag size="small" :type="statusTagType(row.status)">
            {{ StatusLabel[row.status as EventStatus] }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="数值" width="100">
        <template #default="{ row }">
          {{ row.value }}{{ row.unit }}
        </template>
      </el-table-column>
      <el-table-column prop="createdAt" label="时间" width="170" />
    </el-table>
  </div>
</template>

<script setup lang="ts" generic="T extends SensingEvent">
import type { SensingEvent } from '@/types/event'
import { EventType, EventSeverity, EventStatus } from '@/types/event'

defineProps<{
  events: SensingEvent[]
}>()

const emit = defineEmits<{
  rowClick: [row: SensingEvent]
}>()

const EventTypeLabel: Record<EventType, string> = {
  [EventType.Motion]: '运动',
  [EventType.Sound]: '声音',
  [EventType.Temperature]: '温度',
  [EventType.Humidity]: '湿度',
  [EventType.Vibration]: '振动',
  [EventType.Intrusion]: '入侵',
  [EventType.Other]: '其他',
}

const SeverityLabel: Record<EventSeverity, string> = {
  [EventSeverity.Info]: '信息',
  [EventSeverity.Warning]: '警告',
  [EventSeverity.Critical]: '严重',
}

const StatusLabel: Record<EventStatus, string> = {
  [EventStatus.Pending]: '待处理',
  [EventStatus.Processing]: '处理中',
  [EventStatus.Resolved]: '已解决',
  [EventStatus.Ignored]: '已忽略',
}

function severityTagType(s: EventSeverity) {
  return s === EventSeverity.Critical ? 'danger' : s === EventSeverity.Warning ? 'warning' : 'info'
}

function statusTagType(s: EventStatus) {
  return s === EventStatus.Resolved ? 'success' : s === EventStatus.Processing ? 'warning' : s === EventStatus.Ignored ? 'info' : 'danger'
}
</script>
