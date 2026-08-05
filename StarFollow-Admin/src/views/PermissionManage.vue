<template>
  <div class="permission-manage">
    <!-- 许可概览 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="许可总数" :value="licenses.length" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="有效许可" :value="activeCount" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="即将过期" :value="expiringCount" /></el-card></el-col>
      <el-col :span="6"><el-card shadow="hover"><el-statistic title="已停用" :value="inactiveCount" /></el-card></el-col>
    </el-row>

    <!-- 操作栏 -->
    <el-card shadow="hover">
      <div class="toolbar">
        <span class="toolbar-title">许可发布 — 组合式发卡策略</span>
        <el-button type="primary" @click="openCreate">+ 发布许可</el-button>
      </div>
    </el-card>

    <!-- 许可列表 -->
    <el-card shadow="hover" v-loading="loading">
      <el-table :data="licenses" stripe border>
        <el-table-column prop="name" label="许可名称" width="150" />
        <el-table-column prop="zone" label="区域" width="100" />
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag size="small" :type="statusTag(row.status)">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="策略摘要" min-width="260">
          <template #default="{ row }">
            <el-tag v-if="row.policies.recordEvent" size="small" effect="plain" class="policy-tag">记录事件</el-tag>
            <el-tag v-if="row.policies.allowExecute" size="small" effect="plain" type="success" class="policy-tag">允许执行</el-tag>
            <el-tag v-if="row.policies.forceConfirm" size="small" effect="plain" type="warning" class="policy-tag">强制二次确认</el-tag>
            <el-tag v-if="row.policies.offlineAllowed" size="small" effect="plain" type="info" class="policy-tag">离线许可</el-tag>
            <el-tag size="small" effect="plain" type="danger" class="policy-tag">{{ unauthorizedLabel(row.policies.unauthorizedAction) }}</el-tag>
            <el-tag size="small" effect="plain" class="policy-tag">{{ usageLabel(row.policies.usageLimit) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="cardCount" label="绑定卡片" width="80" />
        <el-table-column prop="keyVersion" label="密钥版本" width="80" />
        <el-table-column prop="expireTime" label="有效期至" width="100" />
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="edit(row)">编辑</el-button>
            <el-button size="small" type="danger" @click="revoke(row)">吊销</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 发布/编辑许可弹窗 -->
    <el-dialog v-model="dialogVisible" :title="editingId ? '编辑许可' : '发布许可'" width="760px" top="4vh">
      <el-form :model="form" label-width="120px">
        <el-form-item label="许可名称"><el-input v-model="form.name" placeholder="如: 正门区域许可" /></el-form-item>
        <el-form-item label="区域">
          <el-select v-model="form.zone" placeholder="选择区域" style="width:100%">
            <el-option v-for="z in ZONE_OPTIONS" :key="z" :label="z" :value="z" />
          </el-select>
        </el-form-item>
        <el-form-item label="有效时间">
          <el-date-picker v-model="form.dateRange" type="daterange" range-separator="至" start-placeholder="开始日期" end-placeholder="结束日期" format="YYYY-MM-DD" value-format="YYYY-MM-DD" style="width:100%" />
        </el-form-item>

        <el-divider content-position="left">策略模板（快捷入口，可再修改）</el-divider>
        <el-form-item label="模板">
          <div class="template-list">
            <el-button v-for="t in POLICY_TEMPLATES" :key="t.key" size="small" @click="applyTemplate(t)" :type="formTemplate === t.key ? 'primary' : ''">
              {{ t.name }}
            </el-button>
            <el-button size="small" @click="clearTemplate">清空</el-button>
          </div>
        </el-form-item>

        <el-divider content-position="left">基础策略</el-divider>
        <el-form-item label="行为">
          <el-checkbox v-model="form.policies.recordEvent">记录事件</el-checkbox>
          <el-checkbox v-model="form.policies.allowExecute">允许执行（开闸/开锁）</el-checkbox>
        </el-form-item>
        <el-form-item label="强制二次确认">
          <el-switch v-model="form.policies.forceConfirm" />
          <span class="policy-desc">开启后用户不得取消，确认失败则不执行（优先级最高）</span>
        </el-form-item>
        <el-form-item label="未授权处理">
          <el-radio-group v-model="form.policies.unauthorizedAction">
            <el-radio-button value="none">不记录</el-radio-button>
            <el-radio-button value="log">仅记录</el-radio-button>
            <el-radio-button value="remind">普通提醒</el-radio-button>
            <el-radio-button value="alarm">紧急报警</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="适用范围">
          <el-select v-model="form.policies.scope" multiple placeholder="选择检测端/区域" style="width:100%">
            <el-option v-for="s in SCOPE_OPTIONS" :key="s" :label="s" :value="s" />
          </el-select>
        </el-form-item>

        <el-divider content-position="left">时间 / 次数 / 扩展</el-divider>
        <el-form-item label="时间限制">
          <el-switch v-model="form.policies.timeLimit.enabled" />
          <template v-if="form.policies.timeLimit.enabled">
            <div class="time-limit-box">
              <el-date-picker v-model="form.policies.timeLimit.startDate" type="date" placeholder="生效日" format="YYYY-MM-DD" value-format="YYYY-MM-DD" style="width:140px" />
              <span>至</span>
              <el-date-picker v-model="form.policies.timeLimit.endDate" type="date" placeholder="失效日" format="YYYY-MM-DD" value-format="YYYY-MM-DD" style="width:140px" />
              <el-time-picker v-model="form.policies.timeLimit.dailyStart" placeholder="每日起" value-format="HH:mm" style="width:120px" />
              <el-time-picker v-model="form.policies.timeLimit.dailyEnd" placeholder="每日止" value-format="HH:mm" style="width:120px" />
            </div>
          </template>
        </el-form-item>
        <el-form-item label="次数限制">
          <el-radio-group v-model="form.policies.usageLimit.type">
            <el-radio-button value="once">一次</el-radio-button>
            <el-radio-button value="fixed">固定次数</el-radio-button>
            <el-radio-button value="unlimited">不限次数</el-radio-button>
          </el-radio-group>
          <el-input-number v-if="form.policies.usageLimit.type === 'fixed'" v-model="form.policies.usageLimit.count" :min="1" :max="10000" style="margin-left:12px" />
        </el-form-item>
        <el-form-item label="离线许可">
          <el-switch v-model="form.policies.offlineAllowed" />
          <span class="policy-desc">检测端断开管理端后允许本地验证</span>
        </el-form-item>
        <el-form-item label="华为设备替代">
          <el-switch v-model="form.policies.huaweiFallback" />
          <span class="policy-desc">允许在手机临时通行模式中使用</span>
        </el-form-item>
        <el-form-item label="方向与事件">
          <el-radio-group v-model="form.policies.direction">
            <el-radio-button value="in">进入</el-radio-button>
            <el-radio-button value="out">离开</el-radio-button>
            <el-radio-button value="both">双向</el-radio-button>
          </el-radio-group>
        </el-form-item>

        <el-divider content-position="left">许可预览</el-divider>
        <el-form-item label="策略预览">
          <div class="preview-box">
            <div class="preview-title">{{ form.name || '未命名许可' }} <el-tag size="small">{{ form.zone || '未选区域' }}</el-tag></div>
            <ul class="preview-list">
              <li v-if="form.policies.recordEvent">✓ 记录经过/签到/到场事件</li>
              <li v-if="form.policies.allowExecute">✓ 允许执行控制信号（开闸/开锁）</li>
              <li v-if="form.policies.forceConfirm" class="hl">★ 管理端强制二次确认（不可取消）</li>
              <li>未授权处理：{{ unauthorizedLabel(form.policies.unauthorizedAction) }}</li>
              <li>适用范围：{{ form.policies.scope.join('、') || '未配置' }}</li>
              <li v-if="form.policies.timeLimit.enabled">时间限制：{{ timeLimitLabel() }}</li>
              <li>次数限制：{{ usageLabel(form.policies.usageLimit) }}</li>
              <li v-if="form.policies.offlineAllowed">✓ 允许离线验证</li>
              <li v-if="form.policies.huaweiFallback">✓ 支持华为设备替代（手机临时通行）</li>
              <li>方向：{{ directionLabel(form.policies.direction) }}</li>
            </ul>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="save">发布许可</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getLicenses, createLicense, revokeLicense } from '@/api/permission'
import { POLICY_TEMPLATES, ZONE_OPTIONS, SCOPE_OPTIONS, defaultPolicy, type License, type CreateLicenseForm, type LicensePolicy, type PolicyTemplate } from '@/types/license'

const licenses = ref<License[]>([])
const loading = ref(true)

const activeCount = computed(() => licenses.value.filter(l => l.status === '有效').length)
const expiringCount = computed(() => licenses.value.filter(l => l.status === '即将过期').length)
const inactiveCount = computed(() => licenses.value.filter(l => ['已过期', '已冻结', '已挂失', '已撤销'].includes(l.status)).length)

async function loadData() {
  loading.value = true
  licenses.value = await getLicenses()
  loading.value = false
}

// ---- 弹窗与表单 ----
const dialogVisible = ref(false)
const editingId = ref('')
const formTemplate = ref('')
const form = reactive<CreateLicenseForm>({ name: '', zone: '', dateRange: null, policies: defaultPolicy() })

function openCreate() {
  editingId.value = ''
  formTemplate.value = ''
  form.name = ''
  form.zone = ''
  form.dateRange = null
  form.policies = defaultPolicy()
  dialogVisible.value = true
}

function edit(row: License) {
  editingId.value = row.id
  formTemplate.value = ''
  form.name = row.name
  form.zone = row.zone
  form.dateRange = null
  form.policies = JSON.parse(JSON.stringify(row.policies))
  dialogVisible.value = true
}

function applyTemplate(t: PolicyTemplate) {
  formTemplate.value = t.key
  form.policies = JSON.parse(JSON.stringify(t.policies))
  ElMessage.success(`已套用「${t.name}」，可继续修改`)
}

function clearTemplate() {
  formTemplate.value = ''
  form.policies = defaultPolicy()
}

// ---- 标签辅助 ----
function unauthorizedLabel(a: LicensePolicy['unauthorizedAction']) {
  const m = { none: '不记录', log: '仅记录', remind: '普通提醒', alarm: '紧急报警' }
  return m[a] || a
}
function usageLabel(u: LicensePolicy['usageLimit']) {
  return u.type === 'once' ? '仅一次' : u.type === 'fixed' ? `固定 ${u.count} 次` : '不限次数'
}
function directionLabel(d: LicensePolicy['direction']) {
  const m = { in: '进入', out: '离开', both: '双向' }
  return m[d] || d
}
function timeLimitLabel() {
  const t = form.policies.timeLimit
  const parts = []
  if (t.startDate) parts.push(t.startDate)
  if (t.endDate) parts.push(`至 ${t.endDate}`)
  if (t.dailyStart && t.dailyEnd) parts.push(`每日 ${t.dailyStart}-${t.dailyEnd}`)
  return parts.join(' ') || '已启用'
}
function statusTag(s: License['status']) {
  const m: Record<string, string> = { 有效: 'success', 即将过期: 'warning', 已过期: 'danger', 已冻结: 'info', 已挂失: 'danger', 已撤销: 'info' }
  return m[s] || ''
}

// ---- 保存与吊销 ----
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
      target.policies = JSON.parse(JSON.stringify(form.policies))
    }
    ElMessage.success('许可已更新')
  } else {
    const newLicense = await createLicense(form, '当前用户')
    licenses.value.unshift(newLicense)
    ElMessage.success('许可已发布')
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
.template-list { display: flex; gap: 8px; flex-wrap: wrap; }
.time-limit-box { display: flex; align-items: center; gap: 8px; margin-top: 8px; flex-wrap: wrap; }
.preview-box { width: 100%; background: #f5f7fa; border-radius: 8px; padding: 12px 16px; }
.preview-title { font-weight: 600; margin-bottom: 8px; display: flex; align-items: center; gap: 8px; }
.preview-list { margin: 0; padding-left: 18px; color: #606266; font-size: 13px; line-height: 1.9; }
.preview-list .hl { color: #e6a23c; font-weight: 600; }
</style>
