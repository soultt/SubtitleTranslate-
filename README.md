# PotPlayer AI 实时字幕翻译扩展

用 PotPlayer **自带的 Whisper AI「实时有声字幕」**把语音转成文字，再把文字发给你自己配置的
**任意 OpenAI 兼容大模型接口**翻译，最后按 PotPlayer **「实时字幕翻译」**的显示方式把译文显示在画面上。

```
视频声音 ──► Whisper AI 语音转文字 ──► 实时字幕文字
                                        │
                                        ▼
                          本扩展调用大模型 API 翻译
                                        │
                                        ▼
                          实时字幕翻译显示译文（画面上）
```

全程走 PotPlayer 官方扩展管线（`Extension\Subtitle\Translate\*.as`），不需要额外开窗口程序、
不需要注入、不需要拦截音频。

---

## 目录结构

```
potplaytrans\
├─ install.ps1                       安装 / 卸载脚本（自动定位 PotPlayer，必要时自动提权）
├─ README.md                         本文档
├─ config\
│  └─ ai-translate.example.json      配置文件模板
├─ src\
│  ├─ SubtitleTranslate - AI Translate.as    扩展主体（AngelScript，UTF-8 with BOM）
│  └─ SubtitleTranslate - AI Translate.ico   扩展图标（可选）
└─ tools\
   ├─ warmup-ollama.bat              本地模型预热（手动双击即可，最可靠的方案）
   └─ make-icon.ps1                  重新生成图标的脚本
```

安装后，扩展目录里会是：

```
<PotPlayer 安装目录>\Extension\Subtitle\Translate\
├─ SubtitleTranslate - AI Translate.as
├─ SubtitleTranslate - AI Translate.ico
└─ ai-translate.json                 ← 只有需要高级选项时才需要这个文件
```

---

## 环境要求

- PotPlayer **64 位**，版本需带「实时有声字幕（Whisper AI 语音转文字）」和「实时字幕翻译」两项功能
  （实测 **25.09.09** 正常）。
- 需要能联网访问你所配置的大模型接口（本地模型则不需要外网）。
- 安装到 `C:\Program Files\...` 需要**管理员权限**。

---

## 安装

### 方式一：脚本安装（推荐）

在 PowerShell 里进入本目录后执行：

```powershell
# 只装插件，密钥之后在 PotPlayer 设置面板里填
powershell -ExecutionPolicy Bypass -File install.ps1

# 装插件并顺便预置配置（DeepSeek 示例）
powershell -ExecutionPolicy Bypass -File install.ps1 `
    -ApiKey sk-xxxxxxxx -Model deepseek-chat `
    -ApiUrl https://api.deepseek.com/v1/chat/completions

# 用现成的配置文件
powershell -ExecutionPolicy Bypass -File install.ps1 -ConfigFile .\my-config.json

# 指定 PotPlayer 目录（脚本自动找不到时才需要）
powershell -ExecutionPolicy Bypass -File install.ps1 -PotPlayerDir "D:\PotPlayer"
```

- 写入受保护目录时脚本会**自动弹 UAC 提权**，点“是”即可。
- 如果目录里已经有 `ai-translate.json`，再跑一次**只改密钥/模型**不会覆盖其它项。
- 常用参数：`-Model` `-ApiUrl` `-ApiKey` `-ConfigFile` `-PotPlayerDir` `-Force` `-Uninstall`。

### 方式二：手动安装

