# 📱Voca

---

## 🧭 产品定位

**english slogan：** 
> Think less. Remember more

**中文 slogan：** 
> 轻松记，事事记。

**一句话介绍**：
> 支持语音、文字输入的智能速记工具，轻松记录灵感、会议和生活点滴，AI 自动整理总结和心情分析，让你轻松记，事事记。

**目标用户：**

* 学生：课堂重点、学习笔记、灵感收集、情绪追踪
* 知识工作者：会议记录、任务备忘、语音转文字、心情管理
* 内容创作者：灵感整理、素材存储、创意速写、情绪洞察
* 日常用户：日程提醒、想法速记、心情追踪、情绪分析

---

## 🔧 核心功能模块

### 1. 📥 多模态速记输入

* ✅ 语音速记（自动转文字）
* ✅ 快速文字输入
* ✅ 附件添加（图片、音频）
* ✅ 心情指数记录（数值化情绪评分）

### 2. 🤖 AI 智能辅助

* 自动总结与要点提取
* 自动生成标题
* 内容智能归类（工作 / 生活 / 学习）
* 情绪/语调识别（语音转写后）
* AI 心情分析与洞察
* 个性化心情建议和趋势预测
* AI 图表分析（情绪趋势、使用频次、分类占比、心情波动）

### 3. 📅 日历与心情浏览

* 按日期浏览笔记（类似日历视图）
* 按关键词、心情指数、来源（语音/文字）筛选
* 速记内容预览卡片（心情色彩分类）
* 心情指数时间轴展示

### 4. � 心情分析系统

* 心情指数评分系统（1-10分数值化）
* 动态心情趋势分析
* 心情波动性监测
* 情绪状态等级评估
* 心情分布统计图表
* AI 驱动的心情洞察报告

### 5. �📦 本地存储 + 导出备份

* 所有数据本地 SQLite 储存
* 自动管理附件（图片 / 音频）
* 一键备份（JSON + ZIP + 可选加密）
* 支持导入 / 恢复历史数据

### 6. 🔒 安全与隐私

* 支持加密备份文件（AES）
* 本地 PIN / 指纹 / Face ID 解锁
* 无数据上传，完全本地运行可选

---

## 🧱 技术架构方案（Flutter）

### 数据结构

* 主表：notes（内容、类型、创建时间、心情指数、AI 结果）
* 附件表：attachments（路径、类型）
* 心情分析表：mood_analytics（日期、心情指数、波动性）

### 音频转写

* 本地插件：`speech_to_text`
* 远程服务：OpenAI Whisper API（可选）

### AI 能力接入

* OpenAI / Gemini API：总结、情绪分析、心情洞察
* 可本地部署轻量模型（TFLite）以保护隐私

### 心情分析系统

* `MoodScoring`：心情评分映射和计算
* `MoodTrendAnalysis`：心情趋势分析
* `AIAgentService`：AI 驱动的心情洞察
* `AnalyticsService`：综合数据分析

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
* 内容区域：速记卡片瀑布流（支持心情色彩分类）
* 悬浮按钮：语音 / 输入方式切换
* 底部导航栏：速记｜心情｜日历｜分析｜设置

### 添加速记页

* 顶部心情选择器（😍兴奋、😊开心、😌平静等）
* 中间：多模态输入框（语音、键盘）
* 下方：AI 实时分析卡片（总结 / 心情洞察）
* 心情指数滑块（1-10分评分）

### 日历视图

* 上方月历 + 动态颜色（基于心情指数）
* 下方每日笔记卡片（按时间轴排序）
* 每日心情指数显示

### AI 分析页

* 心情趋势图：折线图（每日心情指数变化）
* 使用频率：柱状图（每周速记数量）
* 心情分布：圆形图（各心情类型占比）
* 心情波动性分析图表
* AI 洞察卡片（个性化建议）
* 可滑动切换分析维度

### 心情浏览页

* 心情筛选器（按心情类型、指数范围）
* 心情色彩编码的笔记卡片
* 心情统计概览
* 快速心情洞察摘要

### 设置页

* 数据导出 / 导入
* 安全设置（加密、锁屏）
* AI 模型 / API 配置
* 心情提醒设置

---
## Style Guidelines

> Primary color: Teal Green (#31DA9F) to convey a sense of vitality, innovation, and natural harmony.

> Background color: Very Light Teal (#E8F8F2), creating a fresh and calming backdrop.

> Accent color: Light Teal (#7AE6B8) for interactive elements, providing a vibrant and modern highlight.

> Secondary accent: Medium Teal (#52E5A3) for emphasis and call-to-action elements.

### 心情色彩系统

> 基于心情指数的动态配色方案：
> - 非常积极 (8.5-10分): 深青绿 (#28B085)
> - 积极 (7.0-8.4分): 主青绿 (#31DA9F)  
> - 平和 (5.5-6.9分): 中青绿 (#52E5A3)
> - 一般 (4.0-5.4分): 浅青绿 (#7AE6B8)
> - 消极 (2.5-3.9分): 蓝绿 (#48C9B0)
> - 非常消极 (1.0-2.4分): 深蓝绿 (#1ABC9C)

## 🚀 版本迭代计划

### ✅ V1 MVP

* 核心速记功能（语音 / 文字）
* 本地 SQLite 存储 + 附件管理
* AI 总结 + 心情分析（调用 API）
* 日历 / 心情浏览
* 心情指数评分系统
* 数据导出与恢复

### 🔜 V2+

* 本地 AI 模型部署（Flutter + TFLite）
* 多设备同步（可选）
* AI 图表分析面板
* 高级心情洞察和预测
* 个性化心情建议系统

---
