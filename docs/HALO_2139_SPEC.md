# 迭代器光环 `OracleGraphics+Halo` 规格书（雨世界）

> 目标类：`Assembly-CSharp.dll` → `OracleGraphics` 内嵌类 `Halo`（TypeDef **#2139**）
> 逆向方式：IL 逐条反汇编（dnfile + dncil），无参考源码
> 本文所有常量均可追溯到具体指令，**不是估计值**

## 溯源

| 资产 | 路径 / 摘要 |
|---|---|
| 程序集 | `RainWorld_Data/Managed/Assembly-CSharp.dll`，9,064,960 B，`b6be1d4e18ce219d21091b51…` |
| Shader | `RainWorld_Data/StreamingAssets/shaders/VectorCircle.shader`（**明文**），`a2b8cacf8e205805bbdcf69b…` |
| 宿主类 | `OracleGraphics`（`GraphicsModule` 子类，管理 FP/Moon 的 puppet） |
| 同类干扰项 | 另有 4 个 `Halo`：#2266 `TempleGuard`、#2759、#2796、`MoonHalo` #3425 —— **均非本文对象** |

`Halo#2139` 的成员方法：`.ctor` `Update` `ChangeAllRadi` `Radius` `Rotation` `Center` `InitiateSprites` `DrawSprites`。

---

## 0. TL;DR

1. **光环没有颜色。** 122 个精灵全部硬编码 `new Color(0,0,0)`。观感颜色 100% 来自房间背景透出。
2. **alpha 被复用为"内孔半径"**，不是透明度。`VectorCircle` shader 把它当几何参数用，输出恒定 alpha=1 → 不透明黑。
3. 整个光环画在 **`BackgroundShortcuts`** 容器（背景层），被 puppet / slugcat 压在下面。
4. 动画由 **6 个独立随机过程** 叠加：旋转抽搐、逐 bit 填充、整环 blink、连线点亮、`expand/push/white` 三速缓动、语音频谱收缩。
5. 外环直径稳态中位 **100px**（p05 80 / p95 160），房间 1400×800。

---

## 1. 精灵清单（`InitiateSprites`，共 122 个）

| 序号 | 数量 | 元素 / 构造 | 初始状态 |
|---|---|---|---|
| `firstSprite + 0..1` | 2 | `FSprite("Futile_White", true)` + `shader = Shaders["VectorCircle"]` | `color = Color(0,0,0)` |
| `+2 .. +21` | 20 | `TriangleMesh.MakeLongMesh(20, false, false)` | `color = Color(0,0,0)` |
| `firstBitSprite + 0..99` | 100 | `FSprite("pixel")`，`scaleX = 4` | `color = Color(0,0,0)` |

- `totalSprites` 初始 2 → `+= connections.Length(20)` → `+= 100` = **122**
- `firstBitSprite = firstSprite + totalSprites`（此时 = firstSprite + 22）
- `AddToContainer`：全部加入 `RoomCamera.ReturnFContainer("BackgroundShortcuts")`

---

## 2. 颜色链路（为什么"没颜色"）

### 2.1 唯一颜色赋值

`InitiateSprites` 中三处 `newobj Color::.ctor`，参数均为 `ldc.r4 0.0 ×3`
→ `UnityEngine.Color(float r, float g, float b)`，即 **黑，a=1**。

`Halo` 的 17 个字段中**没有**任何颜色字段：

```
owner, firstSprite, totalSprites, connections, connectionsFireChance,
bits, firstBitSprite, ringRotations,
expand/lastExpand/getToExpand, push/lastPush/getToPush,
white/lastWhite/getToWhite
```

`SkinColor` / `ApplyPalette` / `GenericJointBaseColor` 等只作用于 **puppet 身体**（`OracleGraphics` 外层类），与光环无关。

### 2.2 Shader 语义

```hlsl
Blend SrcAlpha OneMinusSrcAlpha
half centerDist = clamp(distance(i.uv.xy, half2(0.5,0.5))*2, 0, 1);
if (centerDist < 1 - i.clr.w || centerDist == 1.0)
    return half4(0,0,0,0);
return half4(i.clr.xyz, 1);
```

