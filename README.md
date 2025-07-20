# 📱 AI 速记 App 产品文档

---

## 🧭 产品定位

**名称：**
> Voca


**english slogan：** 
> Think less. Remember more



**中文 slogan：** 
> 轻松记，事事记。



**一句话介绍**：

> 支持语音、手写和文字输入的智能速记工具，轻松记录灵感、会议和生活点滴，AI 自动整理总结，让你轻松记，事事记。


**目标用户：**

* 学生：课堂重点、学习笔记、灵感收集
* 知识工作者：会议记录、任务备忘、语音转文字
* 内容创作者：灵感整理、素材存储、创意速写
* 日常用户：日程提醒、想法速记、情绪追踪

---

## 🔧 核心功能模块

### 1. 📥 多模态速记输入

* ✅ 语音速记（自动转文字）
* ✅ 手写笔记（支持画图 / 手写文字）
* ✅ 快速文字输入
* ✅ 附件添加（图片、音频）

### 2. 🤖 AI 智能辅助

* 自动总结与要点提取
* 自动生成标题、标签
* 内容智能归类（工作 / 生活 / 学习）
* 情绪/语调识别（语音转写后）
* AI 图表分析（情绪趋势、使用频次、分类占比）

### 3. 📅 日历与标签浏览

* 按日期浏览笔记（类似日历视图）
* 按关键词、标签、来源（语音/文字）筛选
* 速记内容预览卡片（色彩分类）

### 4. 📦 本地存储 + 导出备份

* 所有数据本地 SQLite 储存
* 自动管理附件（图片 / 音频）
* 一键备份（JSON + ZIP + 可选加密）
* 支持导入 / 恢复历史数据

### 5. 🔒 安全与隐私

* 支持加密备份文件（AES）
* 本地 PIN / 指纹 / Face ID 解锁
* 无数据上传，完全本地运行可选

---

## 🧱 技术架构方案（Flutter）

### 数据结构

* 主表：notes（内容、类型、创建时间、AI 结果）
* 附件表：attachments（路径、类型）
* 标签表：tags + notes\_tags 中间表

### 音频转写

* 本地插件：`speech_to_text`
* 远程服务：OpenAI Whisper API（可选）

### AI 能力接入

* OpenAI / Gemini API：总结、情绪分析、标签推荐
* 可本地部署轻量模型（TFLite）以保护隐私

### 导出结构

* JSON 结构 + 附件 ZIP
* 可加密文件扩展名 `.aisnap`

### 插件推荐

* `sqflite`：本地数据库
* `path_provider`、`file_picker`：文件操作
* `share_plus`：导出 / 分享
* `speech_to_text`、`just_audio`：语音输入
* `fl_chart` / `syncfusion_flutter_charts`：图表展示
* `flutter_tts`（可选）：AI 回读内容

---

## 🎨 UI 原型设计指南（Material You 风格）

### 主界面

* 顶部 AppBar：动态主题 + 搜索栏
* 内容区域：速记卡片瀑布流（支持标签颜色）
* 悬浮按钮：语音 / 手写 / 输入方式切换
* 底部导航栏：速记｜标签｜日历｜分析｜设置

### 添加速记页

* 顶部标签选择（自动推荐）
* 中间：多模态输入框（语音、键盘、手写）
* 下方：AI 实时分析卡片（总结 / 标签）

### 日历视图

* 上方月历 + 动态颜色
* 下方每日笔记卡片（按时间轴排序）

### AI 分析页

* 情绪趋势图：折线图（每日情绪）
* 使用频率：柱状图（每周速记数量）
* 分类比例：圆形图 / 标签词云
* 可滑动切换分析维度

### 设置页

* 数据导出 / 导入
* 安全设置（加密、锁屏）
* AI 模型 / API 配置

---
## Style Guidelines

> Primary color: Light Green (#8BC34A) to convey a sense of calm, growth, and freshness.

> Background color: Very Light Green (#F1F8E9), creating a soft and natural backdrop.

> Accent color: Pale Green (#A5D6A7) for interactive elements, providing a vibrant highlight.

## 🚀 版本迭代计划

### ✅ V1 MVP

* 核心速记功能（语音 / 文字）
* 本地 SQLite 存储 + 附件管理
* AI 总结 + 标签生成（调用 API）
* 日历 / 标签浏览
* 数据导出与恢复

### 🔜 V2+

* 手写输入（绘图 / 手写识别）
* 本地 AI 模型部署（Flutter + TFLite）
* 多设备同步（可选）
* AI 图表分析面板

---