1. 把 `src\SubtitleTranslate - AI Translate.as`（和 `.ico`）复制到
   `<PotPlayer 安装目录>\Extension\Subtitle\Translate\`。
2. 如需高级配置，再把 `config\ai-translate.example.json` 复制到同一目录并重命名为
   `ai-translate.json`。
3. 完全退出并重新打开 PotPlayer。

### 卸载

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

只删除 `.as` 与 `.ico`，**保留** `ai-translate.json`。手动删除这两个文件同样有效。

---

## 在 PotPlayer 里启用

需要**同时打开**两个开关：

1. **语音转文字（产生字幕）**
   右键菜单 → `字幕` → `实时有声字幕（Whisper AI 语音转文字）`
   首次使用会提示下载引擎与模型，选一个模型（如 `base` / `small` / `medium`），
   再选好识别语言。这一步和翻译插件无关，但没它就**没有输入文字**。

2. **字幕翻译（把字幕送去翻译）**
   右键菜单 → `字幕` → `实时字幕翻译` → 勾选启用，并进入 `实时字幕翻译设置...`：
   - **翻译引擎**：选 `AI 翻译(实时)`
   - **原始语言**：`自动检测`（或指定具体语言）
   - **目标语言**：例如 `中文(简体)`
   - **显示方式**：`下面显示翻译` / `仅显示翻译` / `上面显示翻译`
   - **账户 / 登录**（点登录按钮）：
     - 第一个输入框按下面的格式填配置串
     - 密码框填 API 密钥（本地模型填 `nullkey`）

> 菜单文字随 PotPlayer 版本与语言包略有差异，认准“实时有声字幕 / 实时字幕翻译 / Whisper”即可。

配置改完后请**完全退出再重开 PotPlayer**，扩展才会重新加载。

---

## 配置方式

有**两个通道**，可以只用其中一个，也可以混用：

| 通道 | 位置 | 优先级 | 适合 |
| --- | --- | --- | --- |
| 设置面板 | PotPlayer「实时字幕翻译设置」的账户/登录框 | **高** | 填模型、地址、密钥等常用项 |
| 配置文件 | 扩展目录下的 `ai-translate.json` | 低（作为默认值） | 自定义请求头、术语表、系统提示词等高级项 |

面板里填过的值会**盖过**配置文件里的同名项；面板里没填的项自动回落到配置文件 / 内置默认值。

### 1) 设置面板格式

第一个输入框填（用 `|` 分隔，共 7 段，**留空的段表示保持当前值**）：

```
模型|接口地址|温度|上下文行数|延迟ms|重试次数|最大输出token
```

例如：

```
deepseek-chat|https://api.deepseek.com/v1/chat/completions|0.2|3|0|1|0
```

- **接口地址**可以只写到根地址，脚本会自动补齐，以下写法等价：
  - `https://api.deepseek.com` → `https://api.deepseek.com/v1/chat/completions`
  - `https://api.deepseek.com/v1` → `https://api.deepseek.com/v1/chat/completions`
- **密钥**填在密码框。留空表示沿用原值；本地模型不需要密钥，填 `nullkey`。
- 想清空面板配置、恢复读取 `ai-translate.json`：在第一个框里填 `-reset-`，密码框留空，点登录。
- 两个框都留空直接点登录，会返回当前配置状态，可用来确认有没有配好。

### 2) 配置文件 `ai-translate.json`

把 `config\ai-translate.example.json` 复制到扩展目录并改名即可。所有项都可以省略，省略就用内置默认值。

字段说明：

| 键 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `model` | 字符串 | `deepseek-chat` | 模型名 |
| `apiUrl` | 字符串 | DeepSeek 地址 | 接口地址，可只写到 `/v1` |
| `apiKey` | 字符串 | 空 | API 密钥；本地模型填 `nullkey` |
| `temperature` | 数字 | `0.2` | 温度，翻译建议 0～0.3 |
| `maxTokens` | 数字 | `0` | 最大输出 token，`0` 表示不限制 |
| `contextLines` | 数字 | `3` | 作为上下文携带的上一句数（0～20） |
| `minChars` | 数字 | `0` | 短于该长度的字幕不翻译，`0` 表示不限制 |
| `delayMs` | 数字 | `0` | 重试前等待毫秒（0～10000） |
| `retries` | 数字 | `1` | 失败重试次数（0～5） |
| `timeoutMs` | 数字 | `20000` | 单次请求最长等待毫秒（1000～120000） |
| `keepAlive` | 字符串 | `24h` | 本地模型保活时长（如 `24h`、`-1` 永久）；仅对本地地址生效，留空不发送 |
| `autoWarmup` | 布尔 | `true` | 本地模型后台自动预热，见下文「本地模型为什么第一次没反应」 |
| `cache` | 布尔 | `true` | 相同原文复用上次译文（省时省钱） |
| `keepOriginalOnFailure` | 布尔 | `true` | 翻译失败时显示原文（`false` 则什么都不显示） |
| `debug` | 布尔 | `false` | 打开调试控制台窗口，打印请求与响应 |
| `logFile` | 布尔 | `false` | 把同样内容写进 `%APPDATA%\PotPlayerMini64\aitrans_log.txt`（不需要控制台，可单独开启） |
| `defaultTargetLang` | 字符串 | `zh-CN` | 当 PotPlayer 没给目标语言时用的兜底目标语言 |
| `authHeader` | 字符串 | `Authorization: Bearer {key}` | 鉴权头模板，`{key}` 会替换成密钥 |
| `extraHeaders` | 字符串 | 空 | 额外请求头，**每行一条** `名称: 值` |
| `systemPrompt` | 字符串 | 空 | 自定义系统提示词，支持 `{src}` `{dst}` 占位；留空用内置模板 |
| `glossary` | 字符串 | 空 | 术语表，**每行一条** `原文=译文` |

