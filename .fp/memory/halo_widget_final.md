---
name: halo_widget_final
description: HALO v0.10 — 完整体检映射手册(磁盘/CPU/内存/GPU/网络)
type: project
created: 2026-07-31 00:52
---

# HALO v0.10 — 完整设计文档

## 物理层结构（从内向外）
层0 光晕   (🌫 半透明圆, ❌不可旋转) → 磁盘 I/O
层1 稀疏齿 (🦷 有齿, ✅可旋转)      → CPU
层2 环     (⭕ 实心圆, ❌不可旋转)  → 内存
层3 配对齿 (🦷 有齿, ✅可旋转)      → GPU
层4 密集齿 (🦷 有齿, ✅可旋转)      → 网络

## 数据映射

### 层0 — 磁盘
- 命令: awk '/sd[a-z] |nvme[0-9]n[0-9] /{r+=$6;w+=$10} END{printf "%d %d", r, w}' /proc/diskstats
- 颜色=总吞吐量(读+写): 低→冷色 #5a8a7a, 高→暖色 #c0a050
- 脉冲速度=吞吐量(越高越快)
- 参考: 50000 sectors/s ≈ 25MB/s

### 层1 — CPU
- 数据: ps -eo %cpu → 求和 ÷ 核心数 (均摊百分比)
- 颜色: 0% #2a6e7e → 100% #c04040
- 脉冲幅度: CPU温度 35°C~90°C 映射 0.5~3.0
- 旋转速度: 系统负载 0~3.0 映射 0.3~3.0

### 层2 — 内存
- 数据: /proc/meminfo (Total-Available)/Total
- 颜色: 0% #3a9a6a → 100% #b058d0
- 亮度: 0%→暗 0.3, 100%→亮 1.5

### 层3 — GPU
- 数据: nvidia-smi --query-gpu=memory.used,memory.total,temperature.gpu
- 颜色: VRAM% 0% #6ab0c0 → 100% #d05030
- 脉冲幅度: VRAM% 0%→0.5, 100%→3.0
- 旋转速度: GPU温度 35°C→0.3(慢), 90°C→3.0(快)

### 层4 — 网络
- 数据: /proc/net/dev enp|wlp 累计差值
- 颜色: 下行速率 0→5MB/s: #4a8a7a → #d0a050
- 脉冲幅度: 上行速率 0→5MB/s: 0.5→3.0
- 旋转速度: 上下行总量 0→10MB/s: 0.5→3.0

## 双端色配置
层0磁盘:   #5a8a7a → #c0a050
层1 CPU:   #2a6e7e → #c04040
层2 内存:  #3a9a6a → #b058d0
层3 GPU:   #6ab0c0 → #d05030
层4 网络:  #4a8a7a → #d0a050

## 核心公式
颜色插值: lerpColor(h1, h2, t) = R1+(R2-R1)*t, G1+(G2-G1)*t, B1+(B2-B1)*t
