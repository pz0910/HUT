# HUT - HTML 托管展示平台 产品规格说明 (SPEC)

## 1. 产品概述

| 项目 | 内容 |
|------|------|
| 产品名称 | HUT (HTML Utility Toolbox) |
| 产品定位 | 个人 HTML 作品托管 & 展示平台 |
| 目标用户 | 仓库主人（panze）及通过 GitHub Pages 访问的任何人 |
| 核心价值 | 集中管理散落的 HTML 小工具/可视化/实验，一键上传、分类展示、随处访问 |
| 线上地址 | https://pz0910.github.io/HUT/ |

## 2. 数据模型

### 2.1 manifest.json — 元数据清单

```json
{
  "items": [
    {
      "id": "abc123",
      "name": "SVG 时钟",
      "description": "纯 SVG 实现的模拟时钟，支持自定义颜色",
      "category": "可视化",
      "filename": "svg-clock.html",
      "uploaded_at": "2026-06-10T12:00:00Z",
      "tags": ["svg", "动画"]
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 6位随机字母数字，CLI 自动生成 |
| name | string | 展示名称（必填） |
| description | string | 简要描述，≤100字（必填） |
| category | string | 分类标签（必填，从预设中选或自定义） |
| filename | string | 文件名，存放在 apps/ 目录下（必填） |
| uploaded_at | ISO8601 | 上传时间，CLI 自动生成 |
| tags | string[] | 可选标签，用于辅助搜索 |

### 2.2 预设分类

| 分类 | 说明 |
|------|------|
| 工具 | 实用小工具（计算器、转换器、编辑器等） |
| 可视化 | 数据可视化、图表、动画 |
| 演示 | Demo、原型、概念验证 |
| 实验 | 技术探索、代码片段 |
| 论文 | 论文相关页面 |
| 其他 | 未分类 |

### 2.3 目录结构

```
HUT/
├── index.html              ← 主页（替换 index.md）
├── manifest.json           ← 元数据清单
├── apps/                   ← HTML 文件存放目录
│   ├── abc123.html         ← 上传的 HTML（文件名用 id 命名，防冲突）
│   └── def456.html
├── papers/                 ← 保留不动
├── hut                     ← CLI 脚本（bash，Mac/Linux）
├── hut.bat                 ← CLI 脚本（batch，Windows）
├── _config.yml             ← 保留（GitHub Pages 需要）
└── u-5539719665b18ff1703314.webp  ← 保留
```

## 3. 功能规格

### 3.1 主页（index.html）

#### 3.1.1 搜索功能
- **搜索框**：页面顶部，全宽，自动聚焦
- **搜索范围**：匹配 name、description、tags 字段
- **搜索方式**：实时过滤（输入即搜，无需回车）
- **空状态**：无匹配时显示"没有找到匹配的内容"
- **清除按钮**：搜索框右侧 ✕ 按钮一键清空

#### 3.1.2 分类筛选
- **标签栏**：搜索框下方，横向排列
- **标签项**：「全部」「工具」「可视化」「演示」「实验」「论文」「其他」
- **交互**：单选切换，当前选中高亮
- **与搜索联动**：搜索 + 分类同时生效（AND 关系）

#### 3.1.3 卡片列表
- **布局**：响应式网格（CSS Grid），每行 1-3 张卡片
- **卡片内容**：
  - 标题（name）
  - 描述（description，最多 2 行截断）
  - 分类标签（category，彩色徽章）
  - 上传时间（uploaded_at，相对时间如"3天前"）
- **交互**：
  - 卡片整体可点击，跳转到 `apps/{filename}`
  - hover 效果：微上浮 + 阴影加深
- **排序**：按 uploaded_at 倒序（最新在前）
- **空状态**：无任何 HTML 时显示"还没有上传任何页面，用 CLI 工具上传第一个吧！"

#### 3.1.4 视觉设计
- **主题**：暗色（背景 #0d1117，卡片 #161b22，文字 #e6edf3）
- **参考**：GitHub Trending 风格
- **字体**：系统字体栈，中文优先
- **语言**：界面全中文
- **响应式**：移动端适配（卡片单列）

### 3.2 CLI 工具（hut / hut.bat）

#### 3.2.1 通用规则
- 所有命令修改 manifest.json 后自动 `git add + commit`
- upload/update 命令自动将文件复制到 apps/ 目录
- 文件名使用 id 命名（如 `abc123.html`），避免中文/空格问题
- id 由 CLI 自动生成（6位小写字母+数字）

#### 3.2.2 命令列表

| 命令 | 格式 | 说明 |
|------|------|------|
| `upload` | `hut upload <file> --name "名称" --desc "描述" --cat "分类" [--tags "t1,t2"]` | 上传新 HTML |
| `list` | `hut list [--cat 分类] [--search 关键词]` | 列出所有已上传 HTML |
| `delete` | `hut delete <id>` | 删除指定 HTML（文件+元数据） |
| `update` | `hut update <id> [--name] [--desc] [--cat] [--tags]` | 更新元数据（不替换文件） |
| `replace` | `hut replace <id> <file>` | 替换 HTML 文件（保留元数据） |
| `push` | `hut push` | git push 到远程（触发 GitHub Pages 更新） |
| `help` | `hut help [command]` | 显示帮助信息 |

#### 3.2.3 upload 流程

```
输入: hut upload clock.html --name "SVG时钟" --desc "模拟时钟" --cat "可视化"

