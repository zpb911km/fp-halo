---
name: install_to_plasmoid
description: 修改源代码后必须手动复制到系统路径并重启 plasma
type: skill
created: 2026-07-31 00:27
---

源代码在 /media/zpb/data/codes/KDEplugin/fp-halo/src/contents/ui/ 下修改后，必须：
1. cp 到 ~/.local/share/plasma/plasmoids/org.zpb.halo/contents/ui/
2. 重启 plasmashell (kquitapp5 + kstart5)
否则看到的永远是旧版。已封装成 tool: fp_install_to_kde