> 文件保存为 **UTF-8**（带不带 BOM 都可以，脚本会自动处理）。

---

## 各服务商配置示例

把对应值填进面板配置串 / `ai-translate.json` 即可。

### 云端（OpenAI 兼容）

| 服务商 | apiUrl | model 示例 | 密钥 |
| --- | --- | --- | --- |
| DeepSeek | `https://api.deepseek.com/v1/chat/completions` | `deepseek-chat` | 平台 sk- 开头 |
| OpenAI | `https://api.openai.com/v1/chat/completions` | `gpt-4o-mini` | sk- 开头 |
| 通义千问（百炼兼容模式） | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` | `qwen-flash` / `qwen-plus` | DashScope Key |
| 智谱 GLM | `https://open.bigmodel.cn/api/paas/v4/chat/completions` | `glm-4-flash` / `glm-4-air` | 平台 Key |
| 月之暗面 Kimi | `https://api.moonshot.cn/v1/chat/completions` | `moonshot-v1-8k` | 平台 Key |
| 硅基流动 | `https://api.siliconflow.cn/v1/chat/completions` | `Qwen/Qwen2.5-7B-Instruct` | 平台 Key |
| 百度千帆 v2 | `https://qianfan.baidubce.com/v2/chat/completions` | `ernie-speed-128k` | 千帆 Key |
| OpenRouter | `https://openrouter.ai/api/v1/chat/completions` | `google/gemini-2.0-flash-001` | 平台 Key |
| Google Gemini（兼容端点） | `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` | `gemini-2.0-flash` | AI Studio Key |

> 上表仅为示例，模型名与地址会随服务商调整，请以各平台文档为准。
> Azure OpenAI 这类需要用 `api-key` 头的服务，把 `authHeader` 改成 `api-key: {key}`。
> OpenRouter 想带来源标识，可在 `extraHeaders` 里加：
> ```
> HTTP-Referer: http://localhost
> X-Title: PotPlayer AI Translate
> ```

### 本地模型（不出本机、免费、无隐私顾虑）

| 引擎 | apiUrl | model 示例 | 密钥 |
| --- | --- | --- | --- |
| Ollama | `http://127.0.0.1:11434/v1/chat/completions` | `qwen2.5` / `llama3.1` | `nullkey` |
| LM Studio | `http://127.0.0.1:1234/v1/chat/completions` | 载入的模型名 | `nullkey` |
| text-generation-webui / vLLM / SGLang | 各自的 OpenAI 兼容地址 | 模型名 | `nullkey` |

> 本地模型只要接口地址里含 `127.0.0.1` 或 `localhost`，脚本**不会要求填密钥**。

#### 本地模型为什么“第一次没反应”（必读）

PotPlayer 给扩展脚本的**单次 HTTP 请求上限约 8.5 秒**，超过就会被 PotPlayer 掐断
（Ollama 的 `server.log` 里会看到 `499`，并伴随
`client connection closed before llama-server finished loading, aborting load`）。
而本地大模型**第一次加载**要把整份权重读进内存，实测 12B 模型需要 **10～20 秒**
（本机实测 `translategemma:12b` 冷加载 **10.7 秒**），必定超过 8.5 秒，于是请求被掐断；
更要命的是 Ollama 一旦发现客户端断开就会**取消本次加载** —— 所以“在 PotPlayer 里多试几次”
永远加载不上，会一直失败。**必须在 PotPlayer 之外先把模型加载好。**

