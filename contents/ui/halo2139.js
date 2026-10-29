.pragma library

// ================================================================
// Halo #2139 —— 雨世界迭代器光环（OracleGraphics.Halo）参考实现
//
// 与 tools/halo2139_sim.py 逐函数对应，常量同源：全部来自
// Assembly-CSharp.dll 的 IL 反汇编 + VectorCircle.shader 明文。
// 规格书：docs/HALO_2139_SPEC.md
//
// 两条设计原则（不要打破，否则无法与参考实现做逐帧回归）：
//   1. step()  = IL 状态机的原样移植，40 tick/s，不掺任何数据逻辑
//   2. draw()  = 唯一接受「数据调制」的地方（尺寸/活跃度/告警）
//
// 单位约定：所有几何常量用「游戏单位」（原版 1400x800 房间的像素），
// 由调用方提供 s = 每游戏单位对应多少屏幕像素。这样组件缩放与还原解耦。
// ================================================================

var TICK_HZ     = 40;
var RING_BITS   = [10, 30, 60];
// 常态外沿（游戏单位）：外圈 bit 环半径 5.5*10 = 55，加径向半厚 2 = 57
var GAME_EXTENT = 57.0;
var DEG         = Math.PI / 180;
var TAU         = Math.PI * 2;

// ---------------------------------------------------------------- 原语
// 对应 Custom:: 下的静态方法，命名与 IL 一致以便回查。

function Lerp(a, b, t) { return a + (b - a) * t; }

// Custom.LerpAndTick：先按固定比例趋近，再按固定步长钳到目标
function lat(cur, tgt, lerp, tick) {
    var r = Lerp(cur, tgt, lerp);
    return r < tgt ? Math.min(r + tick, tgt) : Math.max(r - tick, tgt);
}

// Custom.SCurve：0..1 缓入缓出，k 控制拐点
function scurve(t, k) {
    t = t * 2 - 1;
    if (t < 0) {
        t = Math.abs(1 + t);
        return 0.5 * ((k * t) / (1 + k - t));
    }
    k = -1 - k;
    return 0.5 + 0.5 * ((k * t) / (k - t + 1));
}

function deg2vec(d) {
    var r = d * DEG;
    return [Math.cos(r), Math.sin(r)];
}

// ---------------------------------------------------------------- bit
// 环上的一个小刻度。每个个体独立呼吸，互不同步 —— 这是该光环的signature。

function mkBit() {
    var f = Math.random();
    return {
        filled:       f,
        lastFilled:   f,
        getToFilled:  f,
        fillSpeed:    0,
        blinkCounter: 0
    };
}

function updateBit(b) {
    b.lastFilled = b.filled;
    if (b.filled !== b.getToFilled) {
        b.filled = lat(b.filled, b.getToFilled, 0.03, b.fillSpeed);
    } else if (b.blinkCounter > 0) {
        b.blinkCounter -= 1;
    } else if (Math.random() < 1 / 60) {
        b.getToFilled = Math.random();
        b.fillSpeed   = 1 / Lerp(2, 80, Math.random());
    }
}

// 整环脉冲：打满 + 加速 + 闪 20 帧
function setBitMax(b) {
    b.getToFilled  = 1;
    b.fillSpeed    = Lerp(b.fillSpeed, 0.25, 0.25);
    b.blinkCounter = 20;
}

// blinkCounter 的 4 相里只亮 2 帧
function bitFill(b, t) {
    if (b.blinkCounter % 4 > 1 && b.filled === b.getToFilled)
        return 0;
    return Lerp(b.lastFilled, b.filled, t);
}

// ---------------------------------------------------------------- 状态

function create() {
    var h = {};

    h.bits = [];
    for (var i = 0; i < RING_BITS.length; i++) {
        var ring = [];
        for (var j = 0; j < RING_BITS[i]; j++) ring.push(mkBit());
        h.bits.push(ring);
    }

    // [cur, last, start, target, progress]
    h.rot = [];
    for (i = 0; i < 10; i++) h.rot.push([0, 0, 0, 0, 0]);

    h.expand = 1; h.lastExpand = 1; h.getToExpand = 1;
    h.push   = 0; h.lastPush   = 0; h.getToPush   = 0;
    h.white  = 0; h.lastWhite  = 0; h.getToWhite  = 0;

    // 未闭合项：SSOracleBehavior 用语音频谱收缩；此处固定 0
    h.voice = 0;

    // 方案 1：连线状态机保留、不渲染。用于将来做边界微光或外部指示。
    h.fireChance = Math.pow(Math.random(), 3);
    h.links = [];
    for (i = 0; i < 20; i++) h.links.push({ lightUp: 0, lastLightUp: 0 });
    h.linkLevel = 0;            // 20 条线的平均亮度，供外部读取

    h.rotSpeed = 1;             // 数据调制：旋转急促度（1 = 原版）

    return h;
}