- `i.clr.w` = 顶点色 alpha = `FNode.alpha`（`color.a=1` 时）
- 判定式 `centerDist >= 1 - alpha` → 画出的环带：`[ (1-alpha)·R , R ]`
- **环宽 = `alpha · R`**
- 输出 `half4(rgb, 1)` → 完全覆盖背景（非叠加、非半透）

### 2.3 两个环的 alpha（`DrawSprites`）

```
环0: alpha = Lerp( 3.0/Radius(0,t), 1.0, Lerp(lastWhite, white, t) )
环1: alpha = 3.0 / Radius(1,t)                       // 恒为 3px 细环
```

推论：

| `white` | 环0 表现 |
|---|---|
| 0 | 与环1 相同的 3px 细环 |
| 0→1 | 环壁变厚 |
| 1 | alpha=1 → 内孔半径 0 → **实心墨盘**（覆盖整片背景） |

> 字段名叫 `white`，效果是"实心墨盘"。这是全案最反直觉处，建议用游戏内截图交叉验证。

### 2.4 视觉结论

- 光环自身是**无彩色**的墨线；"发光感"完全由房间背景亮度/色调提供。
- `gt_pulse` 图显示了 `white=1` 时实心盘的样子（发到手机的对比图之一）。

---

## 3. 几何公式

```csharp
Center(t)  = Lerp(body.firstChunk.lastPos, pos, t)     // 取 firstChunk
           → 记为 body
           = head(t) + DirVec(body, head(t)) * 20f      // head(t) = Lerp(head.lastPos, head.pos, t)

Radius(i,t) = ( (3f + i + Lerp(lastPush, push, t))
                - 0.5f * owner.averageVoice )
              * Lerp(lastExpand, expand, t) * 10f

Rotation(i,t) = Lerp(ringRotations[i,1], ringRotations[i,0], t)   // 上帧 → 当前帧
```

`expand = 1, push = 0` 时为**标准尺度**：

| 用途 | i | 半径 |
|---|---|---|
| 环0 | 0 | 30 |
| bit 层 0 | 0.5 | 35 |
| 环1 | 1 | 40 |
| bit 层 1 | 1.5 | 45 |
| bit 层 2 | 2.5 | 55 |
| 连线控制点 | 2 | 50 |

（`push` 有 95% 的时间为 0，故半径常态就锁在上表的值：30 / 40 / 35 / 45 / 55；
只有偶发事件（约 32 秒一次）才短暂抬升。见 §6。）

---

## 4. 绘制（`DrawSprites`）

### 4.1 环

```
sprite[i].x = Center.x - cam.x ; .y = Center.y - cam.y
sprite[i].scale = Radius(i,t) / 8          // Futile_White 为 16×16 → 直径 = 2R
sprite[i].alpha = 见 §2.3
```

### 4.2 bit（100 个）

```
angle      = (j / bits[ring].Length) * 360 + Rotation(ring, t)
pos        = Center + DegToVec(angle) * Radius(ring + 0.5, t)
sprite.x/y = pos - cam
sprite.rotation = angle
sprite.scaleX   = 4              // 常量，InitiateSprites 中设定
sprite.scaleY   = 8 * bit.Fill(t)
```

**长轴朝向：切向（已定案）。** `scaleY = 8·Fill` 沿环的**切向**生长，
`scaleX = 4` 是径向厚度。即 bit 是"沿环方向变长的齿"，不是"沿半径长出的刺"。

判定依据：
1. `sprite.rotation = angle`。Futile 的 rotation 把精灵**局部 +X 轴**转到给定角度，
   而 `angle` 正是该点的极角方向（=径向）→ 局部 X = 径向、局部 Y = 切向。
   若取径向长轴，就得额外假设"局部 +X 落在切向"，多一次 90° 的假设。
2. 游戏内实拍对照确认（A/B 图为 `/tmp/halo_gt/axis_ab.png`）。

