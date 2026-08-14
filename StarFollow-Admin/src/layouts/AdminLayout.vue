<template>
  <el-container class="admin-layout">
    <!-- 左侧导航 -->
    <el-aside :width="isCollapse ? '64px' : '220px'" class="admin-aside">
      <div class="logo-area">
        <span v-if="!isCollapse" class="logo-full">StarFollow</span>
        <span v-else class="logo-short">SF</span>
      </div>

      <el-menu
        :default-active="activeMenu"
        :collapse="isCollapse"
        router
        background-color="#001529"
        text-color="#ffffffa6"
        active-text-color="#ffffff"
      >
        <el-menu-item index="/home">
          <el-icon><HomeFilled /></el-icon>
          <template #title>首页</template>
        </el-menu-item>
        <el-menu-item index="/realtime-events">
          <el-icon><VideoCamera /></el-icon>
          <template #title>实时事件</template>
        </el-menu-item>
        <el-menu-item index="/event-log">
          <el-icon><Document /></el-icon>
          <template #title>事件日志</template>
        </el-menu-item>
        <el-menu-item index="/alarm-center">
          <el-icon><Bell /></el-icon>
          <template #title>报警中心</template>
        </el-menu-item>
        <el-menu-item index="/confirmation-center">
          <el-icon><CircleCheck /></el-icon>
          <template #title>待确认</template>
        </el-menu-item>
        <el-menu-item index="/device-manage">
          <el-icon><Monitor /></el-icon>
          <template #title>检测端管理</template>
        </el-menu-item>
        <el-menu-item index="/permission-manage">
          <el-icon><Key /></el-icon>
          <template #title>许可发布</template>
        </el-menu-item>
        <el-menu-item index="/invite-manage">
          <el-icon><Tickets /></el-icon>
          <template #title>邀请码管理</template>
        </el-menu-item>
        <el-menu-item index="/card-license-manage">
          <el-icon><CreditCard /></el-icon>
          <template #title>卡片/许可管理</template>
        </el-menu-item>
        <el-menu-item index="/system-settings">
          <el-icon><Setting /></el-icon>
          <template #title>系统设置</template>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <!-- 右侧主区域 -->
    <el-container>
      <!-- 顶部状态栏 -->
      <el-header class="admin-header">
        <div class="header-left">
          <el-icon class="collapse-btn" @click="isCollapse = !isCollapse">
            <Fold v-if="!isCollapse" />
            <Expand v-else />
          </el-icon>
          <span class="header-title">星随 StarFollow 管理中心</span>
        </div>
        <div class="header-right">
          <span class="header-time">{{ currentTime }}</span>
          <el-tag size="small" :type="wsConnected ? 'success' : 'warning'">{{ wsConnected ? '实时链路正常' : '实时链路重连中' }}</el-tag>
        </div>
      </el-header>

      <!-- 页面内容 -->
      <el-main class="admin-main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { HomeFilled, VideoCamera, Document, Bell, Monitor, Key, Tickets, CreditCard, Setting, Fold, Expand, CircleCheck } from '@element-plus/icons-vue'
import { connectEventSocket, closeSocket, onSocketState } from '@/api/websocket'

const route = useRoute()
const isCollapse = ref(false)

const activeMenu = computed(() => route.path)
const currentTime = ref('')
const wsConnected = ref(false)

function updateTime() {
  const now = new Date()
  currentTime.value = now.toLocaleString('zh-CN', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  })
}

let timer: ReturnType<typeof setInterval> | null = null
let unsubscribeSocket: (() => void) | null = null

onMounted(() => {
  updateTime()
  timer = setInterval(updateTime, 1000)
  unsubscribeSocket = onSocketState(connected => { wsConnected.value = connected })
  connectEventSocket()
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
  unsubscribeSocket?.()
  closeSocket()
})
</script>

<style scoped>
.admin-layout {
  height: 100vh;
}

.admin-aside {
  background-color: #001529;
  overflow-x: hidden;
  transition: width 0.2s;
}

.logo-area {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 2px;
  border-bottom: 1px solid #ffffff1a;
}

.logo-short {
  font-size: 18px;
  font-weight: 800;
}

.admin-header {
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  border-bottom: 1px solid #e8e8e8;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04);
  height: 56px;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.collapse-btn {
  font-size: 20px;
  cursor: pointer;
  color: #606266;
}
.collapse-btn:hover {
  color: #409eff;
}

.header-title {
  font-size: 16px;
  font-weight: 600;
  color: #303133;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 16px;
}

.header-time {
  font-size: 13px;
  color: #909399;
  font-family: monospace;
}

.admin-main {
  background: #f0f2f5;
  padding: 24px;
  overflow-y: auto;
}
</style>
