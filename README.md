# HALO — 系统数据光环

> KDE Plasma 6 桌面小部件 · 系统数据 × 科幻视觉

一个浮在壁纸上的**系统仪表盘**。光环的几何与动画**逐参数复刻**《雨世界》迭代器
的 `OracleGraphics.Halo`（type #2139）—— 2 道细环 + 100 个独立呼吸的记忆位 +
3 环该物种特有的抽搐式旋转；颜色与数据映射来自本挂件。

规格书见 [`docs/HALO_2139_SPEC.md`](./docs/HALO_2139_SPEC.md)（全部常量来自
`Assembly-CSharp.dll` 的 IL 反汇编）。参考实现：`tools/halo2139_sim.py`（Python，
可导出静帧/视频作逐帧比对基准）、`contents/ui/halo2139.js`（QML 实际使用）。

## 一览

径向结构（游戏单位：半径 57 = 常态外沿，挂件按此等比缩放至组件的内接圆）：

```
半径 30  环 0        细环 3px；温度告警时整盘填成实心墨      ← CPU 色
半径 35  记忆位 ×10   齿长 = 独立随机呼吸                    ← 磁盘 I/O
半径 40  环 1        细环 3px；随内存占用加粗                ← 内存 色
半径 45  记忆位 ×30   齿长 = 独立随机呼吸                    ← GPU 显存
半径 55  记忆位 ×60   最密的一圈，会连成毛刷状                ← 网络吞吐
```

动画不是关键帧：每个记忆位以 1/60 概率独立重抽填充目标（快慢
`1/Lerp(2,80,rand)`），整环有 1/60 概率被打满并闪 20 帧；旋转是
"到达即重抽 ±[15°,150°]" 的抽搐，用 `SCurve` 弹性趋近。

> 原版另有 20 条从光环射向房间边界的神经连线，其锚点半径是光环的 7.2 倍，
> 正常尺寸的挂件装不下 —— 状态机保留（`halo.linkLevel`），但不渲染。
> 详见规格书 §10.4。

## 环境要求

- **KDE Plasma 6**（Qt6 / KF6）。
- 需要 `org.kde.plasma.plasma5support`（Plasma 6 自带）。
- GPU 层依赖 `nvidia-smi`（存在才启用，缺失时该层静止，不影响其余）。

## 安装

### 方法一：从 GitHub 克隆（推荐）

```bash
git clone https://github.com/zpb911km/fp-halo.git
mkdir -p ~/.local/share/plasma/plasmoids/org.zpb.halo
rsync -a --delete --exclude='.git/' --exclude='*.plasmoid' \
  fp-halo/ ~/.local/share/plasma/plasmoids/org.zpb.halo/

# 重启 plasmashell（Plasma 6 / Wayland）
kquitapp6 plasmashell; sleep 3
setsid -f plasmashell --no-respawn >/tmp/plasmashell.log 2>&1
```

然后在桌面右键 → 添加小部件 → 搜索 **HALO** → 拖到桌面。

### 方法二：`.plasmoid` 一键安装

```bash
kpackagetool6 --type Plasma/Applet --install org.zpb.halo.plasmoid

# 升级已安装版本：
kpackagetool6 --type Plasma/Applet --upgrade org.zpb.halo.plasmoid
```

## 颜色定制

每个数据层支持**双端色**：起始色（低负载/空闲）→ 终止色（高负载/繁忙），中间线性插值。

在小部件配置面板中为每一层分别设置。

## 手册

- [`docs/HALO_2139_SPEC.md`](./docs/HALO_2139_SPEC.md) — Halo #2139 逆向规格 + 挂件映射（现行）
- [`HALO_EMBODIMENT_MANUAL.md`](./HALO_EMBODIMENT_MANUAL.md) — v0.x 五层齿环设计手册（**已被取代**，仅存档）

## 技术栈

- **QML** + **Canvas 2D** — 纯 QML 渲染，零外部依赖
- **plasma5support DataSource (executable engine)** — 通过 shell 命令采集系统数据
- **数据来源**: `/proc/stat`, `/proc/meminfo`, `/proc/net/dev`, `/proc/diskstats`, `nvidia-smi`

## 版本

- **v1.0** — 渲染层整体重写为 Halo #2139 的参数级复现：`halo2139.js`
  状态机（40 tick/s）+ 数据调制分离；分辨率无关缩放（常态外沿内接组件）；
  去掉 5 层关键帧齿环与 20 条连线渲染
- **v0.11** — 迁移到 Plasma 6 / Qt6：`PlasmoidItem` 根元素、`plasma5support` 数据源、
  `metadata.json` 补 `X-Plasma-API-Minimum-Version`；配置页重写
- **v0.10** — 五层全映射: 磁盘 / CPU / 内存 / GPU / 网络