**已知后果**：外环 60 齿、r=55 时相邻弦长 `2·55·sin(π/60) ≈ 5.76px`，
而切向长边最大 8px → **满填充时相邻齿重叠 2.24px，连成连续弧**。
这不是 bug：实际各 bit 独立随机填充，很少同时满格，观感是疏密不一的齿梳，
只有整环 `SetToMax` / blink 期间才会短暂连成实环。

### 4.3 连接线（20 条 × 20 段）

`Custom.Bezier` 是 **5 参三次贝塞尔**，但**第 3、4 参数的语义是反的**：
`Bezier(Vector2 a, Vector2 b, Vector2 c, Vector2 d, float t)` 实际等价于标准贝塞尔 `(a, b, d, c)`，
即 **P0 = a、P1 = b、P2 = d、P3 = c**。

判定依据（IL 实为 de Casteljau 变体）：
`L1 = Lerp(b,d,t)`；`A = Lerp(a,b,t)`；`D = Lerp(d,c,t)`；`A2 = Lerp(A,L1,t)`；`D2 = Lerp(L1,D,t)`；`return Lerp(A2,D2,t)`。
代数展开得 `(1-t)³·a + 3t(1-t)²·b + 3t²(1-t)·d + t³·c` —— `c` 拿 `t³`（终点），`d` 拿 `3t²(1-t)`（内控制点）。
**按标准参数序画会把起点终点整体画反。**

```
light  = 2 * Lerp(c.lastLightUp, c.lightUp, t)     // ← 半宽（≤2px），不是段长
dir    = DirVec(Center, c.stuckAt)                 // 单位向量：中心 → 附着点
ctrl   = Center + dir * Radius(2, t)               // 注意：不乘 2
end    = Center + dir * 400
a0     = c.stuckAt                                 // 起点固定，不累进
hd     = c.handle                                  // 第二控制点 = stuckAt + RNV() * Lerp(400,700,rnd)
prev   = a0
for j in 0..19:
    q       = Bezier(a0, hd, ctrl, end, j/19)      // 标准序为 (a0, hd, end, ctrl)
    segLen  = Distance(prev, q)
    th      = segLen * 0.3                         // ← 四边形沿曲线的长度，不是粗细
    segDir  = DirVec(prev, q)
    perp    = PerpendicularVector(segDir)
    v[j*4+0] = q - segDir*th - perp*light
    v[j*4+1] = q - segDir*th + perp*light
    v[j*4+2] = q            - perp*light
    v[j*4+3] = q            + perp*light
    prev    = q
```

#### 4.3.1 锚点与手柄（`Halo.Connection::.ctor`，已逐条核对 IL）

```csharp
// 调用方 Halo::.ctor
pos = new Vector2(room.PixelWidth/2f, room.PixelHeight/2f)  // 房间中心
    + Custom.RNV() * Lerp(300f, 500f, Random.value);        // RNV = DegToVec(value*360°)
new Connection(this, pos);

// 构造器
p = pos;
p.x = Clamp(p.x, arm.cornerPositions[0].x, arm.cornerPositions[1].x);
p.y = Clamp(p.y, arm.cornerPositions[2].y, arm.cornerPositions[1].y);
stuckAt = Lerp(pos, p, 0.5f);          // 落在盒内则原样，盒外只拉回一半
handle  = pos + RNV() * Lerp(400f, 700f, Random.value);  // 基点是 pos，不是 stuckAt
```

- 锚点环**以房间中心为圆心**，与 halo 自身位置无关。
- `handle` 的基础点是被夹**之前**的 `pos`；两者重合仅当不发生夹取。
- `arm_box=None` 时不做夹取。`cornerPositions` 由 `OracleArm::.ctor/Update` 按关节位置
  逐帧算出、随手臂动画变化，无法只从 Halo 的 IL 推出。夹取强度实测（锚点环 300~500）：

| arm_box | mean \|stuckAt\| |
|---|---|
| 无（None） | 399.8 |
| 200×150 | 255.9 |
| 400×300 | 308.2 |
| 800×500 | 370.9 |
| 1200×700 | 392.3 |

