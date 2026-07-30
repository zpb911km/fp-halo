---
name: halo_widget_final
description: HALO 项目最终状态摘要（含 embodiment 后）
type: project
created: 2026-07-30 23:51
---

# HALO — 液压联动光环 + 系统数据 Embodiment

## 当前版本
v0.9-emb (git commit 8a13e75)

## 物理层结构（内→外）
层0 光晕 ❌装饰 → 层1 稀疏齿 ✅CPU → 层2 环 ❌内存 → 层3 配对齿 ✅装饰 → 层4 密集齿 ✅网络

## 核心功能
- 5 层光环以心律失常的液压猝发节奏呼吸/闪烁/旋转
- 系统数据通过 `PlasmaCore.DataSource + engine:executable` 从 /proc 采集
- 安全可扩展：加一行命令 + 一行 onNewData 解析即可新增传感器

## 三环 Embodiment

| 层 | 硬件 | 可旋 | 颜色映射 | 其他维度 |
|----|------|------|---------|---------|
| 1 | CPU | ✅ | 使用率: 蓝绿↔红 | 温度→脉冲↑, 负载→旋转↑ |
| 2 | 内存 | ❌ | 使用率: 绿↔紫 | 使用率→亮度↑ |
| 4 | 网络 | ✅ | 下行: 翡↔金 | 上行→脉冲↑, 吞吐→旋转↑ |

## 颜色配置
双端色 (start/end)：调色盘面板实时输入 #rrggbb

## 遗留
- 层3 配对齿（装饰）闲置，可分配给后续硬件
- 无毛玻璃 / 整体透明度 / 响应式尺寸
- 完整手册见 memory: halo_embodiment_manual
