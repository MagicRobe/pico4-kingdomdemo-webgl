# PICO4 王国 — WebGL 网页演示

剑与弩双武器 · 波次防守 · 天赋成长 —— 一款 VR 王国防守游戏的浏览器演示版（去 XR）。

## 试玩

- 展示页：`index.html`
- 试玩入口：`webgl/index.html`（Unity WebGL 播放器）
- 建议桌面浏览器（Chrome / Edge），键盘 + 鼠标操作

## 操作

| 键 | 功能 |
|---|---|
| WASD | 移动 |
| 鼠标 | 旋转视角 |
| 左键 / 空格 | 攻击 |
| 鼠标右键 | 举盾格挡 |
| Shift | 切换武器 |
| Ctrl | 切换盾牌 |

## 技术

- Unity 2022.3 WebGL 构建，Brotli 压缩 + Decompression Fallback（loader 内嵌解压，GitHub Pages 可直接运行）
- `webgl/Build/webgl-build.data.unityweb` 约 97MB（< GitHub 100MB 单文件限制）
- 去 XR 演示：WASD + 鼠标 Fallback 输入，虚拟双手挂载武器盾牌

## 本地运行

```bash
python webgl/webgl_server.py
# 或
python -m http.server 8124
```

然后浏览器打开 `http://localhost:8124/webgl/`