> 采样：每档 800 条（seed 1000..1039 × 20 条），距离相对房间中心。单 seed 只有 20 条，
> 标准误约 ±15，**不要用单 seed 复核本表**。CLI 可对照跑：
> `python3 tools/halo2139_sim.py stats --arm-box X0 Y0 X1 Y1`

- `handle` 是**随机方向**（`RNV()` 每次重抽角度），因此四个控制点一般不共线，
  曲线是被"从随机远点拽回"的大弧。
- **起点 `a = stuckAt`（r≈430，边框），终点 `c = Center + dir*Radius(2,t)`（r≈50，正好停在
  halo 外环 40px 之外）**。所以连线是"从边框甩到 halo 边缘"的曲线：一端在边框、
  一端贴在 halo 上，且不进入 halo 内部。
- 顶点 alpha 未单独设置（保持 1）；亮度只通过 **线宽** 体现，`light` 同时是 `Rectangle` 的半宽。

---

## 5. 动画状态机（40 tick/s）

### 5.1 旋转抽搐

`ringRotations` 为 `float[10,5]`：`[cur, last, start, target, progress]`

```csharp
for (i = 0; i < 10; i++) {
    R[1] = R[0];
    if (R[0] != R[3]) {
        R[4] += 1f / Mathf.Lerp(20f, Mathf.Abs(R[2] - R[3]), 0.5f);
        R[0]  = Mathf.Lerp(R[2], R[3], Custom.SCurve(R[4], 0.5f));
        if (R[4] > 1f) { R[4] = 0f; R[2] = R[3]; R[0] = R[3]; }   // 硬吸附
    } else if (Random.value < 1f/30f) {
        R[3] = R[0] + (Random.value < 0.5f ? 1f : -1f) * Mathf.Lerp(15f, 150f, Random.value);
    }
}
```

`Custom.SCurve(t, k)`：

```csharp
t = t*2 - 1;
if (t < 0) { t = Abs(1 + t); return 0.5f * (k*t) / (1 + k - t); }
k = -1 - k;  return 0.5f + 0.5f * (k*t) / (k - t + 1);
```

特征：
- **不是匀速旋转**，是"到位后静置 → 抽搐一下"。
- 摆幅越小越快：15° ≈ 17 tick（0.43s），150° ≈ 85 tick（2.1s）。
- 10 组环参数，但只有 `i ∈ {0,1,2}` 被绘制使用（bit 三层各用一组）。

### 5.2 单 bit 填充（`MemoryBit`）

```csharp
void Update() {
    lastFilled = filled;
    if (filled != getToFilled)
        filled = Custom.LerpAndTick(filled, getToFilled, 0.03f, fillSpeed);
    else if (blinkCounter > 0)
        blinkCounter--;
    else if (Random.value < 1f/60f) {          // ≈ 1.5 次/秒
        getToFilled = Random.value;
        fillSpeed   = 1f / Mathf.Lerp(2f, 80f, Random.value);
    }
}

float Fill(float t) {
    if (blinkCounter % 4 > 1 && filled == getToFilled) return 0f;   // 2 帧灭 / 2 帧亮
    return Mathf.Lerp(lastFilled, filled, t);
}

void SetToMax() {
    getToFilled = 1f;
    fillSpeed   = Mathf.Lerp(fillSpeed, 0.25f, 0.25f);
    blinkCounter = 20;
}
```

- 每个 bit 独立随机呼吸 → **一片此起彼伏的心跳**，非整层同步。
- `fillSpeed` 跨度 1/2 ~ 1/80，慢的 bit 几秒才走完，快的瞬间到位。

### 5.3 整环脉冲

```csharp
if (Random.value < 1f/60f && bits.Length > 0) {
    int r = Random.Range(0, bits.Length);
    foreach (var b in bits[r]) b.SetToMax();
}
```

### 5.4 连线点亮