1. 校验文件存在且为 .html
2. 生成 id（6位随机）
3. 复制文件 → apps/{id}.html
4. 写入 manifest.json
5. git add apps/{id}.html manifest.json
6. git commit -m "feat: 添加 {name}"
7. 输出: ✅ 已上传: SVG时钟 (id: abc123)
        运行 'hut push' 推送到 GitHub Pages
```

#### 3.2.4 list 输出格式

```
ID      名称          分类      上传时间
abc123  SVG时钟       可视化    3天前
def456  JSON格式化    工具      1周前
```

## 4. 交互流程

```
用户打开 https://pz0910.github.io/HUT/
    │
    ▼
加载 manifest.json（fetch）
    │
    ▼
渲染卡片列表（按时间倒序）
    │
    ├─ 搜索框输入 → 实时过滤 name/desc/tags
    ├─ 点击分类标签 → 按 category 过滤
    └─ 点击卡片 → 跳转 apps/{filename}
```

### CLI 工作流

```
开发者本地操作
    │
    ├─ hut upload xxx.html ...  → 写文件+元数据+git commit
    ├─ hut delete <id>          → 删文件+元数据+git commit
    ├─ hut update <id> ...      → 更新元数据+git commit
    └─ hut push                 → git push → GitHub Pages 自动部署
```

## 5. 技术规格

| 项目 | 选型 | 说明 |
|------|------|------|
| 前端 | 纯 HTML + CSS + JS | 无框架，无构建步骤 |
| 数据存储 | manifest.json | 纯 JSON 文件，前端 fetch 读取 |
| 样式 | 内联 CSS | 单文件，便于管理 |
| CLI (Mac/Linux) | Bash 脚本 | jq 解析 JSON |
| CLI (Windows) | Batch 脚本 | PowerShell 辅助 JSON 操作 |
| 托管 | GitHub Pages | 静态文件直接部署 |
| 兼容性 | 现代浏览器 | Chrome/Firefox/Safari/Edge 最新版 |

### 5.1 性能要求
- 主页加载 < 2s（含 fetch manifest.json）
- 搜索过滤响应 < 100ms
- manifest.json 单文件 < 100KB（支持约 500 个条目）

### 5.2 安全考虑
- 上传的 HTML 通过 `sandbox` 属性限制 iframe 能力（如需预览）
- CLI 不处理敏感数据

## 6. 保留内容

| 内容 | 处理方式 |
|------|----------|
| papers/ 目录 | 完全保留，不修改 |
| _config.yml | 保留（GitHub Pages 需要） |
| u-5539719665b18ff1703314.webp | 保留 |
| index.md | **替换**为 index.html |

## 7. 未来规划（P2/P3）

| 优先级 | 功能 | 说明 |
|--------|------|------|
| P2 | 缩略图预览 | 自动生成 HTML 页面截图作为卡片封面 |
| P2 | 标签云 | 首页展示热门标签，点击筛选 |
| P2 | 访问计数 | 通过 GitHub API 统计页面访问量 |
| P3 | 多文件 HTML 支持 | 支持上传含 assets 的 HTML 项目（zip 解压） |
| P3 | 版本管理 | 同一 HTML 支持多版本 |
| P3 | 暗色/亮色切换 | 用户可切换主题 |
