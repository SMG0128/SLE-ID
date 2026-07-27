<template>
  <el-card class="status-card" shadow="hover">
    <div class="status-card__body">
      <div class="status-card__icon">
        <el-icon :size="32" :color="color">
          <component :is="icon" />
        </el-icon>
      </div>
      <div class="status-card__info">
        <div class="status-card__label">{{ label }}</div>
        <div class="status-card__value" :style="{ color }">{{ value }}</div>
        <div v-if="unit" class="status-card__unit">{{ unit }}</div>
      </div>
    </div>
  </el-card>
</template>

<script setup lang="ts">
defineProps<{
  icon: string
  label: string
  value: string | number
  unit?: string
  color?: string
}>()
</script>

<style scoped>
.status-card {
  min-width: 200px;
}

.status-card__body {
  display: flex;
  align-items: center;
  gap: 16px;
}

.status-card__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  border-radius: 12px;
  background: var(--el-color-primary-light-9);
}

.status-card__label {
  font-size: 13px;
  color: #909399;
}

.status-card__value {
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
}

.status-card__unit {
  font-size: 12px;
  color: #c0c4cc;
}
</style>
