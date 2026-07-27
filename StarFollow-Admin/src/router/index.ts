import { createRouter, createWebHashHistory, type RouteRecordRaw } from 'vue-router'
import AdminLayout from '@/layouts/AdminLayout.vue'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    component: AdminLayout,
    redirect: '/home',
    children: [
      {
        path: 'home',
        name: 'Home',
        component: () => import('@/views/Home.vue'),
        meta: { title: '首页' },
      },
      {
        path: 'realtime-events',
        name: 'RealtimeEvents',
        component: () => import('@/views/EventMonitor.vue'),
        meta: { title: '实时事件' },
      },
      {
        path: 'event-log',
        name: 'EventLog',
        component: () => import('@/views/EventLog.vue'),
        meta: { title: '事件日志' },
      },
      {
        path: 'alarm-center',
        name: 'AlarmCenter',
        component: () => import('@/views/AlarmCenter.vue'),
        meta: { title: '报警中心' },
      },
      {
        path: 'device-manage',
        name: 'DeviceManage',
        component: () => import('@/views/DeviceManage.vue'),
        meta: { title: '检测端管理' },
      },
      {
        path: 'permission-manage',
        name: 'PermissionManage',
        component: () => import('@/views/PermissionManage.vue'),
        meta: { title: '许可管理' },
      },
      {
        path: 'invite-code',
        name: 'InviteCode',
        component: () => import('@/views/InviteManage.vue'),
        meta: { title: '邀请码' },
      },
    ],
  },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

export default router
