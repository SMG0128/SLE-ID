<template>
  <div class="event-log">
    <!-- 筛选 -->
    <el-card shadow="hover">
      <el-form :inline="true" :model="filter" class="filter-form">
        <el-form-item label="时间范围">
          <el-date-picker
            v-model="filter.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            format="YYYY-MM-DD"
            value-format="YYYY-MM-DD"
            style="width:260px"
          />
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
    <el-card shadow="hover">
      <el-table :data="pagedData" stripe border>
        <el-table-column prop="eventId" label="事件ID" width="110" />
        <el-table-column prop="time" label="时间" width="180" />
        <el-table-column prop="device" label="检测端" width="140" />
        <el-table-column prop="cardId" label="匿名卡ID" width="150" />
        <el-table-column label="结果" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.result === '成功' ? 'success' : row.result === '失败' ? 'danger' : 'info'">
              {{ row.result }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="终止状态" width="160">
          <template #default="{ row }">
            <span :style="{ color: statusColor[row.status] }">{{ row.status }}</span>
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
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'

// ---- 配置 ----
const deviceOptions = ['正门检测端', '走廊检测端', '机房检测端', '车库检测端', '会议室检测端', '仓库检测端']
const statusColor: Record<string, string> = {
  '待命中': '#909399', '接近中': '#409eff', '区域内': '#e6a23c',
  '已完成': '#67c23a', '冷却中': '#909399', '已拒绝': '#f56c6c',
}

// ---- mock 数据 ----
function genMock(count: number) {
  const pools = {
    device: deviceOptions,
    cardId: Array.from({ length: 20 }, (_, i) => `ANON-${String(i + 1).padStart(4, '0')}`),
    result: ['成功', '成功', '成功', '成功', '失败', '待定'] as const,
    status: ['待命中', '接近中', '区域内', '已完成', '冷却中', '已拒绝'] as const,
  }
  const list: Record<string, unknown>[] = []
  let id = 1000
  for (let d = count; d >= 0; d--) {
    const date = new Date(2026, 6, 27, 0, 0, 0)
    date.setMinutes(date.getMinutes() - d * 12 + Math.floor(Math.random() * 5))
    list.push({
      eventId: `EV-${String(id++).padStart(6, '0')}`,
      time: date.toLocaleString('zh-CN'),
      dateStr: date.toISOString().slice(0, 10), // YYYY-MM-DD 用于筛选比较
      device: pools.device[Math.floor(Math.random() * pools.device.length)],
      cardId: pools.cardId[Math.floor(Math.random() * pools.cardId.length)],
      result: pools.result[Math.floor(Math.random() * pools.result.length)],
      status: pools.status[Math.floor(Math.random() * pools.status.length)],
    })
  }
  return list
}
const allData = genMock(80)

// ---- 筛选 ----
const filter = reactive({
  dateRange: null as [string, string] | null,
  device: '',
  result: '',
})
const page = ref(1)
const pageSize = ref(10)

const filteredData = computed(() => {
  return allData.filter(item => {
    if (filter.device && item.device !== filter.device) return false
    if (filter.result && item.result !== filter.result) return false
    if (filter.dateRange) {
      const [start, end] = filter.dateRange
      const d = item.dateStr as string
      if (d < start || d > end) return false
    }
    return true
  })
})

const pagedData = computed(() => {
  const start = (page.value - 1) * pageSize.value
  return filteredData.value.slice(start, start + pageSize.value)
})

function search() { page.value = 1 }
function reset() {
  filter.dateRange = null
  filter.device = ''
  filter.result = ''
  page.value = 1
}
</script>

<style scoped>
.event-log { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.filter-form { margin-bottom: 0; }
.pagination { display: flex; justify-content: flex-end; margin-top: 16px; }
</style>