```csharp
foreach (var c in connections) {
    c.lastLightUp = c.lightUp;
    c.lightUp *= 0.9f;                              // 3~4 tick 衰减
    if (Random.value < connectionsFireChance / 40f && oracle.Consious) {
        c.lightUp = 1f;
        room.PlaySound(SoundID.SS_AI_Halo_Connection_Light_Up, ...);
    }
}
if (Random.value < 1f/60f) connectionsFireChance = Random.value * Random.value * Random.value;
```

- `.ctor` 中 `connectionsFireChance = Random.value^3`
- 三次方 → **大多数时候接近 0（沉默），偶发成串点亮**，这个分布形状是刻意的
- 音效 `SS_AI_Halo_Connection_Light_Up`，音量随 `oracle.noiseSuppress` 衰减

### 5.5 三速缓动 + 随机事件

```csharp
lastExpand = expand; lastPush = push; lastWhite = white;
expand = Custom.LerpAndTick(expand, getToExpand, 0.05f,  0.0125f);
push   = Custom.LerpAndTick(push,   getToPush,   0.02f,  0.025f );
white  = Custom.LerpAndTick(white,  getToWhite,  0.07f,  1f/44f);

bool flag = false;
if (Random.value < 1f/160f) {
    if (Random.value < 1f/8f) { flag = getToWhite < 1f; getToWhite = 1f; }
    else                       getToWhite = 0f;
}
if (Random.value < 1f/160f || flag) {
    if (Random.value < 0.5f && flag)
        getToExpand = Mathf.Lerp(0.8f, 2f, Mathf.Pow(Random.value, 1.5f));
    else
        getToExpand = 1f;
}
if (Random.value < 1f/160f || flag) {
    if (Random.value < 0.5f && flag)
        getToPush = (float)(Random.Range(-1,0) + Random.Range(1,6));  // ∈ {0..4}
    else
        getToPush = 0f;
}
```

**三个易错点（均由 IL 逐条走 opcode 确认，勿按直觉改写）：**

1. **两个块各消耗一次独立的 `Random.value`**，进入块后再消耗一次；**只有 `rnd<0.5 && flag` 才给增益**，其余一切情况都归位到中性值（1 / 0）。写成 `rnd>=0.5` 是取反错误（分布上等价，但语义错）。
2. **`Random.Range(int,int)` 上界不含**（MemberRef 签名 `00 02 08 08 08` = `(int32,int32)->int32`）：`Range(-1,0)` **恒为 -1**，`Range(1,6)` 为 1..5，故 `getToPush ∈ 0..4`、均值 2.0。此处曾被误当作 `{-1,0}`（取值 0..5、均值 2.5），导致 `push` 均值偏高、半径整体偏大，详见第 6 节订正记录。**即便区间退化，两次 `Range` 仍各消耗一个随机数，不可合并成一次。**
3. **`flag` 的语义是"这一 tick 刚发生一次变亮"**，`getToWhite` 平时为 0，故变亮事件时 `flag` 基本恒为真 → 增益事件率 ≈ `1/160 × 1/8 ≈ 1/1280` tick，约 32 秒一次。

由此得到的实际行为：`expand/push` 在绝大多数时间**稳在 1 / 0**，只有偶发事件才短暂抬升。

`Custom.LerpAndTick(cur, target, lerp, tick)`：

```csharp
float r = Lerp(cur, target, lerp);
return r < target ? Mathf.Min(r + tick, target) : Mathf.Max(r - tick, target);
```

`ChangeAllRadi()`（外部触发，`SSOracleBehavior.SlugcatEnterRoomReaction` 调用）：

```csharp
getToExpand = Mathf.Lerp(0.8f, 2f, Mathf.Pow(Random.value, 1.5f));
getToPush   = (float)(Random.Range(-1,0) + Random.Range(1,6));
```

### 5.6 出生点

`.ctor`：`expand = 1; getToExpand = 1;` 其余 `push/white` 均 0；`ringRotations` 全 0。

### 5.7 语音耦合（`OracleGraphics.Update` → `averageVoice`）

