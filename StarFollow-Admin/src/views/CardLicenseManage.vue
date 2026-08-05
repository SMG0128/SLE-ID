<template>
  <div class="card-manage">
    <!-- 概览 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="卡片总数" :value="list.length" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="正常" :value="normalCount" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="冻结/挂失" :value="frozenLostCount" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="已撤销" :value="revokedCount" /></el-card></el-col>
    </el-row>

    <!-- 筛选 -->
    <el-card shadow="hover">
      <el-form :inline="true">
        <el-form-item label="状态">
          <el-select v-model="statusFilter" placeholder="全部" clearable style="width:140px">
            <el-option label="正常" value="正常" />
            <el-option label="已冻结" value="已冻结" />
            <el-option label="已挂失" value="已挂失" />
            <el-option label="已撤销" value="已撤销" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="applyFilter">筛选</el-button>
          <el-button @click="statusFilter = ''; applyFilter()">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 卡片列表 -->
    <el-card shadow="hover" v-loading="loading">
      <el-table :data="filtered" stripe border>
        <el-table-column prop="cardId" label="卡片标识" width="120" />
        <el-table-column prop="owner" label="持有人" width="100" />
        <el-table-column prop="licenseName" label="绑定许可" width="150" />
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag size="small" :type="statusTag(row.status)">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="keyVersion" label="密钥版本" width="90" />
        <el-table-column prop="lastSync" label="最后同步" width="170" />
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.status === '正常'" size="small" type="warning" @click="act(row, 'freeze')">冻结</el-button>
            <el-button v-if="row.status === '正常'" size="small" type="danger" @click="act(row, 'report_lost')">挂失</el-button>
            <el-button v-if="row.status === '已冻结' || row.status === '已挂失'" size="small" type="success" @click="act(row, 'restore')">恢复</el-button>
            <el-button v-if="row.status !== '已撤销'" size="small" type="danger" @click="act(row, 'revoke')">撤销</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getCardList, performCardAction } from '@/api/card'
import type { Card, CardStatus, CardAction } from '@/types/card'

const list = ref<Card[]>([])
const loading = ref(true)
const statusFilter = ref('')

const filtered = computed(() => (statusFilter.value ? list.value.filter(c => c.status === statusFilter.value) : list.value))
const normalCount = computed(() => list.value.filter(c => c.status === '正常').length)
const frozenLostCount = computed(() => list.value.filter(c => c.status === '已冻结' || c.status === '已挂失').length)
const revokedCount = computed(() => list.value.filter(c => c.status === '已撤销').length)

async function loadData() {
  loading.value = true
  const res = await getCardList()
  list.value = res.list
  loading.value = false
}

function statusTag(s: CardStatus) {
  const m: Record<string, string> = { 正常: 'success', 已冻结: 'warning', 已挂失: 'danger', 已撤销: 'info' }
  return m[s] || ''
}

async function act(row: Card, action: CardAction) {
  const labels: Record<CardAction, string> = { freeze: '冻结', report_lost: '挂失', restore: '恢复', revoke: '撤销' }
  const warning = action === 'revoke' || action === 'report_lost'
  try {
    await ElMessageBox.confirm(
      `确定对卡片 ${row.cardId}（${row.owner}）执行「${labels[action]}」操作？`,
      labels[action] + '卡片',
      { type: warning ? 'error' : 'warning' },
    )
    const updated = await performCardAction(row.cardId, action)
    if (updated) Object.assign(row, updated)
    ElMessage.success(`已${labels[action]}`)
  } catch { /* 取消 */ }
}

function applyFilter() { /* 响应式已生效 */ }

onMounted(loadData)
</script>

<style scoped>
.card-manage { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.stats-row { margin: 0 !important; }
</style>
