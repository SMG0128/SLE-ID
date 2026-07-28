<template>
  <div class="alarm-center">
    <!-- 统计 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="严重" :value="stats.severe" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="高" :value="stats.high" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="普通" :value="stats.normal" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="未处理" :value="stats.unhandled" /></el-card></el-col>
    </el-row>

    <!-- 筛选 -->
    <el-card shadow="hover">
      <el-form :inline="true" :model="filter">
        <el-form-item label="等级">
          <el-select v-model="filter.level" placeholder="全部" clearable style="width:120px">
            <el-option v-for="l in ALARM_LEVELS" :key="l.value" :label="l.label" :value="l.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="filter.type" placeholder="全部" clearable style="width:160px">
            <el-option v-for="t in ALARM_TYPES" :key="t.value" :label="t.label" :value="t.value" />
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
    <el-card shadow="hover" v-loading="loading">
      <el-table :data="tableData" stripe border>
        <el-table-column label="等级" width="80">
          <template #default="{ row }"><el-tag size="small" :type="levelTag(row.level)" effect="dark">{{ levelLabel(row.level) }}</el-tag></template>
        </el-table-column>
        <el-table-column label="报警类型" width="140">
          <template #default="{ row }"><el-tag size="small" effect="plain" :type="typeTagColor(row.type)">{{ typeLabel(row.type) }}</el-tag></template>
        </el-table-column>
        <el-table-column prop="device" label="检测端" width="140" />
        <el-table-column prop="cardId" label="卡片ID" width="120" />
        <el-table-column prop="message" label="报警信息" min-width="200" show-overflow-tooltip />
        <el-table-column prop="operator" label="操作人" width="100" />
        <el-table-column prop="time" label="时间" width="180" />
        <el-table-column label="状态" width="90">
          <template #default="{ row }"><el-tag size="small" :type="row.handled ? 'success' : 'danger'">{{ row.handled ? '已处理' : '未处理' }}</el-tag></template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="showDetail(row)">详情</el-button>
            <el-button v-if="!row.handled" size="small" type="primary" @click="markHandled(row)">标记处理</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div class="pagination">
        <el-pagination v-model:current-page="page" :page-size="pageSize" :total="total" layout="total, prev, pager, next" background @current-change="loadData" />
      </div>
    </el-card>

    <!-- 详情弹窗 -->
    <el-dialog v-model="dialogVisible" title="报警详情" width="520px">
      <template v-if="currentAlarm">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="报警ID">{{ currentAlarm.id }}</el-descriptions-item>
          <el-descriptions-item label="等级"><el-tag size="small" :type="levelTag(currentAlarm.level)">{{ levelLabel(currentAlarm.level) }}</el-tag></el-descriptions-item>
          <el-descriptions-item label="类型">{{ typeLabel(currentAlarm.type) }}</el-descriptions-item>
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
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getAlarmList, handleAlarm } from '@/api/alarm'
import { ALARM_TYPES, ALARM_LEVELS, type AlarmRecord, type AlarmQuery, type AlarmStats, type AlarmLevel, type AlarmType } from '@/types/alarm'

const filter = reactive<AlarmQuery>({ page: 1, pageSize: 10, level: '', type: '', handleStatus: '' })
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)
const tableData = ref<AlarmRecord[]>([])
const stats = ref<AlarmStats>({ severe: 0, high: 0, normal: 0, total: 0, unhandled: 0 })
const loading = ref(false)

async function loadData() {
  loading.value = true
  const query: AlarmQuery = { ...filter, page: page.value, pageSize: pageSize.value }
  const res = await getAlarmList(query)
  tableData.value = res.list
  total.value = res.total
  stats.value = res.stats
  loading.value = false
}

async function markHandled(row: AlarmRecord) {
  await handleAlarm(row.id)
  row.handled = true
  stats.value.unhandled--
  ElMessage.success('已标记处理')
}

const dialogVisible = ref(false)
const currentAlarm = ref<AlarmRecord | null>(null)
function showDetail(row: AlarmRecord) { currentAlarm.value = row; dialogVisible.value = true }

function levelLabel(l: AlarmLevel) { return ALARM_LEVELS.find(x => x.value === l)?.label || l }
function levelTag(l: AlarmLevel) { return l === 'severe' ? 'danger' : l === 'high' ? 'warning' : '' }
function typeLabel(t: AlarmType) { return ALARM_TYPES.find(x => x.value === t)?.label || t }
function typeTagColor(t: AlarmType) {
  const m: Record<string, string> = { unknown_device: 'warning', unauthorized: 'danger', license_expired: 'warning', key_failed: 'danger', confirm_failed: 'info', execute_failed: 'danger', suspected_replay: 'danger' }
  return m[t] || 'info'
}

function search() { page.value = 1; loadData() }
function reset() { filter.level = ''; filter.type = ''; filter.handleStatus = ''; page.value = 1; loadData() }

onMounted(loadData)
</script>

<style scoped>
.alarm-center { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.stats-row { margin: 0 !important; }
.pagination { display: flex; justify-content: flex-end; margin-top: 16px; }
</style>