// ---------------------------------------------------------------- 每 tick 推进
// 严格按 IL 顺序执行；顺序影响随机数消耗，不可调换。

function step(h) {
    // ---- 20 条神经连线（不渲染，只跑状态机）
    var sum = 0;
    for (var i = 0; i < h.links.length; i++) {
        var c = h.links[i];
        c.lastLightUp = c.lightUp;
        c.lightUp *= 0.9;                                   // 约 1s 衰减完
        if (Math.random() < h.fireChance / 40) c.lightUp = 1;
        sum += c.lightUp;
    }
    h.linkLevel = sum / h.links.length;
    if (Math.random() < 1 / 60) h.fireChance = Math.pow(Math.random(), 3);  // 三次方 → 成串触发

    // ---- 抽搐式旋转：到达后重抽 ±[15,150]°，SCurve 趋近
    for (i = 0; i < h.rot.length; i++) {
        var r = h.rot[i];
        r[1] = r[0];
        if (r[0] !== r[3]) {
            r[4] += (1 / Lerp(20, Math.abs(r[2] - r[3]), 0.5)) * h.rotSpeed;
            r[0] = Lerp(r[2], r[3], scurve(r[4], 0.5));
            if (r[4] > 1) { r[4] = 0; r[2] = r[3]; r[0] = r[3]; }
        } else if (Math.random() < 1 / 30) {
            var sign = Math.random() < 0.5 ? 1 : -1;
            r[3] = r[0] + sign * Lerp(15, 150, Math.random());
        }
    }

    // ---- 100 个 bit 各自呼吸
    for (i = 0; i < h.bits.length; i++)
        for (var j = 0; j < h.bits[i].length; j++) updateBit(h.bits[i][j]);

    // ---- 每帧 1/60 概率挑一整环打满
    if (Math.random() < 1 / 60) {
        var ring = h.bits[Math.floor(Math.random() * h.bits.length)];
        for (j = 0; j < ring.length; j++) setBitMax(ring[j]);
    }

    // ---- 三个平滑量，节拍各不相同
    h.lastExpand = h.expand; h.lastPush = h.push; h.lastWhite = h.white;
    h.expand = lat(h.expand, h.getToExpand, 0.05, 0.0125);
    h.push   = lat(h.push,   h.getToPush,   0.02, 0.025);
    h.white  = lat(h.white,  h.getToWhite,  0.07, 1 / 44);

    // ---- 事件源：1/160 帧一次；其中 1/8 是"亮起"（白盘），否则归零
    var flag = false;
    if (Math.random() < 1 / 160) {
        if (Math.random() < 1 / 8) {
            flag = h.getToWhite < 1;
            h.getToWhite = 1;
        } else {
            h.getToWhite = 0;
        }
    }
    if (Math.random() < 1 / 160 || flag) {
        if (Math.random() < 0.5 && flag) h.getToExpand = Lerp(0.8, 2.0, Math.pow(Math.random(), 1.5));
        else                             h.getToExpand = 1;
    }
    if (Math.random() < 1 / 160 || flag) {
        if (Math.random() < 0.5 && flag)
            // Random.Range(int,int) 上界不含（签名字节 00 02 08 08 08）：
            //   Range(-1, 0) 恒为 -1，Range(1, 6) 为 1..5 → getToPush ∈ 0..4
            // Math.random()*1 取整恒为 0，只为保持"两次 Range 各消耗一次随机数"。
            h.getToPush = (Math.floor(Math.random() * 1) - 1)
                        + (Math.floor(Math.random() * 5) + 1);
        else
            h.getToPush = 0;
    }
}

// ---------------------------------------------------------------- 几何

// Radius(i,t) = ((3 + i + push) - 0.5*voice) * expand * 10
// pushAdd / sizeGain 是数据调制（见 draw），传 0 / 1 即为原版
function radius(h, i, t, pushAdd, sizeGain) {
    pushAdd  = pushAdd  || 0;
    sizeGain = sizeGain || 1;
    return ((3 + i + Lerp(h.lastPush, h.push, t) + pushAdd) - 0.5 * h.voice)
         * Lerp(h.lastExpand, h.expand, t) * sizeGain * 10;
}

function rotation(h, i, t) { return Lerp(h.rot[i][1], h.rot[i][0], t); }