插件为此做了两件事：

1. **后台预热（`autoWarmup`，默认开）**
   插件加载时、以及每次请求失败时，都会另外起一个**隐藏进程**（`wscript` + `curl`，无窗口、
   不阻塞 PotPlayer）去发一次预热请求，先把模型读进内存。约 10～20 秒后模型就绪，
   此后所有翻译请求都是 1～3 秒的快请求。
   → 也就是说：**启动 PotPlayer 后等十几秒再开始看**，就不会遇到“开头几句没翻译”。
   → 在设置面板里点「登录」也会顺手触发一次预热（并会在返回信息里带上 `warmup=...` 状态，
     失败原因一目了然）。

2. **保活（`keepAlive`，默认 `24h`）**
   每次请求都带 `keep_alive`，让模型加载后长期常驻内存，不会你暂停几分钟就被 Ollama 卸载，
   从而避免反复冷启动。

**最稳妥的做法：用 `tools\warmup-ollama.bat` 手动预热一次**

双击 `tools\warmup-ollama.bat`（或命令行运行 `warmup-ollama.bat 模型名 接口地址`），
它会在 PotPlayer 之外发一次带 `keep_alive` 的请求并等它加载完，最后打印 `ollama ps` 结果。
看到模型出现在 `ollama ps` 列表里（`UNTIL` 是 `24 hours from now`）就成功了：

```
NAME                  ID              SIZE     PROCESSOR          UNTIL
translategemma:12b    c2f9a9ca1ec7    10 GB    46%/54% CPU/GPU    24 hours from now
```

之后只要 Ollama 不重启，PotPlayer 里的翻译就一直是快请求。

想更省心，也可以让模型**长期常驻**：

- 设系统环境变量 `OLLAMA_KEEP_ALIVE=-1`（Ollama 永不卸载模型），然后重启 Ollama；
- 或者手动预热一次：`ollama run --keepalive 24h 模型名 "hi"`。

排查时先看这两个：

- `ollama ps`：**模型不在列表里**就说明没加载，翻译必然超时；
- `ollama serve` 的日志（`%LOCALAPPDATA%\Ollama\server.log`）：出现 `499` 就是被 8.5 秒上限掐断。

关掉自动预热：把 `autoWarmup` 设为 `false`（例如模型很小加载很快、或你已经让它常驻了）。

> 若日志里出现「等待 Nms 后放弃」且 N 接近 8500，就说明撞上了这个上限 —— 等十几秒再试即可。

---

## 进阶

### 术语表（glossary）

每行一条 `原文=译文`，会作为硬性要求附给模型：

```
PotPlayer=PotPlayer
Captain=船长
```

### 自定义系统提示词（systemPrompt）

留空时用内置的“专业字幕翻译”模板。自定时可用 `{src}` / `{dst}` 占位，例如：

```
把下面的字幕从 {src} 翻译成 {dst}，只输出译文，不要解释，保持一行。
```

### 省流量 / 省成本

- `cache: true`：重复出现的字幕直接复用译文。
- 调大 `minChars`：过滤掉过短的气口、语气词。
- `contextLines` 调大能提升连贯性，但每次请求会更长，按需权衡。

### 调试

平时这两个开关都是关的：`debug`（控制台窗口）和 `logFile`（写文件）。需要排查时按需打开其中一个并重启 PotPlayer：

- `"debug": true` —— 弹出控制台窗口，打印每次请求的 URL、消息体、返回内容和耗时。
- `"logFile": true` —— 不弹窗，把同样内容（外加当前生效的模型、面板覆盖了配置文件哪些项）写进
  `%APPDATA%\PotPlayerMini64\aitrans_log.txt`，只保留最近约 24KB。

排查完记得改回 `false`。

---

## 常见问题