```csharp
voice.currentSoundObject.GetSpectrumData(voiceFreqSamples, 0, 5);
averageVoice = sum(samples) / len;
averageVoice = InverseLerp(0f, 0.00014f, averageVoice);     // 归一化到 [0,1]
if (averageVoice > 0.7f && Random.value < averageVoice/14f)
    randomTalkVector = Custom.RNV();
else
    randomTalkVector *= 0.9f;
```

进入 `Radius()` 的 `-0.5 * averageVoice` 项 → 若生效则是说话时光环整体收缩（最大 -0.5 半径单位 = -5px × expand）。

> **已定案：该项实际恒为 0，是死参数。** 紧接上文的同一方法内：

```csharp
if (averageVoice > 0f) {
    for (i = 0; i < voiceFreqSamples.Length; i++) voiceFreqSamples[i] = 0f;
    averageVoice = 0f;                       // ← 用完立刻清零
}
```

> 计算与清零都在 `OracleGraphics.Update` 里完成，而 `Radius` 只在 `Halo.DrawSprites`
> 中被调用；游戏内 Update 先于 DrawSprites，因此绘制时读到的 `averageVoice` 恒为 0。
> → 参考实现固定 `voice = 0` 与原版一致。
>
> 可证伪条件：若游戏内 FP 讲话时能观察到光环随语音收缩，则上述调用顺序假设有误。

---

## 6. 实测稳态分布（`tools/halo2139_sim.py stats`，4 个 seed × 40,000 tick）

| 量 | mean | p05 | p50 | p95 |
|---|---|---|---|---|
| `Radius(0,t)` | 31.2 ~ 32.3 | 30 | **30** | 38.6 ~ 50.0 |
| `Radius(1,t)` | 41.4 ~ 42.5 | 40 | **40** | 51.4 ~ 62.0 |
| `expand` | 1.01 ~ 1.03 | 1.0 | 1.0 | 1.0 ~ 1.2 |
| `push` | 0.05 ~ 0.17 | 0 | **0** | 0 ~ 1.4 |
| `white` | 0.10 ~ 0.17 | 0 | 0 | 1 |
| 同时点亮连线 | 3.1 ~ 3.2 条 / 20 | — | — | — |

外环直径：**p50 80px**，p95 约 100~124px，峰值（事件时）可到 200px。
→ 在 1400×800 房间里，光环是**小尺寸高密度**的细节，不是视觉主体。

> ⚠️ 本表订正过两次，记录在此以免再犯：
> 1. 增益条件曾写成 `rnd>=0.5 && flag`（把 IL 的 `blt` 判反），使 `push` 均值达 1.35、
>    p50=1，半径整体偏大 10px。
> 2. `Random.Range(int,int)` **上界不含**（MemberRef 签名字节 `00 02 08 08 08` =
>    `(int32,int32)->int32`），故 `Range(-1,0)` **恒为 -1**，`Range(1,6)` = 1..5 →
>    `getToPush ∈ 0..4`，均值 2.0。曾误当作 `{-1,0}` 并让上界含 5，使取值变成 0..5、均值 2.5。
>
> 订正后 `push` 有 95% 的时间为 0，环半径回到恒定的 30 / 40。**旧视频
> （`halo2139.mp4` / `_v2` / `_v3`）的环略偏大，以本表为准。**

---

## 7. 未闭合项

1. ~~`averageVoice` 是否真的生效~~ —— **已定案：恒为 0，是死参数**，见 §5.7。
2. **`white=1` 的实心盘**是否符合游戏观感（代码如此，直觉存疑）。
3. **后处理**：`VectorCircle` 自身无 bloom/tint；若游戏内观感更"亮"，来源在房间后期处理链（`DeepProcessing` 等），与本类无关。
4. **`oracle.arm.cornerPositions` 的具体值**：决定 `stuckAt` 的夹取强度，是**唯一仍未
   闭合的几何量**。`tools/halo2139_sim.py` 已将它暴露为 `arm_box` 参数（默认 `None`
   = 不夹），但真实数值取决于 FP 房间内手臂包围盒的实测值，需游戏内测距。
