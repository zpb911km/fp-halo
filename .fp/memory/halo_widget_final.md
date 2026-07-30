---
name: halo_widget_final
description: KDE Plasma 5 HALO 液压光环小部件 — 完整项目总结
type: project
created: 2026-07-30 21:55
---

## 项目：HALO — 液压联动光环（KDE Plasma 5 Widget）

### 基本信息
- **存储路径**：`/media/zpb/data/codes/KDEplugin/fp-halo/`
- **插件 ID**：`org.zpb.halo`（Name 仅 "HALO"，无多余文字）
- **安装路径**：`~/.local/share/plasma/plasmoids/org.zpb.halo/`
- **构建产物**：`org.zpb.halo.plasmoid`（zip 包）
- **入口文件**：`src/contents/ui/main.qml`
- **当前版本**：`v0.9`
- **Git 标签**：`v0.6-pre`（重构前备份）、`v0.8`（重构后）、`v0.9`（RGBA 支持）

### 版本演进（v0.1 → v0.9）

| 版本 | 变更 |
|------|------|
| v0.1 | HTML/SVG 方案，CSS 闪烁+旋转 |
| v0.2 | 转 QML Canvas 原生绘制，背景透明 |
| v0.3 | 修复①完全透明看不见（st 在 Component.onCompleted 初始化）；②齿数变化观感（脉冲间隔使用每层独立值，对应 CSS 原版 3s/5s/7s/11s/13s） |
| v0.4 | 颜色定制：全局预设组切换（5层同时变），修复点击色块只有单层变化的 bug |
| v0.5 | 设置面板色块矩阵：每层 6 色块对应 6 组预设，高亮当前 |
| v0.6 | 修复色块矩阵对角线 bug（嵌套 Repeater index 遮盖）；加 hex 输入框支持任意颜色 |
| v0.7 | 简化面板：去除色块矩阵，仅保留层名 + 预览色块 + hex 输入框 |
| v0.8 | **重构**：清空重写为 10 分区结构（2a~2k），逻辑不变，代码从 433 行优化至 398 行 |
| v0.9 | **RGBA 支持**：输入 `#rrggbb[aa]`，7 位表示半透明，Canvas strokeStyle 使用 `Qt.rgba()`，不依赖 context.globalAlpha |

### 核心算法

**5 层光环**（由内到外）：
- 层0：光晕（连续无齿，3s 闪烁）
- 层1：稀疏（18齿，5s 闪烁，23s 顺时针旋转）
- 层2：环（连续无齿，7s 闪烁）
- 层3：配对（4段=2齿+2gap，11s 闪烁，29s 逆时针旋转）
- 层4：密集（72齿，13s 闪烁，31s 顺时针旋转）

**液压猝发**：内外边界各自独立随机脉冲，受相邻层约束和全局边界限制，迭代约束 3 次确保不穿模。

**闪烁**：精确复刻 CSS 关键帧时序（每层独立 flickerKfs 表）。

**旋转**：stop-and-go 关键帧 + cubic-bezier(0.4,0,0.2,1) 牛顿法解算。

**齿数恒定**：使用圆心角定义，`arcAt()` 手工逐线绘制绕过 Qt arc() 对<1°小弧的粗糙近似。

### 设置面板
- 点击右下角 ⚙ 弹出深色半透明面板
- 5 行配置：层名 + 预览色块 + monospace hex 输入框
- 输入 `#rrggbb`（不透明）或 `#rrggbbaa`（带透明度），回车/失焦生效
- 正则校验：`/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/`
- Esc 关闭面板

### 构建与安装
```bash
# 构建 + 安装
cd /media/zpb/data/codes/KDEplugin/fp-halo && make install

# 清除缓存 + 重启
rm -rf ~/.cache/plasmashell/qmlcache/
kquitapp5 plasmashell && sleep 2 && kstart5 plasmashell &
```

### 候选待办功能
1. 毛玻璃效果（小部件背景模糊/高斯模糊，可调强度）
2. 前景整体透明度滑块
3. 自适应小部件拖拽尺寸（当前写死 400×400 缩放）
4. 性能优化（GPU 加速/帧率控制）
