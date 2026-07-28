<template>
  <div class="event-log">
    <!-- 筛选 -->
    <el-card shadow="hover">
      <el-form :inline="true" :model="filter">
        <el-form-item label="时间范围">
          <el-date-picker v-model="filter.dateRange" type="daterange" range-separator="至" start-placeholder="开始日期" end-placeholder="结束日期" format="YYYY-MM-DD" value-format="YYYY-MM-DD" style="width:260px" />
        </el-form-item>
        <el-form-item label="检测端">
          <el-select v-model="filter.device" placeholder="全部" clearable style="width:160px">
            <el-option v-for="d in deviceOptions" :key="d" :label="d" :value="d" />
          </el-select>
        </el-form-item>
        <el-form-item label="结果">
          <el-select v-model="filter.result" placeholder="全部" clearable style="width:120px">
            <el-option label="成功" value="成功" />
            <el-option label="失败" value="失败" />
            <el-option label="待定" value="待定" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="search">查询</el-button>
          <el-button @click="reset">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 表格 -->
    <el-card shadow="hover" v-loading="loading">
      <el-table :data="tableData" stripe border>
        <el-table-column prop="eventId" label="事件ID" width="110" />
        <el-table-column prop="time" label="时间" width="180" />
        <el-table-column prop="device" label="检测端" width="140" />
        <el-table-column prop="cardId" label="匿名卡ID" width="150" />
        <el-table-column label="结果" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.result === '成功' ? 'success' : row.result === '失败' ? 'danger' : 'info'">{{ row.result }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="终止状态" width="160" />
      </el-table>
      <div class="pagination">
        <el-pagination v-model:current-page="page" :page-size="pageSize" :total="total" layout="total, prev, pager, next" background @current-change="loadData" />
      </div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { getEventList } from '@/api/event'
import type { EventLogItem, EventQuery } from '@/types/event'

const deviceOptions = ['正门检测端', '走廊检测端', '机房检测端', '车库检测端', '会议室检测端', '仓库检测端']

const filter = reactive({
  dateRange: null as [string, string] | null,
  device: '',
  result: '',
})
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)
const tableData = ref<EventLogItem[]>([])
const loading = ref(false)

async function loadData() {
  loading.value = true
  const query: EventQuery = {
    page: page.value,
    pageSize: pageSize.value,
    device: filter.device || undefined,
    result: filter.result || undefined,
    dateStart: filter.dateRange?.[0],
    dateEnd: filter.dateRange?.[1],
  }
  const res = await getEventList(query)
  tableData.value = res.list
  total.value = res.total
  loading.value = false
}

function search() { page.value = 1; loadData() }
function reset() { filter.dateRange = null; filter.device = ''; filter.result = ''; page.value = 1; loadData() }

onMounted(loadData)
</script>

<style scoped>
.event-log { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.pagination { display: flex; justify-content: flex-end; margin-top: 16px; }
</style>