5. ~~bit 长轴朝向~~ —— **已定案：切向**，见 §4.2。渲染器默认
   `--bit-axis tangential`，`radial` 保留为对照开关。
6. ~~`Random.Range` 重载~~ —— **已定案：`Range(int,int)`，上界不含**，见 §6。

---

## 8. 复现工具

**`tools/halo2139_sim.py`** —— 本规格书唯一参考实现（不依赖游戏资源，
2 环 + 100 bit + 20 条贝塞尔连线全部程序化绘制）。

```bash
python3 tools/halo2139_sim.py still --out /tmp/a.png          # 单帧 PNG
python3 tools/halo2139_sim.py still --out /tmp/b.png --zoom 2.2 --ticks 120
python3 tools/halo2139_sim.py video --out /tmp/a.mp4          # 20s @40fps
python3 tools/halo2139_sim.py stats                           # §6 的分布表
```

编写时的三个坑（都已写在代码注释里）：

1. **`bezier3(p0,p1,p2,p3,t)` 必须按 `(a, b, d, c)` 传参** —— `Custom.Bezier`
   的第 3、4 实参权重互换，见 §4.3。
2. **连线的 `th = seg*0.3` 是沿曲线的长度，不是线宽**；线宽是
   `2*Lerp(lastLightUp, lightUp, t) ∈ [0,2]`，见 §4.3。
3. **bit 的 `scaleY=8*Fill` 沿切向**（不是径向）。`rotation = 极角` 让局部 +X
   落在径向，故 scaleY 落在切向；切向最长 8px > 外环弦长 5.76px，满格时
   相邻齿会重叠成连续弧，属于原版行为，见 §4.2。

`seed` 决定一切：同一个 seed + 同一 `warmup` 输出逐字节可复现
（已验证同参数两次 `still` 的 md5 相同），可直接用于 QML 版的逐帧 diff。

历史验证图（一次性产物，未入库）：`gt_full.png` / `gt_pulse.png` /
`gt_zoom.png` / `halo2139_v3.mp4`。

---

## 9. 与实现的对应关系（备忘）

| 原版槽位 | 语义 | 可映射的数据维度（双模式时） |
|---|---|---|
| `Radius(0)/(1)` ← `expand`, `push` | 整体尺度 | 总负载 / 告警级别 |
| `bits[3].Fill` | 100 个独立活跃度 | 三类细粒度指标（CPU 核 / 磁盘 / 网络） |
| `white` | 实心墨盘脉冲 | 二元事件（错误 / 通知） |
| `ringRotations[i]` | 抽搐式角度 | 速率类指标 |
| `connections.lightUp` | 20 条远场连线 | 外部连接 / 请求流量 |
| `averageVoice` | 语音收缩 | 音频输出电平（天然同源） |

---

## 10. KDE 挂件迁移（`contents/ui/halo2139.js`）

实现文件：`contents/ui/halo2139.js`（状态机 + 绘制），由 `contents/ui/main.qml`
驱动。与 §8 的 Python 参考实现**逐函数对应**，两边共享同一套常量。

### 10.1 分层原则

| 层 | 职责 | 是否允许掺数据 |
|---|---|---|
| `step(h)` | IL 状态机原样移植，40 tick/s | **否**。随机数消耗顺序不可调换 |
| `draw(ctx, h, view)` | 绘制 + 数据调制 | **是**。所有物理量映射集中在此 |
| `main.qml` | 轮询 `/proc`、颜色配置、缩放 | — |

因此"还原"与"数据映射"互不污染：`view` 传 `sizeGain=1 / pushAdd=0 /
whiteForce=0 / bitGain=[1,1,1]` 即得到与参考实现同构的结果。

### 10.2 缩放（关键）

所有几何常量用**游戏单位**（原版 1400×800 房间的像素），由调用方给出
`s = 每游戏单位对应多少屏幕像素`：

