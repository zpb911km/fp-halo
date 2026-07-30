// ================================================================
// HALO — 液压联动光环 | KDE Plasma 5 Widget
// version v0.9
// ================================================================

import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0

// ================================================================
// 1. ROOT — Plasmoid shell
// ================================================================

Item {
    id: root
    width:  400
    height: 400

    Plasmoid.backgroundHints:        PlasmaCore.Types.NoBackground
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    // ============================================================
    // 2. fullRepresentation — main widget surface
    // ============================================================

    Plasmoid.fullRepresentation: Item {
        id: w
        anchors.fill: parent

        // ─── 2a. layout constants ───────────────────────────────
        readonly property real sf:        Math.min(width, height) / 400
        readonly property real gap:       3
        readonly property real minThick:  1.5
        readonly property real maxR:      195
        readonly property string version: "v0.9"

        // ─── 2b. per-layer animation config ─────────────────────
        readonly property var layerConf: [
            //   dashAngles (deg)                 flashMs  rotate  rotMs
            {  dashAngles: [],                        fMs: 3000,  rot: false, rotMs: 0 },
            {  dashAngles: [1.1, 18.9],               fMs: 5000,  rot: true,  rotMs: 23000 },
            {  dashAngles: [],                        fMs: 7000,  rot: false, rotMs: 0 },
            {  dashAngles: [1, 2.6, 1, 19.4],         fMs: 11000, rot: true,  rotMs: 29000 },
            {  dashAngles: [0.65, 4.35],              fMs: 13000, rot: true,  rotMs: 31000 },
        ]

        readonly property var layerPulse: [
            //   innerInterval  outerInterval  transitionDur
            {  iInt: 2200,  oInt: 3100,  tDur: 600 },
            {  iInt: 2800,  oInt: 3700,  tDur: 500 },
            {  iInt: 3400,  oInt: 4300,  tDur: 450 },
            {  iInt: 4100,  oInt: 5200,  tDur: 550 },
            {  iInt: 4800,  oInt: 6100,  tDur: 500 },
        ]

        readonly property var flickerKfs: [
            [ [0,0.4],[0.42,0.4],[0.43,0],[0.44,0.4],[0.45,0.1],[0.46,0.4],
              [0.78,0.4],[0.79,0],[0.80,0.4],[1,0.4] ],
            [ [0,0.8],[0.30,0.8],[0.31,0],[0.32,0.8],[0.33,0.1],[0.34,0.8],
              [0.65,0.8],[0.66,0],[0.67,0.8],[1,0.8] ],
            [ [0,0.6],[0.53,0.6],[0.54,0],[0.55,0.6],[0.89,0.6],[0.90,0.1],[0.91,0.6],[1,0.6] ],
            [ [0,0.8],[0.23,0.8],[0.24,0],[0.25,0.8],[0.26,0.1],[0.27,0.8],
              [0.61,0.8],[0.62,0],[0.63,0.8],[1,0.8] ],
            [ [0,0.8],[0.17,0.8],[0.18,0],[0.19,0.8],[0.47,0.8],[0.48,0.1],[0.49,0.8],
              [0.73,0.8],[0.74,0],[0.75,0.8],[1,0.8] ],
        ]

        readonly property var rotKfs: [
            [],
            [ [0,0],[0.10,0],[0.20,60],[0.30,60],

              [0.45,120],[0.60,120],[0.75,240],[0.90,240],[1,360] ],
            [],
            [ [0,0],[0.15,0],[0.25,-90],[0.40,-90],
              [0.55,-180],[0.70,-180],[0.85,-270],[0.95,-270],[1,-360] ],
            [ [0,0],[0.05,0],[0.15,45],[0.25,45],[0.35,90],[0.50,90],
              [0.65,180],[0.80,180],[0.90,270],[0.95,270],[1,360] ],
        ]

        readonly property var initBounds: [
            { i:20,  o:80  },
            { i:115, o:125 },
            { i:136, o:138 },
            { i:150, o:162 },
            { i:175, o:185 },
        ]

        // ─── 2c. color config (persistent) ──────────────────────
        readonly property var defaultColors: [
            "#8fb3a6", "#cfe7df", "#bfe0d6", "#d6ece4", "#c4e0d8"
        ]

        property string _c0: defaultColors[0]
        property string _c1: defaultColors[1]
        property string _c2: defaultColors[2]
        property string _c3: defaultColors[3]
        property string _c4: defaultColors[4]

        function getColor(i) {
            return i === 0 ? _c0 : i === 1 ? _c1 : i === 2 ? _c2 : i === 3 ? _c3 : _c4;
        }

        function syncColors() {
            var v;
            v = Plasmoid.configuration.color0; _c0 = (v && v.length) ? v : defaultColors[0];
            v = Plasmoid.configuration.color1; _c1 = (v && v.length) ? v : defaultColors[1];
            v = Plasmoid.configuration.color2; _c2 = (v && v.length) ? v : defaultColors[2];
            v = Plasmoid.configuration.color3; _c3 = (v && v.length) ? v : defaultColors[3];
            v = Plasmoid.configuration.color4; _c4 = (v && v.length) ? v : defaultColors[4];
        }

        function setColor(i, hex) {
            Plasmoid.configuration["color" + i] = hex;
            if      (i === 0) _c0 = hex;
            else if (i === 1) _c1 = hex;
            else if (i === 2) _c2 = hex;
            else if (i === 3) _c3 = hex;
            else if (i === 4) _c4 = hex;
        }

        // ─── 2d. animation state ────────────────────────────────
        property var  st:       []
        property var  t0:       0
        property bool stReady:  false

        // ─── 2e. color helpers (hex with optional alpha) ────────
        function parseColor(hex) {
            hex = hex.replace('#', '');
            var r = parseInt(hex.substr(0, 2), 16);
            var g = parseInt(hex.substr(2, 2), 16);
            var b = parseInt(hex.substr(4, 2), 16);
            var a = hex.length >= 8 ? parseInt(hex.substr(6, 2), 16) / 255 : 1.0;
            return Qt.rgba(r / 255, g / 255, b / 255, a);
        }

        // ─── 2f. animation math functions ───────────────────────

        /* cubic‑bezier solver (0,0)–(0.4,0.2)–(1,1) */
        function cb(t) {
            var bx = 0.4, by = 0.2, g = t;
            for (var i = 0; i < 8; i++) {
                var x  = 3*bx*g*(1-g)*(1-g) + 3*by*g*g*(1-g) + g*g*g - t;
                var dx = 3*bx*(1-g)*(1-g) - 6*bx*g*(1-g) + 3*by*g*(2-3*g) + 3*g*g;
                if (Math.abs(x) < 1e-6) break;
                g -= x / dx; g = Math.max(0, Math.min(1, g));
            }
            return 3*0*g*(1-g)*(1-g) + 3*1*g*g*(1-g) + g*g*g;
        }

        /* linear eval of keyframe table */
        function ev(k, p) {
            if (p <= k[0][0]) return k[0][1];
            if (p >= k[k.length-1][0]) return k[k.length-1][1];
            for (var i = 0; i < k.length-1; i++) {
                if (p >= k[i][0] && p < k[i+1][0]) {
                    var seg = (p - k[i][0]) / (k[i+1][0] - k[i][0]);
                    return k[i][1] + (k[i+1][1] - k[i][1]) * seg;
                }
            }
            return k[0][1];
        }

        /* bezier‑eased eval of rotation keyframes */
        function evr(k, p) {
            if (p <= k[0][0]) return k[0][1];
            if (p >= k[k.length-1][0]) return k[k.length-1][1];
            for (var i = 0; i < k.length-1; i++) {
                if (p >= k[i][0] && p < k[i+1][0]) {
                    var seg = (p - k[i][0]) / (k[i+1][0] - k[i][0]);
                    return k[i][1] + (k[i+1][1] - k[i][1]) * cb(seg);
                }
            }
            return k[0][1];
        }

        /* ease‑out cubic */
        function eoc(t) { return 1 - Math.pow(1 - t, 3); }

        /* next pulse time with jitter */
        function npt(a) { return a * (0.3 + Math.random() * 2.2); }

        /* update a single channel (inner/outer) */
        function uc(ch, now, li, ct) {
            if (now >= ch.np) {
                ch.f = ch.c;
                var b = [];
                for (var bi = 0; bi < st.length; bi++)
                    b.push({ i: st[bi].ii.c, o: st[bi].oo.c });

                var mn, mx;
                if (ct === 'i') {
                    mn = (li === 0) ? 0 : b[li-1].o + gap;
                    mx = Math.min(b[li].o - minThick,
                                  (li === 4) ? maxR - minThick
                                             : b[li+1].i - gap - minThick);
                } else {
                    mn = b[li].i + minThick;
                    mx = (li === 4) ? maxR : b[li+1].i - gap;
                }
                if (mn > mx) { ch.np = now + npt(ch.iv); return; }
                ch.t  = mn + Math.random() * (mx - mn);
                ch.st = now;
                ch.d  = ch.td * (0.6 + Math.random() * 0.8);
                ch.np = now + ch.d + npt(ch.iv);
            }
            if (now < ch.st + ch.d) {
                var pr = (now - ch.st) / ch.d;
                ch.c = ch.f + (ch.t - ch.f) * eoc(Math.min(pr, 1));
            } else {
                ch.c = ch.t;
            }
        }

        /* enforce boundary constraints (iterative) */
        function enf() {
            for (var it = 0; it < 3; it++) {
                for (var i = 0; i < st.length; i++) {
                    if (i === 0)
                        st[i].ii.c = Math.max(0, st[i].ii.c);
                    else
                        st[i].ii.c = Math.max(st[i-1].oo.c + gap, st[i].ii.c);

                    if (i === st.length-1)
                        st[i].oo.c = Math.min(maxR, st[i].oo.c);
                    else
                        st[i].oo.c = Math.min(st[i+1].ii.c - gap, st[i].oo.c);

                    if (st[i].oo.c < st[i].ii.c + minThick) {
                        if (i === st.length-1 ||
                            st[i].oo.c + minThick <= st[i+1].ii.c - gap)
                            st[i].oo.c = st[i].ii.c + minThick;
                        else
                            st[i].ii.c = st[i].oo.c - minThick;
                    }
                }
            }
        }

        /* initialise all channels */
        function initState() {
            var n = Date.now();
            t0 = n;
            var s = [];
            for (var i = 0; i < 5; i++) {
                var p = layerPulse[i];
                s.push({
                    ii: {
                        c:  initBounds[i].i, t: initBounds[i].i, f: initBounds[i].i,
                        st: 0, d: 600,
                        np: n + Math.random() * p.iInt,
                        iv: p.iInt, td: p.tDur
                    },
                    oo: {
                        c:  initBounds[i].o, t: initBounds[i].o, f: initBounds[i].o,
                        st: 0, d: 600,
                        np: n + Math.random() * p.oInt,
                        iv: p.oInt, td: p.tDur
                    },
                });
            }
            st = s;
            stReady = true;
        }

        /* manual arc drawer (bypass Qt arc() undersampling for small arcs) */
        function arcAt(ctx, cx, cy, r, sa, ea) {
            var span = ea - sa;
            var n = Math.max(4, Math.round(span * r * 0.5));
            var stp = span / n;
            for (var j = 0; j <= n; j++) {
                var a = sa + j * stp;
                if (j === 0)
                    ctx.moveTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
                else
                    ctx.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
            }
        }

        // ─── 2g. Canvas renderer ────────────────────────────────
        Canvas {
            id: cv
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!stReady || st.length === 0) return;

                var el   = Date.now() - t0;
                var s    = w.sf;
                var cx   = width  / 2;
                var cy   = height / 2;

                for (var i = 0; i < 5; i++) {
                    var ci = st[i].ii.c * s;
                    var co = st[i].oo.c * s;
                    var r  = (ci + co) / 2;
                    var sw = Math.max(co - ci, 0.1);

                    ctx.save();

                    // rotation transform
                    if (layerConf[i].rot) {
                        var a = evr(rotKfs[i],
                                    (el % layerConf[i].rotMs) / layerConf[i].rotMs);
                        ctx.translate(cx, cy);
                        ctx.rotate(a * Math.PI / 180);
                        ctx.translate(-cx, -cy);
                    }

                    // colour & opacity
                    ctx.strokeStyle = parseColor(getColor(i));
                    ctx.lineWidth   = sw;
                    ctx.globalAlpha = ev(flickerKfs[i],
                                         (el % layerConf[i].fMs) / layerConf[i].fMs);

                    // draw
                    var da = layerConf[i].dashAngles;
                    if (da.length > 0) {
                        var cycleTotal = 0;
                        for (var d = 0; d < da.length; d++) cycleTotal += da[d];
                        var numTeeth = Math.round(360 / cycleTotal);
                        ctx.beginPath();
                        for (var k = 0; k < numTeeth; k++) {
                            var ang = k * cycleTotal;
                            for (var seg = 0; seg < da.length; seg++) {
                                if (seg % 2 === 0) {
                                    var sr = ang * Math.PI / 180;
                                    var er = (ang + da[seg]) * Math.PI / 180;
                                    arcAt(ctx, cx, cy, r, sr, er);
                                }
                                ang += da[seg];
                            }
                        }
                    } else {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    }
                    ctx.stroke();
                    ctx.restore();
                }
            }
        }

        // ─── 2h. version badge ──────────────────────────────────
        Text {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.margins: 4
            text:   version
            color:  "#5a7a6e"
            font {
                pixelSize: 10
                family:    "monospace"
            }
            opacity: 0.5
        }

        // ─── 2i. gear button ────────────────────────────────────
        Text {
            id: gearBtn
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            text:   "⚙"
            font.pixelSize: 14
            color:  panel.opened ? "#8fb3a6" : "#4a6a5e"
            opacity: 0.7

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked:  panel.toggle()
                onEntered:  parent.color = "#8fb3a6"
                onExited:   parent.color = panel.opened ? "#8fb3a6" : "#4a6a5e"
            }
        }

        // ─── 2j. colour settings panel ──────────────────────────
        Rectangle {
            id: panel
            anchors.centerIn: parent
            width:  parent.width  - 48
            height: parent.height - 80  // leave room for version + gear
            radius: 8
            color:  Qt.rgba(0.08, 0.08, 0.08, 0.88)
            border {
                width: 1
                color: "#3a5a4e"
            }

            visible: false
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            property bool opened: false

            function toggle() {
                opened = !opened;
                visible = true;
                opacity = opened ? 1 : 0;
                if (opened) forceActiveFocus();
            }

            Keys.onEscapePressed: {
                opened = false;
                opacity = 0;
            }

            MouseArea {
                anchors.fill: parent
                onClicked: forceActiveFocus()
            }

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.85
                spacing: 12

                // title
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:   "调色盘"
                    color:  "#8fb3a6"
                    font {
                        pixelSize: 22
                        bold: true
                    }
                }

                Repeater {
                    model: 5
                    delegate: Row {
                        id: layerRow
                        property int li: index
                        spacing: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 46

                        // layer name
                        Text {
                            width:  64
                            height: parent.height
                            text:   ["光晕","稀疏","环","配对","密集"][layerRow.li]
                            color:  "#ccc"
                            font.pixelSize: 20
                            verticalAlignment: Text.AlignVCenter
                        }

                        // colour preview
                        Rectangle {
                            width:  36
                            height: 36
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            border {
                                width: 1
                                color: "#555"
                            }
                            color: parseColor(getColor(layerRow.li))
                        }

                        // hex input
                        QQC2.TextField {
                            id: hexField
                            width:  140
                            height: 36
                            text:   getColor(layerRow.li)
                            font {
                                pixelSize: 18
                                family:    "monospace"
                            }
                            color: "#ccc"
                            background: Rectangle {
                                color: "#2a2a2a"
                                radius: 3
                                border {
                                    width: 1
                                    color: "#555"
                                }
                            }
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            leftPadding:  8
                            rightPadding: 8
                            validator: RegExpValidator {
                                regExp: /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/
                            }

                            onEditingFinished: {
                                var t = text.trim();
                                if (t.match(/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/))
                                    setColor(layerRow.li, t);
                            }
                            Keys.onReturnPressed:  focus = false
                            Keys.onEnterPressed:   focus = false
                        }
                    }
                }
            }
        }

        // ─── 2k. animation timer ────────────────────────────────
        Timer {
            id: ft
            interval: 16
            repeat:   true
            running:  true

            onTriggered: {
                if (!stReady || st.length === 0) return;
                var now = Date.now();
                for (var i = 0; i < 5; i++) {
                    uc(st[i].ii, now, i, 'i');
                    uc(st[i].oo, now, i, 'o');
                }
                enf();
                cv.requestPaint();
            }
        }

        // ─── 2l. lifecycle ──────────────────────────────────────
        Component.onCompleted: {
            syncColors();
            initState();
            cv.requestPaint();
        }

        onVisibleChanged: {
            if (visible && stReady)
                cv.requestPaint();
        }
    }
}
