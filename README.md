# HALO — 液压联动光环

> KDE Plasma 5 桌面小部件 · 系统数据 × 科幻视觉

一个浮在壁纸上的**系统仪表盘**——五层光环以心律失常的液压猝发节奏呼吸、闪烁、旋转，每一层映射一个硬件设备的状态。

## 一览

```
层0 光晕   → 磁盘 I/O   颜色(吞吐量) + 脉冲(吞吐量)
层1 稀疏齿 → CPU         颜色(使用率) + 脉冲(温度)   + 旋转(负载)
层2 环     → 内存        颜色(使用率) + 亮度(使用率)
层3 配对齿 → GPU         颜色(显存%)  + 脉冲(显存%)  + 旋转(温度)
层4 密集齿 → 网络        颜色(下行)   + 脉冲(上行)   + 旋转(总吞吐)
```

每个硬件一个环，每个环 2~3 种视觉维度同时表达不同参数。

## 安装

```bash
# 克隆
git clone git@github.com:zpb911km/fp-halo.git
cd fp-halo

# 安装到 Plasma
cp -r . ~/.local/share/plasma/plasmoids/org.zpb.halo/

# 重启 Plasma
killall plasmashell && plasmashell --replace & disown
```

然后在桌面右键 → 添加小部件 → 搜索 **HALO** → 拖到桌面。

## 颜色定制

每个数据层支持**双端色**：起始色（低负载/空闲）→ 终止色（高负载/繁忙），中间线性插值。

在调色盘面板中为每一层分别设置。

## 手册

详细映射公式和测试清单见 [`HALO_EMBODIMENT_MANUAL.md`](./HALO_EMBODIMENT_MANUAL.md)

## 技术栈

- **QML** + **Canvas 2D** — 纯 QML 渲染，零外部依赖
- **PlasmaCore.DataSource (executable engine)** — 通过 shell 命令采集系统数据
- **数据来源**: `/proc/stat`, `/proc/meminfo`, `/proc/net/dev`, `/proc/diskstats`, `nvidia-smi`

## 版本

v0.10 — 五层全映射: 磁盘 / CPU / 内存 / GPU / 网络