```
GAME_EXTENT = 57                      // 常态外沿 = 外圈 bit 环 55 + 径向半厚 2
s           = (min(w, h) / 2) / (GAME_EXTENT * inscribe)
```

`inscribe = 1.0` 时常态外沿**正好内接**于组件矩形，与组件像素尺寸无关 ——
这是分辨率无关的，不是硬编码像素。

**已知冲突**：IL 自身有大幅脉冲（`expand` 峰值 2.0、`push` 峰值 5，约每
32 秒一次），峰值半径可达常态的 3.7 倍。组件有边界而游戏房间没有，因此
"内接"只能对某一个状态成立：

- `inscribe = 1.0`（默认）：常态内接，脉冲被 `clip: true` 裁在组件内 —— 观感是光环撞到边界
- `inscribe ≈ 1.35`：连 p95 脉冲也装得下，但常态只占组件 74%
- `inscribe ≈ 3.7`：所有脉冲都不越界，常态仅占 27%（不推荐）

### 10.3 数据槽位映射

每个物理量占用一个**原版本来就存在**的自由度，不新增几何：

| 挂件槽位 | 原版语义 | 物理量 | 范围 | 观感 |
|---|---|---|---|---|
| `sizeGain` | `expand` 缩放 | CPU 占用 | 0.80 → 1.00 | 越忙整体越大 |
| `ring1Thick` | 环 1 的 alpha=3/R | 内存占用 | 3 → 22 游戏单位 | 细环→粗环 |
| `whiteForce` | `white` 实心脉冲 | 温度 | 70°C 起渐入 | 环 0 填成实心墨盘 = 告警 |
| `bitGain[0]` | 内环 10 齿 Fill | 磁盘 I/O | 0.30 → 1.00 | 齿长随负载生长 |
| `bitGain[1]` | 中环 30 齿 Fill | GPU 显存 | 0.30 → 1.00 | 同上 |
| `bitGain[2]` | 外环 60 齿 Fill | 网络吞吐 | 0.30 → 1.00 | 同上 |
| `rotSpeed` | `ringRotations` 进度增量 | 平均负载 | 0.6 → 2.5 | 抽搐更急 |
| 颜色 | 5 个颜色槽 | 各自的 mix | — | 沿用挂件原有配色 |

`sizeGain` 只向下取（≤1.0）是刻意的：常态即为最大，保证数据调制不会
把光环顶出组件边界。

`connections.lightUp`（20 条连线）**状态机保留、不渲染** —— 见 10.4。

### 10.4 为什么连线不渲染

连线的 `stuckAt` 锚点实测半径 p50 = 408、p95 = 505 游戏单位，而光环外沿
只有 57。比值 **≈ 7.2×**。

若光环铺到 400px 组件的 195px 半径，连线需要 1400px 半径 → 组件需
**2800px 见方**；即使 1:1 不放大（光环仅 114px 直径），也需 **816px**。

**结论：在正常尺寸的挂件里，全幅连线在数学上不可能实现。**

处理方式（方案 1，已选定）：`step()` 里照常跑 20 条线的状态机
（`fireChance = rnd³` 的成串触发 + `lightUp *= 0.9` 衰减），结果存于
`h.linkLevel`（0..1 平均亮度）备查，但 `draw()` 不绘制。这样将来若要做
"边界微光"等改编形态，信号源仍在，不需要重写状态机。

### 10.5 移植一致性验证

用 node 执行 `halo2139.js`（剥离 `.pragma library` 后注入 `module.exports`），
跑 20,000 tick 与 Python 参考实现对比：

| 量 | Python | JS |
|---|---|---|
| `Radius(1)` mean / p50 | 42.27 / 40.0 | 42.7 / 40.0 |
| `expand` mean | 1.04 | 1.00 |
| `push` mean / p50 | 0.08 / 0.0 | 0.10 / 0.0 |
| bit 四顶点坐标 | — | 逐点与 `render()` 一致 |

差异仅来自随机序列，无系统性偏移。Qt6 的 `qmllint` 本机未安装，QML 层
未做静态检查，需在 plasmashell 中实机加载确认。