**1. 字幕一直显示原文 / 没有翻译**
- 检查是否**同时**开了「实时有声字幕」和「实时字幕翻译」。
- 「实时字幕翻译设置」里是否选了 `AI 翻译(实时)`。
- 是否填了 API 密钥（本地模型用 `nullkey`）。打开 `logFile`（推荐）或 `debug` 看提示。
- 面板上的「测试」按钮只回显当前配置（**不调用模型**）；想验证连通性请点「登录」。
- 本地模型先确认已经加载好：`ollama ps` 里要能看到你的模型（否则先跑一次 `tools\warmup-ollama.bat`）。

**2. 面板点登录提示 “Saved, but the test request failed: no response in 8xxx ms...”**
- 说明配置能存下来，但那次探测请求没成功。检查地址、密钥、网络、代理。
- 若是**本地模型**且提示 `no response in 8xxx ms - the local model is probably not loaded yet`，
  那是撞上了 PotPlayer 约 8.5 秒的硬上限：
  - 先确认 `ollama ps` 里有没有这个模型；没有就双击 `tools\warmup-ollama.bat` 把它加载好
    （约 10～30 秒），或者点「登录」触发插件自带的预热后**等十几秒再点一次**；
  - 返回串里的 `warmup=...` 会告诉你预热是成功启动还是卡在哪一步。
  - `timeoutMs` 对本地模型无效 —— 那个上限是 PotPlayer 定的，改不了。
- 云端接口偶尔抖动，把 `retries` 调大一点。

**3. 翻译很慢 / 有延迟**
- 大模型接口本身有延迟，属正常。换更快的模型（`*-flash` / `*-mini` / `*-speed` 类），
  或改用本地模型，或减小 `contextLines`。

**4. 模型把原文照抄回来了（不翻译）**
- 脚本检测到回显会自动用更强的提示词重试一次。
- 仍不行就换一个翻译能力更强的模型，或把 `temperature` 调低到 `0`。

**5. 译文被截断**
- 把 `maxTokens` 设成一个正数（如 `1024`）。

**6. 提示“配置文件 JSON 解析失败”**
- 用记事本/编辑器检查 `ai-translate.json` 的括号、引号、逗号是否合法。

**7. 装了但列表里没有 `AI 翻译(实时)`**
- 确认 `.as` 放在 `<PotPlayer>\Extension\Subtitle\Translate\` 且文件名正确。
- 完全退出 PotPlayer 再打开。
- 确认下载/使用的是 64 位 PotPlayer。

**8. 写完配置没生效**
- 一定要**完全退出并重开** PotPlayer；改 `ai-translate.json` 或在面板里改配置都同理。

**9. 弹窗里的中文是乱码（例如 `涓婂笺鏇?3 琛?` 或一堆 `�`）**
- PotPlayer 弹出的消息框（「测试」结果、登录返回的提示）**只按系统 ANSI 代码页**
  （中文系统是 GBK）解释脚本返回的字节；而 `.as` 源码里的中文是 UTF-8 —— 于是
  「UTF-8 字节被当成 GBK 读」，就成了乱码。
- 试验过在返回前用 `HostUTF8ToMBCS()` 把中文转成 GBK，结果**更糟**：PotPlayer 会把
  返回的字节再转一次，变成一堆 `�` 替换字符。所以这类**不带 `{$CP936=...$}` 标签**的弹窗
  已改成**纯 ASCII 英文**（配置名、报错原因、`warmup=` 状态都在一行里，够看）。
- 带 `{$CP936=...$}` / `{$CP0=...$}` 标签的界面文字（引擎名、设置面板标签）不受影响，
  那一套交给 PotPlayer 自己按标签处理，**不要**自己转换。
- 中文的详细说明看：`logFile=true`（或 `debug=true`）时的日志输出、以及本 README。

---

## 隐私说明

「实时有声字幕」识别出的字幕文字会**逐条发送**到你配置的那个接口。
- 用云端服务商：文字会离开本机，请遵守该服务商的条款与隐私政策。
- 用本地模型（Ollama / LM Studio 等）：文字不出本机。

---

## 致谢与参考

- PotPlayer 官方扩展 API 文档：`<PotPlayer 安装目录>\Extension\api.txt`
- 官方示例扩展：`Extension\Subtitle\Translate\SubtitleTranslate - Libre.as` 等

本扩展为个人自制，与 PotPlayer / 各模型服务商无关联。
