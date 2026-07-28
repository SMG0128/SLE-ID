<template>
  <div class="permission-manage">
    <!-- 许可概览 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="许可总数" :value="licenses.length" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="有效许可" :value="activeCount" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="即将过期" :value="expiringCount" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="已过期" :value="expiredCount" /></el-card></el-col>
    </el-row>

    <!-- 操作栏 -->
    <el-card shadow="hover">
      <div class="toolbar">
        <span class="toolbar-title">许可管理 — 星闪策略引擎</span>
        <el-button type="primary" @click="openCreate">+ 创建许可</el-button>
      </div>
    </el-card>

    <!-- 许可列表 -->
    <el-card shadow="hover" v-loading="loading">
      <el-table :data="licenses" stripe border>
        <el-table-column prop="name" label="许可名称" width="160" />
        <el-table-column prop="zone" label="区域" width="120" />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status === '有效' ? 'success' : row.status === '即将过期' ? 'warning' : 'danger'">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="cardCount" label="绑定卡片" width="90" />
        <el-table-column label="策略" min-width="280">
          <template #default="{ row }">
            <el-tag v-for="p in row.policies" :key="p.key" size="small" effect="plain" :type="p.enabled ? 'success' : 'info'" class="policy-tag">
              {{ p.label }}
            </el-tag>
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
        <el-form-item label="许可名称"><el-input v-model="form.name" placeholder="如: 正门区域许可" /></el-form-item>
        <el-form-item label="区域">
          <el-select v-model="form.zone" placeholder="选择区域" style="width:100%">
            <el-option v-for="z in ZONE_OPTIONS" :key="z" :label="z" :value="z" />
          </el-select>
        </el-form-item>
        <el-form-item label="有效时间">
          <el-date-picker v-model="form.dateRange" type="daterange" range-separator="至" start-placeholder="开始日期" end-placeholder="结束日期" format="YYYY-MM-DD" value-format="YYYY-MM-DD" style="width:100%" />
        </el-form-item>
        <el-divider content-position="left">策略配置</el-divider>
        <el-form-item v-for="p in POLICY_OPTIONS" :key="p.key" :label="p.label">
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
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getLicenses, createLicense, revokeLicense } from '@/api/permission'
import { POLICY_OPTIONS, ZONE_OPTIONS, type License, type CreateLicenseForm } from '@/types/license'

const licenses = ref<License[]>([])
const loading = ref(true)

const activeCount = computed(() => licenses.value.filter(l => l.status === '有效').length)
const expiringCount = computed(() => licenses.value.filter(l => l.status === '即将过期').length)
const expiredCount = computed(() => licenses.value.filter(l => l.status === '已过期').length)

async function loadData() {
  loading.value = true
  licenses.value = await getLicenses()
  loading.value = false
}

// ---- 弹窗 ----
const dialogVisible = ref(false)
const editingId = ref('')
const form = reactive<CreateLicenseForm>({ name: '', zone: '', dateRange: null, policies: {} })

function openCreate() {
  editingId.value = ''
  form.name = ''
  form.zone = ''
  form.dateRange = null
  form.policies = Object.fromEntries(POLICY_OPTIONS.map(p => [p.key, false]))
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

async function save() {
  if (!form.name || !form.zone || !form.dateRange) {
    ElMessage.warning('请填写完整信息')
    return
  }
  if (editingId.value) {
    const target = licenses.value.find(l => l.id === editingId.value)
    if (target) {
      target.name = form.name
      target.zone = form.zone
      target.policies = POLICY_OPTIONS.map(p => ({ ...p, enabled: !!form.policies[p.key] }))
    }
    ElMessage.success('许可已更新')
  } else {
    const newLicense = await createLicense(form, '当前用户')
    licenses.value.unshift(newLicense)
    ElMessage.success('许可已创建')
  }
  dialogVisible.value = false
}

async function revoke(row: License) {
  try {
    await ElMessageBox.confirm(`确定吊销许可 "${row.name}"? 已绑定的 ${row.cardCount} 张卡片将立即失效。`, '吊销许可', { type: 'error' })
    await revokeLicense(row.id)
    licenses.value = licenses.value.filter(l => l.id !== row.id)
    ElMessage.success('许可已吊销')
  } catch { /* 取消 */ }
}

onMounted(loadData)
</script>

<style scoped>
.permission-manage { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.stats-row { margin: 0 !important; }
.toolbar { display: flex; align-items: center; justify-content: space-between; }
.toolbar-title { font-size: 16px; font-weight: 600; }
.policy-tag { margin-right: 4px; margin-bottom: 4px; }
.policy-desc { margin-left: 8px; color: #909399; font-size: 12px; }
</style>
