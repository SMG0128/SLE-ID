<template>
  <div class="permission-manage">
    <!-- 许可概览 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6">
        <el-card shadow="hover"><el-statistic title="许可总数" :value="licenses.length" /></el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="有效许可" :value="activeCount">
            <template #suffix><el-tag type="success" size="small">活跃</el-tag></template>
          </el-statistic>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="即将过期" :value="expiringCount">
            <template #suffix><el-tag type="warning" size="small">7天内</el-tag></template>
          </el-statistic>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="已过期" :value="expiredCount">
            <template #suffix><el-tag type="danger" size="small">需处理</el-tag></template>
          </el-statistic>
        </el-card>
      </el-col>
    </el-row>

    <!-- 操作栏 -->
    <el-card shadow="hover">
      <div class="toolbar">
        <span class="toolbar-title">许可管理 — 星闪策略引擎</span>
        <el-button type="primary" @click="openCreate">+ 创建许可</el-button>
      </div>
    </el-card>

    <!-- 许可列表 -->
    <el-card shadow="hover">
      <el-table :data="licenses" stripe border>
        <el-table-column prop="name" label="许可名称" width="160" />
        <el-table-column prop="zone" label="区域" width="120" />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status === '有效' ? 'success' : row.status === '即将过期' ? 'warning' : 'danger'">
              {{ row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="cardCount" label="绑定卡片" width="90" />
        <el-table-column label="策略" min-width="280">
          <template #default="{ row }">
            <el-tooltip v-for="p in row.policies" :key="p.key" :content="p.desc" placement="top">
              <el-tag size="small" effect="plain" :type="p.enabled ? 'success' : 'info'" class="policy-tag">
                {{ p.label }}
              </el-tag>
            </el-tooltip>
          </template>
        </el-table-column>
        <el-table-column prop="creator" label="创建人" width="100" />
        <el-table-column prop="createTime" label="创建时间" width="120" />
        <el-table-column prop="expireTime" label="有效期至" width="120" />
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="edit(row)">编辑</el-button>
            <el-button size="small" type="danger" @click="revoke(row)">吊销</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 创建/编辑许可弹窗 -->
    <el-dialog v-model="dialogVisible" :title="editingId ? '编辑许可' : '创建许可'" width="520px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="许可名称">
          <el-input v-model="form.name" placeholder="如: 正门区域许可" />
        </el-form-item>
        <el-form-item label="区域">
          <el-select v-model="form.zone" placeholder="选择区域" style="width:100%">
            <el-option label="正门大厅" value="正门大厅" />
            <el-option label="3F走廊" value="3F走廊" />
            <el-option label="B1机房" value="B1机房" />
            <el-option label="地下车库" value="地下车库" />
            <el-option label="2F会议室" value="2F会议室" />
            <el-option label="1F仓库" value="1F仓库" />
            <el-option label="全区域" value="全区域" />
          </el-select>
        </el-form-item>
        <el-form-item label="有效时间">
          <el-date-picker
            v-model="form.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            format="YYYY-MM-DD"
            value-format="YYYY-MM-DD"
            style="width:100%"
          />
        </el-form-item>

        <el-divider content-position="left">策略配置</el-divider>

        <el-form-item v-for="p in policyOptions" :key="p.key" :label="p.label">
          <el-switch v-model="form.policies[p.key]" />
          <span class="policy-desc">{{ p.desc }}</span>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="save">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'

interface License {
  id: string
  name: string
  zone: string
  status: string
  cardCount: number
  policies: { key: string; label: string; desc: string; enabled: boolean }[]
  creator: string
  createTime: string
  expireTime: string
}

const policyOptions = [
  { key: 'record_event', label: '记录事件', desc: '记录所有认证与检测事件日志' },
  { key: 'allow_execute', label: '允许执行', desc: '允许卡片执行开门/区域进入等操作' },
  { key: 'double_confirm', label: '二次确认', desc: '需要操作人员现场二次确认后放行' },
  { key: 'abnormal_alarm', label: '异常报警', desc: '检测到异常时立即触发报警通知' },
]

const licenses = ref<License[]>([
  {
    id: 'LC-001', name: '正门区域许可', zone: '正门大厅', status: '有效', cardCount: 12,
    policies: policyOptions.map(p => ({ ...p, enabled: true })),
    creator: '张三', createTime: '2026-07-20', expireTime: '2026-12-31',
  },
  {
    id: 'LC-002', name: '机房专属许可', zone: 'B1机房', status: '有效', cardCount: 3,
    policies: policyOptions.map(p => ({ ...p, enabled: p.key !== 'double_confirm' })),
    creator: '张三', createTime: '2026-07-15', expireTime: '2026-09-30',
  },
  {
    id: 'LC-003', name: '走廊通行许可', zone: '3F走廊', status: '即将过期', cardCount: 8,
    policies: policyOptions.map(p => ({ ...p, enabled: p.key === 'record_event' || p.key === 'allow_execute' })),
    creator: '李四', createTime: '2026-06-01', expireTime: '2026-08-02',
  },
  {
    id: 'LC-004', name: '车库车辆许可', zone: '地下车库', status: '已过期', cardCount: 5,
    policies: policyOptions.map(p => ({ ...p, enabled: p.key !== 'abnormal_alarm' })),
    creator: '张三', createTime: '2026-01-10', expireTime: '2026-06-30',
  },
])

// ---- 统计 ----
const activeCount = computed(() => licenses.value.filter(l => l.status === '有效').length)
const expiringCount = computed(() => licenses.value.filter(l => l.status === '即将过期').length)
const expiredCount = computed(() => licenses.value.filter(l => l.status === '已过期').length)

// ---- 弹窗 ----
const dialogVisible = ref(false)
const editingId = ref('')
const form = reactive({
  name: '',
  zone: '',
  dateRange: null as [string, string] | null,
  policies: {} as Record<string, boolean>,
})

function openCreate() {
  editingId.value = ''
  form.name = ''
  form.zone = ''
  form.dateRange = null
  form.policies = Object.fromEntries(policyOptions.map(p => [p.key, false]))
  dialogVisible.value = true
}

function edit(row: License) {
  editingId.value = row.id
  form.name = row.name
  form.zone = row.zone
  form.dateRange = null
  form.policies = Object.fromEntries(row.policies.map(p => [p.key, p.enabled]))
  dialogVisible.value = true
}

function save() {
  if (!form.name || !form.zone || !form.dateRange) {
    ElMessage.warning('请填写完整信息')
    return
  }
  const policyList = policyOptions.map(p => ({
    ...p, enabled: !!form.policies[p.key],
  }))
  const now = new Date().toISOString().slice(0, 10)
  const [_, expire] = form.dateRange
  const status = expire < now ? '已过期'
    : new Date(expire).getTime() - Date.now() < 7 * 86400000 ? '即将过期' : '有效'

  if (editingId.value) {
    const target = licenses.value.find(l => l.id === editingId.value)
    if (target) {
      target.name = form.name; target.zone = form.zone
      target.policies = policyList; target.expireTime = expire
      target.status = status
    }
    ElMessage.success('许可已更新')
  } else {
    licenses.value.unshift({
      id: `LC-${String(licenses.value.length + 1).padStart(3, '0')}`,
      name: form.name, zone: form.zone, status,
      cardCount: 0, policies: policyList, creator: '当前用户',
      createTime: now, expireTime: expire,
    })
    ElMessage.success('许可已创建')
  }
  dialogVisible.value = false
}

function revoke(row: License) {
  ElMessageBox.confirm(`确定吊销许可 "${row.name}"? 已绑定的 ${row.cardCount} 张卡片将立即失效。`, '吊销许可', { type: 'error' })
    .then(() => {
      licenses.value = licenses.value.filter(l => l.id !== row.id)
      ElMessage.success('许可已吊销')
    }).catch(() => {})
}
</script>

<style scoped>
.permission-manage { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.stats-row { margin: 0 !important; }
.toolbar { display: flex; align-items: center; justify-content: space-between; }
.toolbar-title { font-size: 16px; font-weight: 600; }
.policy-tag { margin-right: 4px; margin-bottom: 4px; }
.policy-desc { margin-left: 8px; color: #909399; font-size: 12px; }
</style>
