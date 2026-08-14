<template>
  <div class="invite-manage">
    <!-- 概览 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="邀请码总数" :value="list.length" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="未使用" :value="unusedCount" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="已绑定" :value="boundCount" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="已失效" :value="invalidCount" /></el-card></el-col>
    </el-row>

    <!-- 操作栏 -->
    <el-card shadow="hover">
      <div class="toolbar">
        <span class="toolbar-title">邀请码管理 — 一次性 / 可过期 / 可撤销 / 可追踪</span>
        <el-button type="primary" @click="dialogVisible = true">生成邀请码</el-button>
      </div>
    </el-card>

    <!-- 邀请码列表 -->
    <el-card shadow="hover" v-loading="loading">
      <el-table :data="list" stripe border>
        <el-table-column prop="code" label="邀请码" width="190" />
        <el-table-column prop="role" label="角色" width="90" />
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag size="small" :type="statusTag(row.status)">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="一次性" width="80">
          <template #default="{ row }">
            <el-tag v-if="row.oneTime" size="small" type="warning" effect="plain">一次性</el-tag>
            <span v-else class="muted">可多次</span>
          </template>
        </el-table-column>
        <el-table-column label="剩余有效时间" width="120">
          <template #default="{ row }">{{ remainTime(row) }}</template>
        </el-table-column>
        <el-table-column label="使用次数" width="100">
          <template #default="{ row }">{{ row.usedCount ?? 0 }} / {{ row.maxUses ?? 1 }}</template>
        </el-table-column>
        <el-table-column prop="usedBy" label="绑定对象" width="100" />
        <el-table-column label="绑定时间" width="160">
          <template #default="{ row }">{{ row.usedAt || '-' }}</template>
        </el-table-column>
        <el-table-column label="失效原因" min-width="140">
          <template #default="{ row }">
            <span :class="{ 'muted': !row.revokeReason }">{{ row.revokeReason || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="130" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="copyCode(row)">复制</el-button>
            <el-button v-if="row.status === '未使用'" size="small" type="danger" @click="revoke(row)">撤销</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 生成弹窗 -->
    <el-dialog v-model="dialogVisible" title="生成邀请码" width="420px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="角色">
          <el-select v-model="form.role">
            <el-option label="管理员" value="管理员" />
            <el-option label="操作员" value="操作员" />
            <el-option label="查看者" value="查看者" />
          </el-select>
        </el-form-item>
        <el-form-item label="有效天数">
          <el-input-number v-model="form.expireDays" :min="1" :max="90" />
        </el-form-item>
        <el-form-item label="使用次数">
          <el-input-number v-model="form.maxUses" :min="1" :max="100" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="doGenerate">生成</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getInviteList, createInvite, revokeInvite } from '@/api/invite'
import type { InviteCode, CreateInviteForm, InviteStatus } from '@/types/invite'

const list = ref<InviteCode[]>([])
const loading = ref(true)

const unusedCount = computed(() => list.value.filter(i => i.status === '未使用').length)
const boundCount = computed(() => list.value.filter(i => i.status === '已绑定').length)
const invalidCount = computed(() => list.value.filter(i => i.status !== '未使用' && i.status !== '已绑定').length)

async function loadData() {
  loading.value = true
  const res = await getInviteList()
  list.value = res.list
  loading.value = false
}

function statusTag(s: InviteStatus) {
  const m: Record<string, string> = { 未使用: 'success', 已绑定: 'primary', 已过期: 'info', 已撤销: 'danger' }
  return m[s] || ''
}

function remainTime(row: InviteCode): string {
  if (row.status !== '未使用') return '-'
  const now = Date.now()
  const expire = new Date(row.expireAt).getTime()
  if (expire <= now) return '已过期'
  const days = Math.ceil((expire - now) / 86400000)
  return `${days} 天`
}

function copyCode(row: InviteCode) {
  navigator.clipboard.writeText(row.code).then(() => ElMessage.success('已复制')).catch(() => ElMessage.info(row.code))
}

async function revoke(row: InviteCode) {
  try {
    const { value } = await ElMessageBox.prompt(`撤销邀请码 ${row.code}，请输入原因`, '撤销邀请码')
    await revokeInvite(row.id, value || '管理员手动撤销')
    row.status = '已撤销'
    row.revokeReason = value || '管理员手动撤销'
    ElMessage.success('已撤销')
  } catch { /* 取消 */ }
}

// ---- 生成 ----
const dialogVisible = ref(false)
const form = reactive<CreateInviteForm>({ role: '操作员', expireDays: 7, maxUses: 1 })

async function doGenerate() {
  const invite = await createInvite(form)
  list.value.unshift(invite)
  dialogVisible.value = false
  ElMessage.success(`邀请码 ${invite.code} 已生成`)
}

onMounted(loadData)
</script>

<style scoped>
.invite-manage { display: flex; flex-direction: column; gap: 16px; max-width: 1400px; }
.stats-row { margin: 0 !important; }
.toolbar { display: flex; align-items: center; justify-content: space-between; }
.toolbar-title { font-size: 16px; font-weight: 600; }
.muted { color: #c0c4cc; }
</style>
