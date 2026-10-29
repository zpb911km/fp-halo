#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Halo #2139 参考实现（离线渲染器）

雨世界迭代器光环 OracleGraphics.Halo(type #2139) 的逐参数复现。
全部常量来自 Assembly-CSharp.dll 的 IL 反汇编与 VectorCircle.shader 明文，
规格书见 docs/HALO_2139_SPEC.md。

用途：
    * 作为 QML 移植前的"标准答案"，输出静帧/视频供人眼比对
    * 作为移植后的逐帧 diff 基准（同一 seed 应当逐像素可复现）
    * 输出稳态统计，用于 calibrate QML 版的参数分布

不依赖游戏资源：2 环(Futile_White+VectorCircle) + 100 bit(pixel) +
20 条贝塞尔连线(TriangleMesh) 全部由本文件程序化绘制。

用法：
    python3 tools/halo2139_sim.py still --out /tmp/a.png            # 单帧
    python3 tools/halo2139_sim.py video --out /tmp/a.mp4            # 20s 视频
    python3 tools/halo2139_sim.py stats                             # 稳态分布

依赖：Pillow；video 子命令另需 PATH 中有 ffmpeg（缺失则仅保留帧序列）。
"""
from __future__ import annotations

import argparse
import math
import os
import random
import shutil
import subprocess
import sys
import tempfile

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    sys.exit("需要 Pillow: pip install Pillow")


# ---------------------------------------------------------------- 原语
# 全部对应 Custom:: 下的静态方法，命名保持与 IL 一致以便回查。

def L(a, b, t):
    """Custom.Lerp"""
    return a + (b - a) * t


def lat(cur, tgt, lerp, tick):
    """Custom.LerpAndTick：先按固定比例趋近，再按固定步长钳到目标。"""
    r = L(cur, tgt, lerp)
    return min(r + tick, tgt) if r < tgt else max(r - tick, tgt)


def scurve(t, k):
    """Custom.SCurve：0..1 的缓入缓出，k 控制拐点。"""
    t = t * 2.0 - 1.0
    if t < 0:
        t = abs(1.0 + t)
        return 0.5 * ((k * t) / (1.0 + k - t))
    k = -1.0 - k
    return 0.5 + 0.5 * ((k * t) / (k - t + 1.0))


def deg2vec(d):
    """Custom.DegToVec"""
    return (math.cos(math.radians(d)), math.sin(math.radians(d)))


def dirvec(a, b):
    """Custom.DirVec = normalize(b - a)"""
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    return (dx / ln, dy / ln)


def bezier3(p0, p1, p2, p3, t):
    """标准三次贝塞尔。

    注意：Custom.Bezier(a, b, c, d, t) 的**实参顺序**与标准 P0..P3 不同——
    其 IL 展开为 (1-t)^3*a + 3t(1-t)^2*b + 3t^2(1-t)*d + t^3*c，
    即第 3、4 参数权重互换。调用点必须写成 bezier3(a, b, d, c, t)。
    """
    u = 1.0 - t
    return (
        u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
        u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1],
    )


# ---------------------------------------------------------------- 状态

class MemoryBit:
    """bit 环上的一个小刻度。每个个体独立呼吸，互不同步。"""

    def __init__(self):
        self.filled = random.random()
        self.lastFilled = self.filled
        self.getToFilled = self.filled
        self.fillSpeed = 0.0
        self.blinkCounter = 0

    def update(self):
        self.lastFilled = self.filled
        if self.filled != self.getToFilled:
            self.filled = lat(self.filled, self.getToFilled, 0.03, self.fillSpeed)
        elif self.blinkCounter > 0:
            self.blinkCounter -= 1
        elif random.random() < 1 / 60:
            self.getToFilled = random.random()
            self.fillSpeed = 1.0 / L(2.0, 80.0, random.random())

    def set_to_max(self):
        """整环脉冲：打满 + 加速 + 闪 20 帧。"""
        self.getToFilled = 1.0
        self.fillSpeed = L(self.fillSpeed, 0.25, 0.25)
        self.blinkCounter = 20

    def fill(self, t):
        # blinkCounter 的 4 相里只亮 2 帧
        if self.blinkCounter % 4 > 1 and self.filled == self.getToFilled:
            return 0.0
        return L(self.lastFilled, self.filled, t)


class Connection:
    """一条神经连线：锚点在房间中心外 300~500px，终点精确停在 halo 外缘。

    IL 依据——调用方 ``Halo::.ctor``::

        pos = 房间中心 + RNV() * Lerp(300, 500, Random.value)
        new Connection(this, pos)

    构造器 ``Halo.Connection::.ctor(parent, pos)``::

        p = pos
        p.x = Clamp(p.x, arm.cornerPositions[0].x, arm.cornerPositions[1].x)
        p.y = Clamp(p.y, arm.cornerPositions[2].y, arm.cornerPositions[1].y)
        stuckAt = Lerp(pos, p, 0.5)      # 落在手臂包围盒内则原样，否则取中点
        handle  = pos + RNV() * Lerp(400, 700, Random.value)

    注意 handle 的基点是被夹之前的 ``pos``，不是 ``stuckAt``。

    ``arm_box`` 为 None 时不做夹取（等价于假设锚点都落在手臂包围盒内）。原版的
    手臂包围盒由 ``OracleArm::.ctor/Update`` 按关节位置逐帧算出，随手臂动画变化，
    无法只从 Halo 的 IL 复现，因此留作外部参数。

    格式为**两个角点** ``((x0, y0), (x1, y1))``，不是四元组 ``(x0, y0, x1, y1)``。
    夹取不消耗随机数，因此开/关 ``arm_box`` 不改变后续随机流（可逐帧对拍）。
    """

    def __init__(self, cx, cy, arm_box=None):
        a = random.random() * math.tau                     # RNV()：第 1 个随机数
        r = L(300.0, 500.0, random.random())               # 第 2 个
        pos = (cx + math.cos(a) * r, cy + math.sin(a) * r)
        if arm_box is None:
            self.stuck_at = pos
        else:
            (x0, y0), (x1, y1) = arm_box
            clamped = (min(max(pos[0], x0), x1),
                       min(max(pos[1], y0), y1))
            self.stuck_at = (L(pos[0], clamped[0], 0.5),
                             L(pos[1], clamped[1], 0.5))
        ha = random.random() * math.tau                    # RNV()：第 3 个
        hr = L(400.0, 700.0, random.random())              # 第 4 个
        self.handle = (pos[0] + math.cos(ha) * hr,
                       pos[1] + math.sin(ha) * hr)
        self.light_up = 0.0
        self.last_light_up = 0.0


class Halo:
    RING_BITS = (10, 30, 60)

    def __init__(self, cx, cy, arm_box=None):
        self.center = (cx, cy)
        self.connections = [Connection(cx, cy, arm_box) for _ in range(20)]
        self.fire_chance = random.random() ** 3
        self.bits = [[MemoryBit() for _ in range(n)] for n in self.RING_BITS]
        self.rot = [[0.0] * 5 for _ in range(10)]  # cur, last, start, target, progress
        self.expand = 1.0
        self.last_expand = 1.0
        self.get_to_expand = 1.0
        self.push = 0.0
        self.last_push = 0.0
        self.get_to_push = 0.0
        self.white = 0.0
        self.last_white = 0.0
        self.get_to_white = 0.0
        # 未闭合项：SSOracleBehavior 用语音频谱驱动收缩，本文件固定 0。
        self.voice = 0.0

    # ---- 每 tick（40Hz）推进一次
    def update(self):
        for c in self.connections:
            c.last_light_up = c.light_up
            c.light_up *= 0.9                              # 约 1s 衰减完
            if random.random() < self.fire_chance / 40.0:
                c.light_up = 1.0
        if random.random() < 1 / 60:
            self.fire_chance = random.random() ** 3        # 三次方 → 成串触发

        for r in self.rot:                                 # 抽搐式旋转
            r[1] = r[0]
            if r[0] != r[3]:
                r[4] += 1.0 / L(20.0, abs(r[2] - r[3]), 0.5)
                r[0] = L(r[2], r[3], scurve(r[4], 0.5))
                if r[4] > 1.0:
                    r[4], r[2], r[0] = 0.0, r[3], r[3]
            elif random.random() < 1 / 30:
                sign = 1.0 if random.random() < 0.5 else -1.0
                r[3] = r[0] + sign * L(15.0, 150.0, random.random())

        for ring in self.bits:
            for b in ring:
                b.update()
        if random.random() < 1 / 60:
            for b in self.bits[random.randrange(len(self.bits))]:
                b.set_to_max()

        self.last_expand, self.last_push, self.last_white = (
            self.expand, self.push, self.white)
        self.expand = lat(self.expand, self.get_to_expand, 0.05, 0.0125)
        self.push = lat(self.push, self.get_to_push, 0.02, 0.025)
        self.white = lat(self.white, self.get_to_white, 0.07, 1 / 44)

        flag = False
        if random.random() < 1 / 160:
            if random.random() < 1 / 8:
                flag = self.get_to_white < 1.0
                self.get_to_white = 1.0
            else:
                self.get_to_white = 0.0
        # 注意：两个独立条件各消耗一次 Random.value；进入块后再消耗一次，
        # 且只有 "rnd<0.5 且 flag" 才真正给增益，否则一律归位到中性值。
        if random.random() < 1 / 160 or flag:
            if random.random() < 0.5 and flag:
                self.get_to_expand = L(0.8, 2.0, random.random() ** 1.5)
            else:
                self.get_to_expand = 1.0
        if random.random() < 1 / 160 or flag:
            if random.random() < 0.5 and flag:
                # Random.Range(int,int) 上界不含（签名字节 00 02 08 08 08）：
                #   Range(-1, 0) 恒为 -1，Range(1, 6) 为 1..5
                #   → getToPush ∈ 0..4，均值 2
                # 两次调用各消耗一个随机数，故仍写两次 randrange。
                self.get_to_push = float(random.randrange(-1, 0)
                                         + random.randrange(1, 6))
            else:
                self.get_to_push = 0.0

    def radius(self, i, t):
        return ((3.0 + i + L(self.last_push, self.push, t)) - 0.5 * self.voice) \
            * L(self.last_expand, self.expand, t) * 10.0

    def rotation(self, i, t):
        return L(self.rot[i][1], self.rot[i][0], t)


# ---------------------------------------------------------------- 渲染

def render(halo, t, cam, size, zoom, bg=None, ss=3, bit_axis="tangential"):
    """渲染一帧。t ∈ [0,1] 为相邻两 tick 之间的插值系数。"""
    W, H = size
    bg = bg or (lambda p, s: (236, 238, 241))
    img = Image.new("RGB", (W * ss, H * ss), bg((0, 0), size))
    dr = ImageDraw.Draw(img)
    for y in range(H * ss):
        dr.line([(0, y), (W * ss, y)], fill=bg((0, y / ss), size))

    layer = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    dl = ImageDraw.Draw(layer)
    ink = (0, 0, 0, 255)  # 所有精灵的 .color 均为 new Color(0,0,0)

    def P(p):
        return ((p[0] - cam[0]) * zoom * ss + W * ss / 2.0,
                (p[1] - cam[1]) * zoom * ss + H * ss / 2.0)

    # --- 20 条连线（画在环与 bit 之下）
    for c in halo.connections:
        if c.last_light_up <= 0.05 and c.light_up <= 0.05:
            continue
        light = 2.0 * L(c.last_light_up, c.light_up, t)     # 真正的半宽 ∈[0,2]
        dv = dirvec(halo.center, c.stuck_at)
        p2 = (halo.center[0] + dv[0] * 400.0,                # 牵引点
              halo.center[1] + dv[1] * 400.0)
        p3 = (halo.center[0] + dv[0] * halo.radius(2, t),    # 终点 = halo 外缘
              halo.center[1] + dv[1] * halo.radius(2, t))
        p0, p1 = c.stuck_at, c.handle
        prev = p0
        for j in range(20):
            q = bezier3(p0, p1, p2, p3, j / 19.0)
            seg = math.hypot(q[0] - prev[0], q[1] - prev[1])
            if seg < 1e-6:
                prev = q
                continue
            dx, dy = (q[0] - prev[0]) / seg, (q[1] - prev[1]) / seg
            px, py = -dy, dx
            th = seg * 0.3                                   # 沿曲线的长度，不是粗细
            quad = [(q[0] - dx * th - px * light, q[1] - dy * th - py * light),
                    (q[0] - dx * th + px * light, q[1] - dy * th + py * light),
                    (q[0] - px * light, q[1] - py * light),
                    (q[0] + px * light, q[1] + py * light)]
            dl.polygon([P(v) for v in quad], fill=ink)
            prev = q

    # --- 2 个主环（VectorCircle: alpha 被当作内孔半径比例）
    cen = P(halo.center)
    for ring in (0, 1):
        R = halo.radius(ring, t) * zoom * ss
        if R < 1:
            continue
        if ring == 0:  # 常态 3px 细环；white→1 时内孔归零 → 实心墨盘
            a = L(3.0 / max(halo.radius(0, t), 1e-3), 1.0,
                  L(halo.last_white, halo.white, t))
        else:
            a = 3.0 / max(halo.radius(1, t), 1e-3)
        rin = max(0.0, (1.0 - min(max(a, 0.0), 1.0)) * R)
        box = [cen[0] - R, cen[1] - R, cen[0] + R, cen[1] + R]
        if rin <= 0.5:
            dr.ellipse(box, fill=(0, 0, 0))
        else:
            dr.ellipse(box, outline=(0, 0, 0), width=max(1, int(round(R - rin))))

    # --- 100 个 bit。scaleX 沿切向、scaleY 沿径向（精灵 rotation = 该点极角）。
    #     已定案：长边沿【切向】。精灵 rotation = 该点极角，Futile 的 rotation 把
    #     局部 +X 转到极角方向（=径向），于是局部 +Y 落在切向：
    #       scaleX = 4      → 径向厚度
    #       scaleY = 8·Fill → 切向长度（沿环生长）
    #     代价：外环 60 齿弦长仅 5.76px < 8px，满填充时相邻齿会重叠成连续弧；
    #     实际很少同时满格，观感是疏密不一的"齿梳"。--bit-axis radial 留作对照。
    for ri, ring in enumerate(halo.bits):
        n = len(ring)
        rot = halo.rotation(ri, t)
        for j, b in enumerate(ring):
            ang = j * 360.0 / n + rot
            v = deg2vec(ang)
            rr = halo.radius(ri + 0.5, t)
            px, py = P((halo.center[0] + v[0] * rr, halo.center[1] + v[1] * rr))
            grow = 8.0 * b.fill(t)
            if bit_axis == "tangential":
                sx, sy = grow, 4.0     # 默认：长边沿切向（沿环生长）
            else:
                sx, sy = 4.0, grow     # 对照用：长边沿径向
            if grow <= 0.3:
                continue
            ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
            hw, hh = sx * zoom * ss / 2.0, sy * zoom * ss / 2.0
            pts = [(px - dx * sa + dy * ca, py + dx * ca + dy * sa)
                   for dx, dy in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh))]
            dl.polygon(pts, fill=ink)

    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB") \
        .resize(size, Image.LANCZOS)


def room_bg(p, size):
    """伪造房间明度渐变（原版由 Room 的调色板/背景层决定，此处仅作底衬）。"""
    x, y = p
    w, h = size
    v = 1.0 - abs(x - w / 2) / (w * 0.75)
    col = (198 + 32 * v, 203 + 30 * v, 211 + 26 * v)
    k = max(0.0, min(1.0, (abs(x - w / 2) / (w / 2)) * 0.55
                         + (abs(y - h / 2) / (h / 2)) * 0.45))
    f = 1.0 - 0.42 * k * k
    return tuple(int(c * f) for c in col)


# ---------------------------------------------------------------- CLI

def _box_from_cli(v):
    """CLI 的四元组 (x0,y0,x1,y1) → build() 的两角点格式 ((x0,y0),(x1,y1))。"""
    if not v:
        return None
    x0, y0, x1, y1 = v
    return ((x0, y0), (x1, y1))


def build(seed=2139, warmup=3000, cx=700.0, cy=400.0, arm_box=None):
    random.seed(seed)
    halo = Halo(cx, cy, arm_box)
    for _ in range(warmup):   # 跳过冷启动
        halo.update()
    return halo


def cmd_still(a):
    halo = build(a.seed, a.warmup, a.cx, a.cy, _box_from_cli(a.arm_box))
    for _ in range(a.ticks):
        halo.update()
    img = render(halo, 1.0, (a.cx, a.cy), (a.w, a.h), a.zoom, room_bg, a.ss,
                 a.bit_axis)
    img.save(a.out)
    print(f"wrote {a.out}  ({a.w}x{a.h}, zoom={a.zoom}, seed={a.seed}, "
          f"bit_axis={a.bit_axis} "
          f"R0={halo.radius(0, 1.0):.1f} R1={halo.radius(1, 1.0):.1f} "
          f"white={halo.white:.2f} push={halo.push:.2f})")


def cmd_video(a):
    tmp = tempfile.mkdtemp(prefix="halo2139_")
    halo = build(a.seed, a.warmup, a.cx, a.cy, _box_from_cli(a.arm_box))
    step = 40.0 / a.fps                 # 逻辑 40 tick/s，每帧推进多少 tick
    acc = 0.0
    for f in range(a.frames):
        acc += step
        while acc >= 1.0:
            halo.update()
            acc -= 1.0
        img = render(halo, acc, (a.cx, a.cy), (a.w, a.h), a.zoom, room_bg, a.ss,
                     a.bit_axis)
        img.save(os.path.join(tmp, f"f{f:05d}.png"))
    print(f"rendered {a.frames} frames -> {tmp}")

    if not shutil.which("ffmpeg"):
        print("! ffmpeg 缺失，帧序列保留在", tmp)
        return
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(a.fps),
           "-i", os.path.join(tmp, "f%05d.png"), "-c:v", "libx264",
           "-pix_fmt", "yuv420p", "-crf", "20", a.out]
    subprocess.run(cmd, check=True)
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"wrote {a.out}  ({a.frames / a.fps:.1f}s @ {a.fps}fps, {a.w}x{a.h})")


def cmd_stats(a):
    halo = build(a.seed, a.warmup, a.cx, a.cy, _box_from_cli(a.arm_box))
    keys = ("R0", "R1", "expand", "push", "white")
    samples = {k: [] for k in keys}
    lit = 0
    for _ in range(a.ticks):
        halo.update()
        samples["R0"].append(halo.radius(0, 0.0))
        samples["R1"].append(halo.radius(1, 0.0))
        samples["expand"].append(halo.expand)
        samples["push"].append(halo.push)
        samples["white"].append(halo.white)
        lit += sum(1 for c in halo.connections if c.light_up > 0.05)

    def q(v, p):
        s = sorted(v)
        return s[min(len(s) - 1, int(p * len(s)))]

    print(f"seed={a.seed} warmup={a.warmup} ticks={a.ticks}")
    print(f"{'量':>8} {'mean':>8} {'p05':>7} {'p50':>7} {'p95':>7}")
    for k in keys:
        v = samples[k]
        print(f"{k:>8} {sum(v) / len(v):8.2f} {q(v, .05):7.1f} "
              f"{q(v, .50):7.1f} {q(v, .95):7.1f}")
    print(f"平均同时点亮连线: {lit / a.ticks:.2f} / 20")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Halo #2139 参考实现")
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(p):
        p.add_argument("--seed", type=int, default=2139)
        p.add_argument("--warmup", type=int, default=3000, help="预热 tick 数")
        p.add_argument("--cx", type=float, default=700.0, help="光环中心 x")
        p.add_argument("--cy", type=float, default=400.0, help="光环中心 y")
        p.add_argument("--w", type=int, default=1280)
        p.add_argument("--h", type=int, default=720)
        p.add_argument("--zoom", type=float, default=1.0)
        p.add_argument("--ss", type=int, default=3, help="超采样倍率")
        p.add_argument("--bit-axis", dest="bit_axis", default="tangential",
                       choices=("radial", "tangential"),
                       help="bit 长边取向：tangential=8px 沿切向(默认,已定案) / "
                            "radial=8px 沿半径(对照用)")
        p.add_argument("--arm-box", dest="arm_box", type=float, nargs=4,
                       default=None, metavar=("X0", "Y0", "X1", "Y1"),
                       help="手臂包围盒两角点，用于把连线锚点夹回盒内（缺省不夹取，"
                            "见 SPEC 4.3.1 的强度实测表）")

    p = sub.add_parser("still", help="输出单帧 PNG")
    common(p)
    p.add_argument("--out", default="halo2139.png")
    p.add_argument("--ticks", type=int, default=0, help="预热后再推进多少 tick")
    p.set_defaults(func=cmd_still)

    p = sub.add_parser("video", help="输出视频")
    common(p)
    p.add_argument("--out", default="halo2139.mp4")
    p.add_argument("--fps", type=int, default=40)
    p.add_argument("--frames", type=int, default=800)
    p.set_defaults(func=cmd_video)

    p = sub.add_parser("stats", help="输出稳态分布")
    p.add_argument("--seed", type=int, default=2139)
    p.add_argument("--warmup", type=int, default=3000)
    p.add_argument("--ticks", type=int, default=20000)
    p.add_argument("--arm-box", dest="arm_box", type=float, nargs=4,
                   default=None, metavar=("X0", "Y0", "X1", "Y1"),
                   help="手臂包围盒两角点（缺省不夹取，见 SPEC 4.3.1）")
    p.add_argument("--cx", type=float, default=700.0)
    p.add_argument("--cy", type=float, default=400.0)
    p.set_defaults(func=cmd_stats)

    a = ap.parse_args(argv)
    a.func(a)


if __name__ == "__main__":
    main()
