<template>
  <div class="device-manage">
    <!-- WS63 通信状态 -->
    <el-card shadow="hover" class="ws-status">
      <div class="ws-status__inner">
        <div class="ws-status__icon">
          <el-icon :size="32" color="#67c23a"><Connection /></el-icon>
        </div>
        <div class="ws-status__info">
          <h3>WS63 通信模块</h3>
          <span>协议: WS63 v2.4 | 频段: 2.4GHz | 节点数: 6 | 延迟: 12ms</span>
        </div>
        <el-tag type="success" size="large" effect="dark">运行正常</el-tag>
      </div>
    </el-card>

    <!-- 设备列表 -->
    <el-card shadow="hover">
      <el-table :data="devices" stripe border>
        <el-table-column prop="id" label="设备ID" width="100" />
        <el-table-column prop="name" label="名称" width="150" />
        <el-table-column prop="location" label="位置" width="120" />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status === '在线' ? 'success' : 'danger'">
              {{ row.status }}
            </el-tag>
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
            <el-tag size="small" :type="row.usbConnected ? 'success' : 'info'">
              {{ row.usbConnected ? '已连接' : '未连接' }}
            </el-tag>
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
import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Connection } from '@element-plus/icons-vue'

const devices = ref([
  { id: 'DEV-001', name: '正门检测端', location: '正门大厅', status: '在线', firmware: 'v3.2.1', heartbeat: 5, usbConnected: true, policyVersion: 'POL-2.4', uptime: '15天' },
  { id: 'DEV-002', name: '走廊检测端', location: '3F走廊', status: '在线', firmware: 'v3.2.1', heartbeat: 8, usbConnected: true, policyVersion: 'POL-2.4', uptime: '15天' },
  { id: 'DEV-003', name: '机房检测端', location: 'B1机房', status: '在线', firmware: 'v3.2.0', heartbeat: 6, usbConnected: false, policyVersion: 'POL-2.3', uptime: '12天' },
  { id: 'DEV-004', name: '车库检测端', location: '地下车库', status: '在线', firmware: 'v3.2.1', heartbeat: 4, usbConnected: true, policyVersion: 'POL-2.4', uptime: '15天' },
  { id: 'DEV-005', name: '会议室检测端', location: '2F会议室', status: '离线', firmware: 'v3.1.9', heartbeat: 0, usbConnected: false, policyVersion: 'POL-2.2', uptime: '-' },
  { id: 'DEV-006', name: '仓库检测端', location: '1F仓库', status: '在线', firmware: 'v3.2.1', heartbeat: 9, usbConnected: true, policyVersion: 'POL-2.4', uptime: '15天' },
])

function restart(row: typeof devices.value[0]) {
  ElMessage.success(`检测端 ${row.name} 重启指令已发送 (WS63)`)
}
function updatePolicy(row: typeof devices.value[0]) {
  ElMessage.success(`策略已更新至 ${row.policyVersion}`)
}
</script>

<style scoped>
.device-manage { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }

.ws-status { margin-bottom: 0; }
.ws-status__inner { display: flex; align-items: center; gap: 16px; }
.ws-status__info h3 { margin: 0 0 4px 0; font-size: 16px; }
.ws-status__info span { font-size: 13px; color: #909399; }
.ws-status__icon { display: flex; align-items: center; }
</style>