// ---------------------------------------------------------------- 绘制
//
// view = {
//     cx, cy,                       // 中心（屏幕像素）
//     s,                            // 每游戏单位对应多少屏幕像素
//     ring0, ring1, bits: [c,c,c],  // 颜色（CSS 字符串）
//     sizeGain,                     // ← CPU：整体尺寸倍率（1 = 原版）
//     pushAdd,                      // ← 内存：整体外扩（0 = 原版）
//     whiteForce,                   // ← 温度：0..1 强制环 0 变实心墨盘
//     bitGain: [g,g,g],             // ← 磁盘/GPU/网络：各 bit 环活跃度
//     alpha
// }
//
// 注意 VectorCircle 的语义：alpha 被当作【内孔半径占外半径的比例】，
// 环宽 = alpha * R。所以白色（white）字段名不副实——它是"填成实心"。

function draw(ctx, h, view) {
    var t  = 1;
    var s  = view.s;
    var cx = view.cx;
    var cy = view.cy;
    var pushAdd  = view.pushAdd  || 0;
    var sizeGain = view.sizeGain || 1;
    var whiteF   = view.whiteForce || 0;
    var bitGain  = view.bitGain || [1, 1, 1];
    var alpha    = view.alpha === undefined ? 1 : view.alpha;

    ctx.globalAlpha = Math.max(0, Math.min(1, alpha));

    // ---- 2 个主环
    // 环 0：常态 3px 细环；white → 1 时内孔归零，整盘填实
    var r0 = radius(h, 0, t, pushAdd, sizeGain);
    var a0 = Lerp(3 / Math.max(r0, 0.001), 1, Math.max(Lerp(h.lastWhite, h.white, t), whiteF));
    drawRing(ctx, cx, cy, r0 * s, a0 * r0 * s, view.ring0);

    // 环 1：恒定 3px（原版），可用数据加粗到最多 55% 半径（仍不是实心）
    var r1 = radius(h, 1, t, pushAdd, sizeGain);
    var th1 = view.ring1Thick === undefined ? 3 : Math.min(view.ring1Thick, r1 * 0.55);
    drawRing(ctx, cx, cy, r1 * s, th1 * s, view.ring1);

    // ---- 100 个 bit（画在环之上）
    // 长边沿【切向】（已定案）：精灵 rotation = 该点极角，局部 +Y 落在切向
    //   tangential = 8 * Fill    → 沿环生长
    //   radial     = 4           → 径向厚度
    for (var ri = 0; ri < h.bits.length; ri++) {
        var ring = h.bits[ri];
        var n    = ring.length;
        var rot  = rotation(h, ri, t);
        var rr   = radius(h, ri + 0.5, t, pushAdd, sizeGain);
        var col  = (view.bits && view.bits[ri]) || view.ring1;

        ctx.fillStyle = col;
        ctx.beginPath();
        var drew = false;

        for (var j = 0; j < n; j++) {
            var grow = bitFill(ring[j], t) * bitGain[ri];
            if (grow <= 0.0375) continue;    // fill <= 0.3/8 → 不画（原版同样跳过）
            var halfT = 4 * grow * s;        // 切向半长 = 8*Fill/2
            var halfR = 2 * s;               // 径向半厚 = 4/2
            var ang   = j * 360 / n + rot;
            var v     = deg2vec(ang);
            var px    = cx + v[0] * rr * s;
            var py    = cy + v[1] * rr * s;
            var ca    = v[0], sa = v[1];     // 径向单位向量 = (ca, sa)
            // 切向 / 径向两组基向量，本地 dx 沿切向、dy 沿径向
            var tX = -sa, tY = ca;           // 切向
            var rX =  ca, rY = sa;           // 径向
            // 4 个顶点：(±halfT, ±halfR)
            var ax = px - tX * halfT - rX * halfR, ay = py - tY * halfT - rY * halfR;
            var bx = px + tX * halfT - rX * halfR, by = py + tY * halfT - rY * halfR;
            var dx2 = px + tX * halfT + rX * halfR, dy2 = py + tY * halfT + rY * halfR;
            var ex = px - tX * halfT + rX * halfR, ey = py - tY * halfT + rY * halfR;
            ctx.moveTo(ax, ay);
            ctx.lineTo(bx, by);
            ctx.lineTo(dx2, dy2);
            ctx.lineTo(ex, ey);
            ctx.closePath();
            drew = true;
        }
        if (drew) ctx.fill();
    }

    ctx.globalAlpha = 1;
}

// 用 Canvas 的 arc 画一圈；thick >= R 时退化为实心圆
function drawRing(ctx, cx, cy, R, thick, color) {
    if (R < 0.5) return;
    if (thick >= R) {
        ctx.beginPath();
        ctx.arc(cx, cy, R, 0, TAU);
        ctx.fillStyle = color;
        ctx.fill();
    } else {
        ctx.beginPath();
        ctx.arc(cx, cy, R - thick / 2, 0, TAU);
        ctx.strokeStyle = color;
        ctx.lineWidth   = thick;
        ctx.stroke();
    }
}
