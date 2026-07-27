import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

/** 系统全局状态 */
export const useSystemStore = defineStore('system', () => {
  // ---- 状态 ----
  const sidebarCollapsed = ref(false)
  const systemName = ref('星随管理端')
  const wsConnected = ref(false)
  const token = ref('')

  // ---- 计算属性 ----
  const sidebarWidth = computed(() => (sidebarCollapsed.value ? '64px' : '220px'))

  // ---- 操作 ----
  function toggleSidebar() {
    sidebarCollapsed.value = !sidebarCollapsed.value
  }

  function setWsConnected(v: boolean) {
    wsConnected.value = v
  }

  function setToken(t: string) {
    token.value = t
  }

  return {
    sidebarCollapsed,
    systemName,
    wsConnected,
    token,
    sidebarWidth,
    toggleSidebar,
    setWsConnected,
    setToken,
  }
})
