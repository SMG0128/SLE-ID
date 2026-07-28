<template>
  <div class="device-manage">
    <!-- WS63 通信状态 -->
    <el-card shadow="hover" class="ws-status" v-loading="loading">
      <div class="ws-status__inner">
        <div class="ws-status__icon">
          <el-icon :size="32" color="#67c23a"><Connection /></el-icon>
        </div>
        <div class="ws-status__info">
          <h3>WS63 通信模块</h3>
          <span>协议: {{ ws.protocol }} | 频段: {{ ws.band }} | 节点数: {{ ws.nodes }} | 延迟: {{ ws.latency }}ms</span>
        </div>
        <el-tag :type="ws.status === '正常' ? 'success' : 'danger'" size="large" effect="dark">
          {{ ws.status === '正常' ? '运行正常' : '异常' }}
        </el-tag>
      </div>
    </el-card>

    <!-- 设备列表 -->
    <el-card shadow="hover">
      <el-table :data="devices" stripe border v-loading="loading">
        <el-table-column prop="id" label="设备ID" width="100" />
        <el-table-column prop="name" label="名称" width="150" />
        <el-table-column prop="location" label="位置" width="120" />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status === '在线' ? 'success' : 'danger'">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="firmware" label="固件版本" width="110" />
        <el-table-column label="心跳" width="80">
          <template #default="{ row }">
            <span :style="{ color: row.heartbeat < 10 ? '#67c23a' : '#e6a23c' }">{{ row.heartbeat }}s</span>
          </template>
        </el-table-column>
        <el-table-column label="USB状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.usbConnected ? 'success' : 'info'">{{ row.usbConnected ? '已连接' : '未连接' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="policyVersion" label="策略版本" width="100" />
        <el-table-column prop="uptime" label="运行时长" width="100" />
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="restart(row)">重启</el-button>
            <el-button size="small" type="primary" @click="updatePolicy(row)">更新策略</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Connection } from '@element-plus/icons-vue'
import { getDeviceList, getWS63Status, restartDevice } from '@/api/device'
import type { Device, WS63Status } from '@/types/device'

const devices = ref<Device[]>([])
const ws = ref<WS63Status>({ protocol: '', band: '', nodes: 0, latency: 0, status: '正常' })
const loading = ref(true)

async function loadData() {
  loading.value = true
  const [devRes, wsRes] = await Promise.all([getDeviceList(), getWS63Status()])
  devices.value = devRes.list
  ws.value = wsRes
  loading.value = false
}

async function restart(row: Device) {
  await restartDevice(row.id)
  ElMessage.success(`检测端 ${row.name} 重启指令已发送 (WS63)`)
}

function updatePolicy(row: Device) {
  ElMessage.success(`策略已更新至 ${row.policyVersion}`)
}

onMounted(loadData)
</script>

<style scoped>
.device-manage { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.ws-status__inner { display: flex; align-items: center; gap: 16px; }
.ws-status__info h3 { margin: 0 0 4px 0; font-size: 16px; }
.ws-status__info span { font-size: 13px; color: #909399; }
.ws-status__icon { display: flex; align-items: center; }
</style>
