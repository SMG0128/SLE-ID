<template>
  <div class="alarm-center">
    <!-- 统计 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-severe">
          <el-statistic title="严重" :value="stats.severe">
            <template #suffix><el-tag type="danger" size="small">需立即处理</el-tag></template>
          </el-statistic>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-high">
          <el-statistic title="高" :value="stats.high" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-normal">
          <el-statistic title="普通" :value="stats.normal" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-total">
          <el-statistic title="未处理" :value="stats.unhandled">
            <template #suffix>
              <span style="font-size:14px;color:#909399">/ {{ stats.total }}</span>
            </template>
          </el-statistic>
        </el-card>
      </el-col>
    </el-row>

    <!-- 筛选 -->
    <el-card shadow="hover">
      <el-form :inline="true" :model="filter">
        <el-form-item label="等级">
          <el-select v-model="filter.level" placeholder="全部" clearable style="width:120px">
            <el-option v-for="l in levels" :key="l.value" :label="l.label" :value="l.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="filter.type" placeholder="全部" clearable style="width:160px">
            <el-option v-for="t in alarmTypes" :key="t.value" :label="t.label" :value="t.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="filter.handleStatus" placeholder="全部" clearable style="width:120px">
            <el-option label="未处理" value="unhandled" />
            <el-option label="已处理" value="handled" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="search">筛选</el-button>
          <el-button @click="reset">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 报警列表 -->
    <el-card shadow="hover">
      <el-table :data="pagedData" stripe border highlight-current-row>
        <el-table-column label="等级" width="80">
          <template #default="{ row }">
            <el-tag size="small" :type="levelTag(row.level)" effect="dark">
              {{ levelLabel(row.level) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="报警类型" width="140">
          <template #default="{ row }">
            <el-tag size="small" effect="plain" :type="typeTagColor(row.type)">
              {{ typeLabel(row.type) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="device" label="检测端" width="140" />
        <el-table-column prop="cardId" label="卡片ID" width="120" />
        <el-table-column prop="message" label="报警信息" min-width="200" show-overflow-tooltip />
        <el-table-column prop="operator" label="操作人" width="100" />
        <el-table-column prop="time" label="时间" width="180" />
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag size="small" :type="row.handled ? 'success' : 'danger'">
              {{ row.handled ? '已处理' : '未处理' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="showDetail(row)">详情</el-button>
            <el-button v-if="!row.handled" size="small" type="primary" @click="handleAlarm(row)">标记处理</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div class="pagination">
        <el-pagination
          v-model:current-page="page"
          :page-size="pageSize"
          :total="filteredData.length"
          layout="total, prev, pager, next"
          background
        />
      </div>
    </el-card>

    <!-- 详情弹窗 -->
    <el-dialog v-model="dialogVisible" title="报警详情" width="520px">
      <template v-if="currentAlarm">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="报警ID">{{ currentAlarm.id }}</el-descriptions-item>
          <el-descriptions-item label="等级">
            <el-tag size="small" :type="levelTag(currentAlarm.level!)">{{ levelLabel(currentAlarm.level!) }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="类型">{{ typeLabel(currentAlarm.type!) }}</el-descriptions-item>
          <el-descriptions-item label="检测端">{{ currentAlarm.device }}</el-descriptions-item>
          <el-descriptions-item label="卡片ID">{{ currentAlarm.cardId }}</el-descriptions-item>
          <el-descriptions-item label="操作人">{{ currentAlarm.operator }}</el-descriptions-item>
          <el-descriptions-item label="时间" :span="2">{{ currentAlarm.time }}</el-descriptions-item>
          <el-descriptions-item label="信息" :span="2">{{ currentAlarm.message }}</el-descriptions-item>
          <el-descriptions-item label="处理方案" :span="2">{{ currentAlarm.solution }}</el-descriptions-item>
        </el-descriptions>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { ElMessage } from 'element-plus'

// ---- 报警类型定义 ----
const alarmTypes = [
  { label: '未知设备', value: 'unknown_device' },
  { label: '未授权', value: 'unauthorized' },
  { label: '许可过期', value: 'license_expired' },
  { label: '密钥失败', value: 'key_failed' },
  { label: '确认失败', value: 'confirm_failed' },
  { label: '执行失败', value: 'execute_failed' },
  { label: '疑似重放', value: 'suspected_replay' },
]

const levels = [
  { label: '严重', value: 'severe' },
  { label: '高', value: 'high' },
  { label: '普通', value: 'normal' },
]

type Level = 'severe' | 'high' | 'normal'
type AlarmType = typeof alarmTypes[number]['value']

interface Alarm {
  id: string
  level: Level
  type: AlarmType
  device: string
  cardId: string
  message: string
  operator: string
  time: string
  handled: boolean
  solution: string
}

// ---- mock 数据 ----
const solutionPool: Record<string, string> = {
  unknown_device: '确认设备身份，更新白名单后重新接入',
  unauthorized: '检查卡片权限配置，联系管理员授权',
  license_expired: '更新许可有效期，或重新签发许可',
  key_failed: '重新协商密钥对，检查 WS63 加密模块状态',
  confirm_failed: '二次确认超时，建议重试或人工介入',
  execute_failed: '检查检测端固件版本，进行远程重启后重试',
  suspected_replay: '标记为可疑事件，建议临时冻结相关卡片',
}

const devicePool = ['正门检测端', '走廊检测端', '机房检测端', '车库检测端', '会议室检测端', '仓库检测端']
const operatorPool = ['系统自动', '系统自动', '系统自动', '张三', '李四']

function genMock(): Alarm[] {
  const list: Alarm[] = []
  let id = 1
  for (const at of alarmTypes) {
    const tv = at.value
    for (let i = 0; i < 2; i++) {
      const level: Level = tv === 'suspected_replay' || tv === 'key_failed' ? 'severe'
        : tv === 'unauthorized' || tv === 'execute_failed' ? 'high' : 'normal'
      const now = new Date()
      now.setMinutes(now.getMinutes() - (id * 23 + i * 7))
      list.push({
        id: `ALM-${String(id++).padStart(6, '0')}`,
        level,
        type: tv as AlarmType,
        device: devicePool[Math.floor(Math.random() * devicePool.length)],
        cardId: `ANON-${String(Math.floor(Math.random() * 9000) + 1000)}`,
        message: `${at.label}报警触发`,
        operator: operatorPool[Math.floor(Math.random() * operatorPool.length)],
        time: now.toLocaleString('zh-CN'),
        handled: i === 0,
        solution: solutionPool[tv] || '待人工分析',
      })
    }
  }
  return list
}
const allData = genMock()

// ---- 筛选 ----
const filter = reactive({
  level: '' as Level | '',
  type: '' as AlarmType | '',
  handleStatus: '' as 'unhandled' | 'handled' | '',
})
const page = ref(1)
const pageSize = ref(10)

const filteredData = computed(() => {
  return allData.filter(item => {
    if (filter.level && item.level !== filter.level) return false
    if (filter.type && item.type !== filter.type) return false
    if (filter.handleStatus === 'unhandled' && item.handled) return false
    if (filter.handleStatus === 'handled' && !item.handled) return false
    return true
  })
})

const pagedData = computed(() => {
  const s = (page.value - 1) * pageSize.value
  return filteredData.value.slice(s, s + pageSize.value)
})

const stats = computed(() => ({
  severe: allData.filter(a => a.level === 'severe').length,
  high: allData.filter(a => a.level === 'high').length,
  normal: allData.filter(a => a.level === 'normal').length,
  total: allData.length,
  unhandled: allData.filter(a => !a.handled).length,
}))

// ---- 弹窗 ----
const dialogVisible = ref(false)
const currentAlarm = ref<Alarm | null>(null)
function showDetail(row: Alarm) { currentAlarm.value = row; dialogVisible.value = true }
function handleAlarm(row: Alarm) { row.handled = true; ElMessage.success('已标记处理') }

// ---- 辅助 ----
function levelLabel(l: Level) { return levels.find(x => x.value === l)?.label || l }
function levelTag(l: Level) { return l === 'severe' ? 'danger' : l === 'high' ? 'warning' : '' }
function typeLabel(t: AlarmType) { return alarmTypes.find(x => x.value === t)?.label || t }
function typeTagColor(t: AlarmType) {
  const colors: Record<string, string> = {
    unknown_device: 'warning', unauthorized: 'danger', license_expired: 'warning',
    key_failed: 'danger', confirm_failed: 'info', execute_failed: 'danger', suspected_replay: 'danger',
  }
  return colors[t] || 'info'
}

function search() { page.value = 1 }
function reset() { filter.level = ''; filter.type = ''; filter.handleStatus = ''; page.value = 1 }
</script>

<style scoped>
.alarm-center { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.stats-row { margin: 0 !important; }
.stat-card :deep(.el-statistic__head) { font-size: 13px; }
.stat-severe :deep(.el-statistic__number) { color: #f56c6c; }
.stat-high :deep(.el-statistic__number) { color: #e6a23c; }
.pagination { display: flex; justify-content: flex-end; margin-top: 16px; }
</style>
