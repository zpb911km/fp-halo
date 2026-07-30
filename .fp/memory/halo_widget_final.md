---
name: halo_widget_final
description: HALO 液压联动光环小部件最终实现方案
type: project
created: 2026-07-30 20:48
---

## HALO 小部件 — QML Canvas 纯渲染方案

### 核心架构
- QML Canvas + 手工逐段逼近弧线（arcAt 函数），完全绕过 Qt arc() 对小角度的粗糙近似
- `Plasmoid.backgroundHints: NoBackground` 实现透明背景
- 左上角 Text 显示版本号（v0.2）

### 齿数恒定方案
齿数由圆心角定义：`cycleTotal` = 各段角度之和，`numTeeth = 360/cycleTotal`
用 arcAt 逐齿绘制，齿数永远不变（之前用 ctx.arc + setLineDash 导致齿数因渲染精度变化）

### 物理系统
- 5 层光环各自独立猝发脉冲（easeOutCubic 缓动）
- 每层有 iInt/oInt/tDur 三个参数控制脉冲节奏
- 物理约束（enf）防止层间穿模

### 闪烁与旋转
- flickerKfs：每层独立的闪烁关键帧（精确复现 CSS 时序）
- rotKfs：旋转关键帧 + cubic-bezier(0.4,0,0.2,1) 牛顿法解算
- 层1顺时针23s、层3逆时针29s、层4顺时针31s

### 文件位置
~/media/zpb/data/codes/KDEplugin/fp-halo/
- src/metadata.json：Name=HALO
- src/contents/ui/main.qml：全部逻辑
- Makefile：make install / make remove
