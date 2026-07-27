<template>
  <el-timeline class="alarm-panel">
    <el-timeline-item
      v-for="alarm in alarms"
      :key="alarm.id"
      :timestamp="alarm.createdAt"
      placement="top"
      :color="levelColor(alarm.level)"
    >
      <div class="alarm-item">
        <div class="alarm-item__header">
          <el-tag size="small" :type="levelTagType(alarm.level)">
            {{ LevelLabel[alarm.level as AlarmLevel] }}
          </el-tag>
          <span class="alarm-item__device">{{ alarm.deviceName }}</span>
        </div>
        <p class="alarm-item__msg">{{ alarm.message }}</p>
        <div class="alarm-item__meta">
          <span>当前值: {{ alarm.value }}</span>
          <span>阈值: {{ alarm.threshold }}</span>
          <el-tag size="small" :type="handleTagType(alarm.handleStatus)">
            {{ HandleLabel[alarm.handleStatus as AlarmHandleStatus] }}
          </el-tag>
        </div>
      </div>
    </el-timeline-item>
    <el-empty v-if="!alarms.length" description="暂无报警" />
  </el-timeline>
</template>

<script setup lang="ts">
import type { AlarmRecord } from '@/types/alarm'
import { AlarmLevel, AlarmHandleStatus } from '@/types/alarm'

defineProps<{
  alarms: AlarmRecord[]
}>()

const LevelLabel: Record<AlarmLevel, string> = {
  [AlarmLevel.Low]: '低',
  [AlarmLevel.Medium]: '中',
  [AlarmLevel.High]: '高',
  [AlarmLevel.Urgent]: '紧急',
}

const HandleLabel: Record<AlarmHandleStatus, string> = {
  [AlarmHandleStatus.Unconfirmed]: '未确认',
  [AlarmHandleStatus.Confirmed]: '已确认',
  [AlarmHandleStatus.Processing]: '处理中',
  [AlarmHandleStatus.Resolved]: '已解决',
}

function levelColor(l: AlarmLevel) {
  const map: Record<AlarmLevel, string> = { low: '#67c23a', medium: '#e6a23c', high: '#f56c6c', urgent: '#ff0000' }
  return map[l] || '#ccc'
}

function levelTagType(l: AlarmLevel) {
  return l === AlarmLevel.Urgent || l === AlarmLevel.High ? 'danger' : l === AlarmLevel.Medium ? 'warning' : 'success'
}

function handleTagType(s: AlarmHandleStatus) {
  return s === AlarmHandleStatus.Resolved ? 'success' : s === AlarmHandleStatus.Unconfirmed ? 'danger' : 'warning'
}
</script>

<style scoped>
.alarm-item {
  padding: 4px 0;
}

.alarm-item__header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
}

.alarm-item__device {
  font-weight: 600;
  color: #303133;
}

.alarm-item__msg {
  color: #606266;
  font-size: 14px;
  margin: 4px 0;
}

.alarm-item__meta {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 12px;
  color: #909399;
}
</style>
