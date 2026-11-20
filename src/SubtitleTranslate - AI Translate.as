/*
    SubtitleTranslate - AI Translate   v1.0.0
    PotPlayer 实时字幕翻译扩展（AngelScript）

    ---------------------------------------------------------------------------
    它做什么
      把 PotPlayer 送进来的字幕文字（含 PotPlayer 内置 Whisper AI「实时有声字幕」
      即语音转文字产生的实时字幕）发给任意 OpenAI 兼容的大模型接口，拿回译文，
      PotPlayer 再按「实时字幕翻译」的显示方式显示在画面上。

        视频声音 --> Whisper AI 语音转文字 --> 实时字幕文字
                 --> 本扩展调用大模型翻译 --> 实时字幕显示译文

    安装位置
      <PotPlayer 安装目录>\Extension\Subtitle\Translate\
        SubtitleTranslate - AI Translate.as
        SubtitleTranslate - AI Translate.ico

    配置方式（两种，可混用；对话框里的值优先级更高）
      1) 菜单：字幕 -> 实时字幕翻译 -> 实时字幕翻译设置...
         翻译引擎选 “AI 翻译(实时)”，点账户/登录，在“模型”栏按下面格式填写：
             模型|接口地址|温度|上下文行数|延迟ms|重试次数|最大输出token
         例如： deepseek-chat|https://api.deepseek.com/v1/chat/completions|0.2|3|0|1|0
         “密码”栏填 API 密钥（本地模型不需要密钥时填 nullkey）。
         在“模型”栏填 -reset- 可清除对话框配置，恢复成读取 ai-translate.json。
      2) 扩展目录下的 ai-translate.json（见 config/ai-translate.example.json），
         可配置自定义请求头、术语表、系统提示词等高级选项。

    官方扩展 API 文档：<PotPlayer 安装目录>\Extension\api.txt
    ---------------------------------------------------------------------------
*/

// ============================== 内置默认值（可被 ai-translate.json 覆盖）==============================

string FILE_MODEL          = "deepseek-chat";
string FILE_URL            = "https://api.deepseek.com/v1/chat/completions";
string FILE_KEY            = "";
string FILE_TEMP           = "0.2";
string FILE_MAXTOKENS      = "0";
string FILE_TARGET         = "zh-CN";                          // 目标语言为空时的兜底目标语言
string FILE_AUTH_HEADER    = "Authorization: Bearer {key}";     // {key} 会被替换成密钥
string FILE_SYSTEM_PROMPT  = "";                                // 自定义系统提示词（留空用内置模板）
string FILE_GLOSSARY       = "";                                // 术语表，每行一条：原文=译文
string FILE_EXTRA_HEADERS  = "";                                // 额外请求头，每行一条：Name: Value
int    FILE_CONTEXT        = 3;                                 // 作为上下文携带的上一句数
int    FILE_DELAY_MS       = 0;                                 // 重试前等待毫秒
int    FILE_RETRY          = 1;                                 // 失败重试次数
int    FILE_TIMEOUT_MS     = 20000;                             // 单次请求允许的最长时间
int    FILE_MINCHARS       = 0;                                 // 短于该长度的字幕不翻译（0=不限制）
bool   FILE_CACHE          = true;                              // 相同文字复用上一次译文
bool   FILE_KEEP_ORIG      = true;                              // 失败时返回原文（false=返回空）
bool   FILE_DEBUG          = false;                             // 打开调试控制台窗口
bool   FILE_LOGFILE        = false;                             // 写日志文件（不需要控制台）
string FILE_KEEPALIVE      = "24h";                             // 本地模型保活时长(keep_alive)，留空不发送
bool   FILE_AUTOWARMUP     = true;                              // 本地模型自动后台预热（解决首次加载超时）

// ================ 幻觉/静音字幕过滤 ================
bool   FILE_BLOCK_HALLUCINATIONS = true;                        // 拦截常见 Whisper 幻觉文本（谢谢观看、[Music] 等）
int    FILE_MIN_INTERVAL_MS      = 500;                         // 同一文本最小翻译间隔(ms)，0=不限制
int    FILE_MAX_GAP_MS           = 5000;                        // 判定为"静音间隙"的最大间隔(ms)，0=不检测；超过此间隔后首次字幕返回空以清除残留
string FILE_HALLUCINATION_PATTERNS =                            // 自定义幻觉拦截词，每行一条（留空用内置列表）
    "谢谢观看\n"
    "thank you for watching\n"
    "thanks for watching\n"
    "字幕由\n"
    "subtitle by\n"
    "subtitles by\n"
    "transcribed by\n"
    "[music]\n"
    "[音乐]\n"
    "♪\n"
    "♫\n"
    "🎵\n"
    "🎶\n"
    "免责声明\n"
    "disclaimer\n"
    "版权所有\n"
    "copyright\n"
    "follow us\n"
    "关注我们\n"
    "订阅\n"
    "subscribe\n"
    "like and subscribe\n"
    "thanks for listening\n"
    "thank you for listening\n"
    "thanks for your support\n"
    "thank you for your support\n"
    "please subscribe\n"
    "please like\n"
    "like and share\n"
    "share and subscribe\n"
    "don't forget to subscribe\n"
    "点赞关注\n"
    "一键三连\n"
    "点赞收藏\n"
    "转发分享\n"
    "评论区见\n"
    "下期再见\n"
    "我们下期见\n"
    "拜拜\n"
    "bye bye\n"
    "goodbye\n"
    "see you next time\n"
    "see you later\n"
    "thanks for watching\n"
    "thank you so much\n"
    "thank you very much\n"
    "thanks a lot\n"
    "thx\n"
    "ty\n"
    "background music\n"
    "bgm\n"
    "背景音乐\n"
    "片头曲\n"
    "片尾曲\n"
    "opening\n"
    "ending\n"
    "op\n"
    "ed\n"
    "主题曲\n"
    "插入歌\n"
    "insert song\n"
    "音效\n"
    "sound effect\n"
    "sfx\n"
    "applause\n"
    "掌声\n"
    "laughter\n"
    "笑声\n"
    "silence\n"
    "静音\n"
    "no speech\n"
    "无语音\n"
    "无声音\n"
    "无人说话\n"
    "narrator\n"
    "旁白\n"
    "字幕组\n"
    "字幕制作\n"
    "subtitle team\n"
    "sub by\n"
    "subs by\n"
    "translated by\n"
    "翻译\n"
    "翻译:\n"
    "翻译：\n"
    "校对\n"
    "校对:\n"
    "校对：\n"
    "时间轴\n"
    "timeline\n"
    "time code\n"
    "timecode\n"
    "压制\n"
    "encode\n"
    "编码\n"
    "后期\n"
    "post production\n"
    "制作\n"
    "production\n"
    "出品\n"
    "presented by\n"
    "制作人\n"
    "producer\n"
    "导演\n"
    "director\n"
    "监制\n"
    "executive producer\n"
    "策划\n"
    "planning\n"
    "统筹\n"
    "coordination\n"
    "鸣谢\n"
    "special thanks\n"
    "thanks to\n"
    "感谢\n"
    "感谢观看\n"
    "感谢收看\n"
    "收看\n"
    "观看\n"
    "收听\n"
    "收听\n"
    "收看完毕\n"
    "观看完毕\n"
    "播放结束\n"
    "播放完毕\n"
    "视频结束\n"
    "视频完毕\n"
    "end of video\n"
    "video ended\n"
    "the end\n"
    "结束\n"
    "完结\n"
    "full video\n"
    "完整版\n"
    "完整视频\n"
    "full version\n"
    "complete version\n"
    "完整版本\n"
    "高清\n"
    "hd\n"
    "1080p\n"
    "720p\n"
    "4k\n"
    "超清\n"
    "原画\n"
    "source\n"
    "原版\n"
    "raw\n"
    "未剪辑\n"
    "uncut\n"
    "无剪辑\n"
    "no cut\n"
    "中文字幕\n"
    "chinese subtitles\n"
    "chinese sub\n"
    "简体中文\n"
    "繁体中文\n"
    "简中\n"
    "繁中\n"
    "双语字幕\n"
    "bilingual subtitles\n"
    "双语\n"
    "中英字幕\n"
    "eng sub\n"
    "english sub\n"
    "english subtitles\n"
    "字幕下载\n"
    "subtitle download\n"
    "下载字幕\n"
    "download subtitle\n"
    "字幕文件\n"
    "subtitle file\n"
    "srt\n"
    "ass\n"
    "vtt\n"
    "字幕格式\n"
    "subtitle format\n"
    "字幕同步\n"
    "subtitle sync\n"
    "同步字幕\n"
    "sync subtitle\n"
    "字幕组招募\n"
    "recruiting\n"
    "招募翻译\n"
    "招募校对\n"
    "招募时间轴\n"
    "招募压制\n"
    "join us\n"
    "加入我们\n"
    "志愿者\n"
    "volunteer\n"
    "合作\n"
    "collaboration\n"
    "商务合作\n"
    "business cooperation\n"
    "商务\n"
    "business\n"
    "联系方式\n"
    "contact\n"
    "邮箱\n"
    "email\n"
    "微信\n"
    "wechat\n"
    "qq\n"
    "群\n"
    "group\n"
    "粉丝群\n"
    "fan group\n"
    "交流群\n"
    "discussion group\n"
    "官网\n"
    "official website\n"
    "官方网站\n"
    "主页\n"
    "homepage\n"
    "网站\n"
    "website\n"
    "链接\n"
    "link\n"
    "网址\n"
    "url\n"
    "扫码\n"
    "scan qr\n"
    "二维码\n"
    "qr code\n"
    "关注公众号\n"
    "follow official account\n"
    "公众号\n"
    "official account\n"
    "微博\n"
    "weibo\n"
    "抖音\n"
    "douyin\n"
    "tiktok\n"
    "bilibili\n"
    "b站\n"
    "b 站\n"
    "哔哩哔哩\n"
    "youtube\n"
    "油管\n"
    "twitch\n"
    "推特\n"
    "twitter\n"
    "x.com\n"
    "facebook\n"
    "instagram\n"
    "ins\n"
    "小红书\n"
    "xiaohongshu\n"
    "rednote\n"
    "快手\n"
    "kuaishou\n"
    "西瓜视频\n"
    "xigua\n"
    "头条\n"
    "toutiao\n"
    "今日头条\n"
    "腾讯视频\n"
    "tencent video\n"
    "爱奇艺\n"
    "iqiyi\n"
    "优酷\n"
    "youku\n"
    "芒果tv\n"
    "mgtv\n"
    "搜狐视频\n"
    "sohu video\n"
    "乐视\n"
    "letv\n"
    "pptv\n"
    "风行\n"
    "funshion\n"
    "acfun\n"
    "a站\n"
    "a 站\n"
    "nico\n"
    "nicovideo\n"
    "niconico\n"
    "abema\n"
    "dailymotion\n"
    "vimeo\n"
    "streaming\n"
    "直播\n"
    "live\n"
    "直播中\n"
    "live now\n"
    "正在直播\n"
    "直播结束\n"
    "live ended\n"
    "回放\n"
    "replay\n"
    "录播\n"
    "vod\n"
    "点播\n"
    "on demand\n"
    "会员\n"
    "vip\n"
    "会员专享\n"
    "vip only\n"
    "付费\n"
    "paid\n"
    "订阅制\n"
    "subscription\n"
    "赞助\n"
    "sponsor\n"
    "赞助商\n"
    "sponsorship\n"
    "广告\n"
    "advertisement\n"
    "广告位\n"
    "ad slot\n"
    "推广\n"
    "promotion\n"
    "推荐\n"
    "recommend\n"
    "推荐视频\n"
    "recommended video\n"
    "相关视频\n"
    "related video\n"
    "更多视频\n"
    "more videos\n"
    "点击观看\n"
    "click to watch\n"
    "观看更多\n"
    "watch more\n"
    "查看详情\n"
    "view details\n"
    "详情\n"
    "details\n"
    "简介\n"
    "description\n"
    "视频简介\n"
    "video description\n"
    "内容简介\n"
    "content description\n"
    "剧情简介\n"
    "plot summary\n"
    "故事梗概\n"
    "synopsis\n"
    "剧透警告\n"
    "spoiler alert\n"
    "剧透\n"
    "spoiler\n"
    "慎入\n"
    "viewer discretion advised\n"
    "慎看\n"
    "not for everyone\n"
    "18+\n"
    "成人内容\n"
    "adult content\n"
    "nsfw\n"
    "敏感内容\n"
    "sensitive content\n"
    "免责声明\n"
    "disclaimer\n"
    "仅供娱乐\n"
    "for entertainment only\n"
    "娱乐 purposes only\n"
    "不代表立场\n"
    "does not represent views\n"
    "个人观点\n"
    "personal opinion\n"
    "仅供参考\n"
    "for reference only\n"
    "非官方\n"
    "unofficial\n"
    "非营利\n"
    "non-profit\n"
    "非商业\n"
    "non-commercial\n"
    "fair use\n"
    "合理使用\n"
    "版权声明\n"
    "copyright notice\n"
    "版权归属\n"
    "copyright belongs to\n"
    "版权所有者\n"
    "copyright owner\n"
    "原作者\n"
    "original author\n"
    "原创作者\n"
    "original creator\n"
    "内容来源\n"
    "content source\n"
    "来源\n"
    "source\n"
    "转载\n"
    "repost\n"
    "搬运\n"
    "reupload\n"
    "搬运工\n"
    "reposter\n"
    "授权\n"
    "permission\n"
    "许可\n"
    "license\n"
    "cc by\n"
    "creative commons\n"
    "知识共享\n"
    "public domain\n"
    "公共领域\n"
    "无版权\n"
    "no copyright\n"
    "免版税\n"
    "royalty free\n"
    "素材\n"
    "material\n"
    "素材来源\n"
    "material source\n"
    "背景素材\n"
    "background material\n"
    "视频素材\n"
    "video material\n"
    "音频素材\n"
    "audio material\n"
    "音乐素材\n"
    "music material\n"
    "音效素材\n"
    "sfx material\n"
    "字体\n"
    "font\n"
    "字体授权\n"
    "font license\n"
    "开源字体\n"
    "open source font\n"
    "免费字体\n"
    "free font\n"
    "商用字体\n"
    "commercial font\n"
    "字体下载\n"
    "font download\n"
    "字体链接\n"
    "font link\n"
    "模板\n"
    "template\n"
    "字幕模板\n"
    "subtitle template\n"
    "特效字幕\n"
    "karaoke\n"
    "卡拉ok\n"
    "歌词字幕\n"
    "lyrics subtitle\n"
    "歌词\n"
    "lyrics\n"
    "lrc\n"
    "krc\n"
    "翻唱\n"
    "cover\n"
    "cover song\n"
    "原唱\n"
    "original singer\n"
    "作词\n"
    "lyricist\n"
    "作曲\n"
    "composer\n"
    "编曲\n"
    "arranger\n"
    "混音\n"
    "mixing\n"
    "母带\n"
    "mastering\n"
    "录音\n"
    "recording\n"
    "录音室\n"
    "studio\n"
    "录音棚\n"
    "recording studio\n"
    "人声\n"
    "vocal\n"
    "伴奏\n"
    "instrumental\n"
    "纯音乐\n"
    "instrumental music\n"
    "无人声\n"
    "no vocal\n"
    "off vocal\n"
    "inst\n"
    "karaoke version\n"
    "卡拉ok版\n"
    "伴奏版\n"
    "纯音乐版\n"
    "instrumental version\n"
    "off vocal version\n";

// ============================== 运行时配置（= 对话框值 或 文件默认值）==============================

string CFG_MODEL       = FILE_MODEL;
string CFG_URL         = FILE_URL;
string CFG_KEY         = FILE_KEY;
string CFG_TEMP        = FILE_TEMP;
string CFG_MAXTOKENS   = FILE_MAXTOKENS;
string CFG_TARGET      = FILE_TARGET;
string CFG_AUTH_HEADER = FILE_AUTH_HEADER;
string CFG_SYSPROMPT   = FILE_SYSTEM_PROMPT;
string CFG_GLOSSARY    = FILE_GLOSSARY;
string CFG_EXTRAHDR    = FILE_EXTRA_HEADERS;
int    CFG_CONTEXT     = FILE_CONTEXT;
int    CFG_DELAY_MS    = FILE_DELAY_MS;
int    CFG_RETRY       = FILE_RETRY;
int    CFG_TIMEOUT_MS  = FILE_TIMEOUT_MS;
int    CFG_MINCHARS    = FILE_MINCHARS;
bool   CFG_CACHE       = FILE_CACHE;
bool   CFG_KEEP_ORIG   = FILE_KEEP_ORIG;
bool   CFG_DEBUG       = FILE_DEBUG;
bool   CFG_LOGFILE     = FILE_LOGFILE;
string CFG_KEEPALIVE   = FILE_KEEPALIVE;
bool   CFG_AUTOWARMUP  = FILE_AUTOWARMUP;

// 幻觉/静音字幕过滤运行时配置
bool   CFG_BLOCK_HALLUCINATIONS = FILE_BLOCK_HALLUCINATIONS;
int    CFG_MIN_INTERVAL_MS      = FILE_MIN_INTERVAL_MS;
int    CFG_MAX_GAP_MS           = FILE_MAX_GAP_MS;
string CFG_HALLUCINATION_PATTERNS = FILE_HALLUCINATION_PATTERNS;
uint   WARM_TICK       = 0;
bool   WARM_LAUNCHED   = false;
string WARM_STATUS     = "idle";     // 预热结果，纯 ASCII，会显示在弹出消息里（便于排查）
string CFG_SOURCE      = "unknown";  // 配置来源（扩展目录/配置目录/内置默认值），排查用

// 调试日志：除控制台外，还把最近若干行写进配置目录的 aitrans_log.txt（相对路径，PotPlayer 只允许配置目录内）
string LOG_BUF         = "";
int    LOG_SEQ         = 0;

string USER_AGENT      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)";
string UNSET_MARK      = "__AITRANS_UNSET__";   // 对话框“未设置”占位，避免和真实值冲突
string TAG_OPEN        = "[[";
string TAG_CLOSE       = "]]";

array<string> CacheKeys;
array<string> CacheVals;
array<string> ContextLines;

// 幻觉拦截与去重用的运行时状态
string LAST_SOURCE           = "";      // 上一次收到的原文（去首尾空白）
uint   LAST_TRANSLATE_TICK   = 0;       // 上一次翻译的时间戳
uint   LAST_SUBTITLE_TICK    = 0;       // 上一次收到字幕的时间戳（无论是否翻译）
array<string> HALLUCINATION_LIST;       // 解析后的幻觉拦截词列表

// ============================== 引擎信息（PotPlayer 列表/对话框里显示）==============================

string GetTitle()
{
    return "{$CP949=AI 번역(실시간)$}"
         + "{$CP950=AI 翻譯(即時)$}"
         + "{$CP936=AI 翻译(实时)$}"
         + "{$CP0=AI Translate (Realtime)$}";
}

string GetVersion()
{
    return "1.0.0";
}

string GetDesc()
{
    return "{$CP950=呼叫任意 OpenAI 相容大模型 API 即時翻譯字幕，可搭配內建 Whisper 即時語音字幕使用。$}"
         + "{$CP936=调用任意 OpenAI 兼容大模型 API 实时翻译字幕，可搭配内置 Whisper 实时语音字幕使用。$}"
         + "{$CP0=Realtime subtitle translation with any OpenAI-compatible LLM API. Works with PotPlayer's built-in Whisper live subtitles.$}";
}

string GetLoginTitle()
{
    return "{$CP949=모델 및 API 설정$}"
         + "{$CP950=模型與 API 設定$}"
         + "{$CP936=模型与 API 配置$}"
         + "{$CP0=Model / API Configuration$}";
}

string GetLoginDesc()
{
    return "{$CP950=格式：模型|介面位址|溫度|上下文行數|延遲ms|重試次數|最大token。位址可以是以 /v1 結尾的根位址，會自動補 /chat/completions。$}"
         + "{$CP936=格式：模型|接口地址|温度|上下文行数|延迟ms|重试次数|最大token。留空表示保持当前值；“地址”可以只写到 /v1，会自动补 /chat/completions。想清掉这里的设置、改回读取 ai-translate.json，就在模型栏填 -reset-。$}"
         + "{$CP0=Format: model|apiUrl|temperature|contextLines|delayMs|retries|maxTokens. Empty part = keep current; a base URL ending with /v1 is completed to /chat/completions. To clear this panel and fall back to ai-translate.json, type -reset- in the model box.$}";
}

string GetUserText()
{
    return "{$CP950=模型|介面位址|溫度|上下文行數|延遲ms|重試次數|最大token（當前：" + CFG_MODEL + " | " + CFG_URL + " | " + CFG_TEMP + " | " + formatInt(CFG_CONTEXT) + " | " + formatInt(CFG_DELAY_MS) + " | " + formatInt(CFG_RETRY) + " | " + CFG_MAXTOKENS + "）$}"
         + "{$CP936=模型|接口地址|温度|上下文行数|延迟ms|重试次数|最大token（当前：" + CFG_MODEL + " | " + CFG_URL + " | " + CFG_TEMP + " | " + formatInt(CFG_CONTEXT) + " | " + formatInt(CFG_DELAY_MS) + " | " + formatInt(CFG_RETRY) + " | " + CFG_MAXTOKENS + "）$}"
         + "{$CP0=model|apiUrl|temperature|contextLines|delayMs|retries|maxTokens (current: " + CFG_MODEL + " | " + CFG_URL + " | " + CFG_TEMP + " | " + formatInt(CFG_CONTEXT) + " | " + formatInt(CFG_DELAY_MS) + " | " + formatInt(CFG_RETRY) + " | " + CFG_MAXTOKENS + ")$}";
}

string GetPasswordText()
{
    return "{$CP949=API 키:$}"
         + "{$CP950=API 金鑰:$}"
         + "{$CP936=API 密钥:$}"
         + "{$CP0=API Key:$}";
}


// ============================== 支持的语言（代码 + 英文名，供提示词使用）==============================

array<string> LangTable =
{
    "en|English", "zh-CN|Chinese (Simplified)", "zh-TW|Chinese (Traditional)", "ja|Japanese",
    "ko|Korean", "fr|French", "de|German", "es|Spanish", "pt|Portuguese", "ru|Russian",
    "it|Italian", "ar|Arabic", "hi|Hindi", "th|Thai", "vi|Vietnamese", "id|Indonesian",
    "ms|Malay", "tr|Turkish", "pl|Polish", "nl|Dutch", "sv|Swedish", "da|Danish",
    "no|Norwegian", "fi|Finnish", "cs|Czech", "sk|Slovak", "hu|Hungarian", "ro|Romanian",
    "bg|Bulgarian", "el|Greek", "he|Hebrew", "fa|Persian", "uk|Ukrainian", "sr|Serbian",
    "hr|Croatian", "sl|Slovenian", "lt|Lithuanian", "lv|Latvian", "et|Estonian", "ca|Catalan",
    "fil|Filipino", "bn|Bengali", "ta|Tamil", "te|Telugu", "ur|Urdu", "sw|Swahili",
    "af|Afrikaans", "sq|Albanian", "hy|Armenian", "az|Azerbaijani", "be|Belarusian",
    "bs|Bosnian", "eu|Basque", "gl|Galician", "ka|Georgian", "gu|Gujarati", "is|Icelandic",
    "kn|Kannada", "kk|Kazakh", "km|Khmer", "ky|Kyrgyz", "lo|Lao", "mk|Macedonian",
    "ml|Malayalam", "mn|Mongolian", "mr|Marathi", "my|Burmese", "ne|Nepali", "pa|Punjabi",
    "si|Sinhala", "tg|Tajik", "uz|Uzbek", "cy|Welsh", "ga|Irish", "mt|Maltese",
    "mi|Maori", "sm|Samoan", "sn|Shona", "so|Somali", "st|Sesotho", "su|Sundanese",
    "mg|Malagasy", "ha|Hausa", "ig|Igbo", "yo|Yoruba", "zu|Zulu", "xh|Xhosa",
    "yi|Yiddish", "jw|Javanese", "ceb|Cebuano", "haw|Hawaiian", "hmn|Hmong", "ny|Chichewa",
    "co|Corsican", "eo|Esperanto", "fy|Frisian", "gd|Scots Gaelic", "ht|Haitian Creole",
    "ku|Kurdish", "lb|Luxembourgish", "la|Latin", "ps|Pashto", "sd|Sindhi", "tl|Filipino"
};

// ============================== 字符串工具 ==============================

string byteToStr(uint8 b)
{
    string s = "";
    s.resize(1);
    s[0] = b;
    return s;
}

bool IsSpaceByte(uint8 c)
{
    return c == 0x20 || (c >= 0x09 && c <= 0x0D);
}

// 去掉首尾空白（自行实现，避免依赖 Trim() 在不同版本里的返回语义）
string StrTrim(const string &in s)
{
    uint i = 0;
    uint j = s.length();
    while (i < j && IsSpaceByte(s[i])) i++;
    while (j > i && IsSpaceByte(s[j - 1])) j--;
    if (i == 0 && j == s.length()) return s;
    return s.substr(i, int(j - i));
}

// 只做 ASCII 大小写转换（足以用于配置项与关键字比较）
string ToLowerStr(const string &in s)
{
    string o = s;
    for (uint i = 0; i < o.length(); i++)
    {
        uint8 c = o[i];
        if (c >= 0x41 && c <= 0x5A) o[i] = uint8(c + 0x20);
    }
    return o;
}

bool StartsWith(const string &in s, const string &in p)
{
    if (p.length() == 0) return true;
    if (s.length() < p.length()) return false;
    return s.substr(0, int(p.length())) == p;
}

bool EndsWith(const string &in s, const string &in p)
{
    if (p.length() == 0) return true;
    if (s.length() < p.length()) return false;
    return s.substr(int(s.length() - p.length())) == p;
}

bool StartsWithCI(const string &in s, const string &in p)
{
    if (s.length() < p.length()) return false;
    return ToLowerStr(s.substr(0, int(p.length()))) == ToLowerStr(p);
}

// 去掉整体包裹的成对符号，例如 "译文" / “译文” / **译文**
string StripWrapped(const string &in text, const string &in open, const string &in close)
{
    string t = StrTrim(text);
    if (t.length() > open.length() + close.length() && StartsWith(t, open) && EndsWith(t, close))
        t = StrTrim(t.substr(int(open.length()), int(t.length() - open.length() - close.length())));
    return t;
}

bool IsDigitsOnly(const string &in s)
{
    bool seen = false;
    for (uint i = 0; i < s.length(); i++)
    {
        uint8 c = s[i];
        if (c >= 0x30 && c <= 0x39) { seen = true; continue; }
        if (c == 0x20 || c == 0x2E || c == 0x2C || c == 0x2D || c == 0x3A || c == 0x2F) continue; // 空格 . , - : /
        return false;
    }
    return seen;
}

bool IsNumStr(const string &in s)
{
    string t = StrTrim(s);
    if (t.length() == 0) return false;
    uint i = 0;
    if (t[0] == 0x2D) i = 1;                          // '-'
    if (i >= t.length()) return false;
    bool seen = false;
    for (; i < t.length(); i++)
    {
        uint8 c = t[i];
        if (c < 0x30 || c > 0x39) return false;
        seen = true;
    }
    return seen;
}

bool IsDecimalStr(const string &in s)
{
    string t = StrTrim(s);
    if (t.length() == 0) return false;
    uint i = 0;
    if (t[0] == 0x2D) i = 1;                          // '-'
    bool seen = false;
    bool dot = false;
    for (; i < t.length(); i++)
    {
        uint8 c = t[i];
        if (c == 0x2E)                                    // '.'
        {
            if (dot) return false;
            dot = true;
            continue;
        }
        if (c < 0x30 || c > 0x39) return false;
        seen = true;
    }
    return seen;
}

int ParseIntA(const string &in s, int def)
{
    string t = StrTrim(s);
    if (t.length() == 0) return def;
    uint i = 0;
    bool neg = false;
    if (t[0] == 0x2D) { neg = true; i = 1; }
    int val = 0;
    bool seen = false;
    for (; i < t.length(); i++)
    {
        uint8 c = t[i];
        if (c < 0x30 || c > 0x39) return def;
        val = val * 10 + int(c - 0x30);
        seen = true;
        if (val > 100000000) return def;
    }
    if (!seen) return def;
    return neg ? -val : val;
}

string JsonEscape(const string &in input)
{
    string res = input;
    res.replace("\\", "\\\\");
    res.replace("\"", "\\\"");
    res.replace("\n", "\\n");
    res.replace("\r", "\\r");
    res.replace("\t", "\\t");
    return res;
}

array<string> SplitLines(const string &in s)
{
    array<string> res;
    string cur = "";
    for (uint i = 0; i < s.length(); i++)
    {
        uint8 c = s[i];
        if (c == 10)
        {
            res.insertLast(cur);
            cur = "";
        }
        else if (c != 13)
        {
            cur += byteToStr(c);
        }
    }
    res.insertLast(cur);
    return res;
}

// 是否包含值得翻译的内容（纯数字、纯符号、纯音乐符号等直接跳过）
bool HasTranslatableContent(const string &in s)
{
    string t = StrTrim(s);
    if (t.length() == 0) return false;
    if (IsDigitsOnly(t)) return false;
    for (uint i = 0; i < t.length(); i++)
    {
        uint8 c = t[i];
        if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) return true;   // 拉丁字母
        if (c >= 0xE4 && c <= 0xE9) return true;                                 // CJK 汉字
        if (c == 0xE3) return true;                                              // 假名/日文标点
        if (c == 0xEA || c == 0xEB || c == 0xEC) return true;                    // 韩文
        if (c == 0xD0 || c == 0xD1) return true;                                 // 西里尔字母
        if (c == 0xD8 || c == 0xD9) return true;                                 // 阿拉伯文
        if (c == 0xE0) return true;                                              // 泰文/希伯来文等
    }
    return false;
}

// ============================== 幻觉/静音字幕拦截 ==============================

// 解析幻觉拦截词配置（按行分割，去空白，转小写）
void ParseHallucinationPatterns()
{
    HALLUCINATION_LIST.resize(0);
    string patterns = StrTrim(CFG_HALLUCINATION_PATTERNS);
    if (patterns.length() == 0) return;
    array<string> lines = SplitLines(patterns);
    for (uint i = 0; i < lines.length(); i++)
    {
        string line = StrTrim(lines[i]);
        if (line.length() > 0)
        {
            HALLUCINATION_LIST.insertLast(ToLowerStr(line));
        }
    }
}

// 判断字符是否为单词边界（空白、标点、字符串开头/结尾）
bool IsWordBoundary(const string &in text, int pos)
{
    if (pos <= 0) return true;  // 字符串开头
    if (pos >= int(text.length())) return true;  // 字符串结尾
    uint8 c = text[pos];
    // 空白字符
    if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) return true;
    // 常见标点
    if (c == 0x2C || c == 0x2E || c == 0x3A || c == 0x3B || c == 0x3F || c == 0x21  // , . : ; ? !
        || c == 0x28 || c == 0x29 || c == 0x5B || c == 0x5D || c == 0x7B || c == 0x7D  // ( ) [ ] { }
        || c == 0x22 || c == 0x27 || c == 0x60  // " ' `
        || c == 0x2D || c == 0x5F  // - _
        || c == 0x2F || c == 0x5C  // / \
        || c == 0x7C || c == 0x40 || c == 0x23 || c == 0x24 || c == 0x25 || c == 0x5E || c == 0x26 || c == 0x2A  // | @ # $ % ^ & *
        || c == 0x3D || c == 0x2B || c == 0x3C || c == 0x3E) return true;  // = + < >
    // 中文标点
    if (c == 0xE3) return true;  // 日文标点区段开头
    if (c == 0xEF) return true;  // 全角标点区段开头
    return false;
}

// 检查文本中是否包含模式作为完整词/短语（边界匹配）
bool ContainsPatternWithBoundary(const string &in text, const string &in pattern)
{
    int pos = text.find(pattern);
    while (pos != -1)
    {
        int endPos = pos + pattern.length();
        bool leftOk = (pos == 0) || IsWordBoundary(text, pos - 1);
        bool rightOk = (endPos >= int(text.length())) || IsWordBoundary(text, endPos);
        if (leftOk && rightOk) return true;
        pos = text.find(pattern, pos + 1);
    }
    return false;
}

// 判断文本是否为常见幻觉/静音字幕（如"谢谢观看"、"[Music]"等）
bool IsHallucination(const string &in text)
{
    if (!CFG_BLOCK_HALLUCINATIONS) return false;
    string t = ToLowerStr(StrTrim(text));
    if (t.length() == 0) return false;
    
    // 1. 精确匹配整行（最高优先级）
    for (uint i = 0; i < HALLUCINATION_LIST.length(); i++)
    {
        if (t == HALLUCINATION_LIST[i]) return true;
    }
    
    // 2. 单行文本且长度较短时，尝试边界匹配
    // 只有当文本不包含换行符，且长度在合理范围内时才做边界匹配
    // 避免在长句子中误匹配
    if (t.find("\n") == -1 && t.length() <= 120)
    {
        for (uint i = 0; i < HALLUCINATION_LIST.length(); i++)
        {
            string pattern = HALLUCINATION_LIST[i];
            if (pattern.length() >= 2 && ContainsPatternWithBoundary(t, pattern))
            {
                return true;
            }
        }
    }
    
    // 3. 特殊模式：纯音乐/音效符号、括号内容
    // 单独处理 [music]、[音乐]、♪ 等
    array<string> specialPatterns;
    specialPatterns.insertLast("[music]");
    specialPatterns.insertLast("[音乐]");
    specialPatterns.insertLast("♪");
    specialPatterns.insertLast("♫");
    specialPatterns.insertLast("🎵");
    specialPatterns.insertLast("🎶");
    specialPatterns.insertLast("[bgm]");
    specialPatterns.insertLast("[background music]");
    specialPatterns.insertLast("[sound effect]");
    specialPatterns.insertLast("[sfx]");
    specialPatterns.insertLast("[applause]");
    specialPatterns.insertLast("[掌声]");
    specialPatterns.insertLast("[laughter]");
    specialPatterns.insertLast("[笑声]");
    specialPatterns.insertLast("[silence]");
    specialPatterns.insertLast("[静音]");
    specialPatterns.insertLast("[no speech]");
    specialPatterns.insertLast("[无语音]");
    specialPatterns.insertLast("(music)");
    specialPatterns.insertLast("(音乐)");
    specialPatterns.insertLast("(bgm)");
    specialPatterns.insertLast("(sound effect)");
    specialPatterns.insertLast("♪♪");
    specialPatterns.insertLast("♫♫");
    specialPatterns.insertLast("🎵🎵");
    specialPatterns.insertLast("🎶🎶");
    for (uint i = 0; i < specialPatterns.length(); i++)
    {
        if (t.find(specialPatterns[i]) != -1) return true;
    }
    
    // 4. 重复字符检测（如 "啊啊啊啊"、"哈哈哈哈"、"wwww"、"23333"）
    if (t.length() >= 4)
    {
        uint8 firstChar = t[0];
        bool allSame = true;
        for (uint i = 1; i < t.length(); i++)
        {
            if (t[i] != firstChar && t[i] != 0x20) { allSame = false; break; }
        }
        if (allSame) return true;
    }
    
    return false;
}

// 检查是否为重复字幕且在最小间隔内
bool IsDuplicateTooSoon(const string &in source)
{
    if (CFG_MIN_INTERVAL_MS <= 0) return false;
    string trimmed = StrTrim(source);
    uint tlen = trimmed.length();
    if (tlen == 0) return false;
    if (trimmed != LAST_SOURCE) return false;
    uint now = HostGetTickCount();
    return (now - LAST_TRANSLATE_TICK) < uint(CFG_MIN_INTERVAL_MS);
}

// 日志落盘：控制台窗口不好复制，写文件后可以直接排查（只保留最近约 24KB）
void AppendLog(const string &in line)
{
    LOG_SEQ++;
    LOG_BUF += formatInt(LOG_SEQ) + "> " + line + "\n";

    if (int(LOG_BUF.length()) > 24000)
    {
        int nl = int(LOG_BUF.find("\n"));
        if (nl >= 0) LOG_BUF = LOG_BUF.substr(nl + 1);
    }

    string path = "aitrans_log.txt";
    if (HostFileExist(path)) HostFileDelete(path);
    uintptr fp = HostFileCreate(path);
    if (fp == 0) return;
    HostFileWrite(fp, LOG_BUF);
    HostFileClose(fp);
}

void Log(const string &in msg)
{
    if (CFG_DEBUG) HostPrintUTF8("[AI Translate] " + msg + "\n");
    if (CFG_LOGFILE) AppendLog(msg);     // 控制台和日志文件是两个独立开关
}

// 是否是本地模型服务（只有本地模型才需要"保活"与"预热"）
bool IsLocalUrl(const string &in url)
{
    string u = ToLowerStr(url);
    if (u.find("127.0.0.1") != -1) return true;
    if (u.find("localhost") != -1) return true;
    if (u.find("0.0.0.0") != -1) return true;
    if (u.find("[::1]") != -1) return true;
    return false;
}

// 覆盖写文本文件
bool WriteTextFile(const string &in path, const string &in content)
{
    if (HostFileExist(path)) HostFileDelete(path);
    uintptr fp = HostFileCreate(path);
    if (fp == 0) return false;
    HostFileWrite(fp, content);
    HostFileClose(fp);
    return true;
}

// 本地大模型首次加载需要 10~20 秒，超过 PotPlayer 单次请求的等待上限（约 8.5 秒），
// 于是请求必然失败，而服务端一旦发现客户端断开就会取消加载，导致"永远加载不上"。
// 所以这里另起一个隐藏的后台进程去预热：让模型先在内存里加载好，
// 之后 PotPlayer 发出的请求就都是 1~3 秒的快请求了。
//   keep_alive 让模型加载后长期常驻，避免反复冷启动。
void LaunchWarmup()
{
    if (!CFG_AUTOWARMUP) { WARM_STATUS = "off (autoWarmup=false)"; return; }
    if (CFG_URL.length() == 0 || CFG_MODEL.length() == 0) { WARM_STATUS = "skip (no model/url)"; return; }
    if (!IsLocalUrl(CFG_URL)) { WARM_STATUS = "skip (not a local url)"; return; }

    uint now = HostGetTickCount();
    if (WARM_LAUNCHED && (now - WARM_TICK) < 30000) return;   // 30 秒内最多触发一次
    WARM_TICK = now;
    WARM_LAUNCHED = true;

    // 注意：HostFileCreate/HostFileDelete 只接受"配置目录内的相对路径"，
    // 绝对路径和 .. 都会被拒（api.txt 明确写了）。所以：
    //   · 写文件用相对文件名（落在 HostGetConfigFolder() 里）
    //   · 给 curl 用的路径用 HostGetConfigFolder() 拼出的绝对路径
    string dir = HostGetConfigFolder();
    if (dir.length() == 0) { WARM_STATUS = "fail (no config folder)"; return; }
    if (dir[dir.length() - 1] != 0x5C) dir += "\\";            // 补 '\'

    string payload = "{\"model\":\"" + JsonEscape(CFG_MODEL)
                   + "\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]"
                   + ",\"stream\":false,\"max_tokens\":1";
    string ka = StrTrim(CFG_KEEPALIVE);
    if (ka.length() > 0) payload += ",\"keep_alive\":\"" + JsonEscape(ka) + "\"";
    payload += "}";

    string pname = "aitrans_warmup.json";
    string vname = "aitrans_warmup.vbs";
    string pfile = dir + pname;                                // 绝对路径，给 curl
    string vfile = dir + vname;                                // 绝对路径，给 wscript
    if (!WriteTextFile(pname, payload)) { WARM_STATUS = "fail (write " + pfile + ")"; return; }

    // 生成一个隐藏运行的 VBS（用 Chr(34) 拼引号，避开 VBS 里 " 的转义坑）
    string vbs = "On Error Resume Next\r\n"
               + "Set sh = CreateObject(\"WScript.Shell\")\r\n"
               + "q = Chr(34)\r\n"
               + "exe = sh.ExpandEnvironmentStrings(\"%SystemRoot%\") & \"\\System32\\curl.exe\"\r\n"
               + "cmd = q & exe & q & \" -s -m 300 -X POST \" & q & \"" + CFG_URL + "\" & q"
               + " & \" -H \" & q & \"Content-Type: application/json\" & q"
               + " & \" --data-binary \" & q & \"@" + pfile + "\" & q & \" -o NUL\"\r\n"
               + "sh.Run cmd, 0, False\r\n";
    if (!WriteTextFile(vname, vbs)) { WARM_STATUS = "fail (write " + vfile + ")"; return; }

    string rc = HostExecuteProgram("wscript.exe", "\"" + vfile + "\"");
    WARM_STATUS = "launched rc=" + formatInt(int(rc.length())) + " file=" + vfile;
    Log("已启动后台预热进程: " + CFG_MODEL + " @ " + CFG_URL);
}

// ============================== 配置文件 ==============================

string ReadTextFile(const string &in path)
{
    uintptr fp = HostFileOpen(path);
    if (fp == 0) return "";
    int64 len = HostFileLength(fp);
    string data = "";
    if (len > 0) data = HostFileRead(fp, int(len));
    HostFileClose(fp);
    // 去掉 UTF-8 BOM
    if (data.length() >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF)
        data = data.substr(3);
    return data;
}

void LoadConfigDefaults()
{
    FILE_MODEL         = "deepseek-chat";
    FILE_URL           = "https://api.deepseek.com/v1/chat/completions";
    FILE_KEY           = "";
    FILE_TEMP          = "0.2";
    FILE_MAXTOKENS     = "0";
    FILE_TARGET        = "zh-CN";
    FILE_AUTH_HEADER   = "Authorization: Bearer {key}";
    FILE_SYSTEM_PROMPT = "";
    FILE_GLOSSARY      = "";
    FILE_EXTRA_HEADERS = "";
    FILE_CONTEXT       = 3;
    FILE_DELAY_MS      = 0;
    FILE_RETRY         = 1;
    FILE_TIMEOUT_MS    = 20000;
    FILE_MINCHARS      = 0;
    FILE_CACHE         = true;
    FILE_KEEP_ORIG     = true;
    FILE_DEBUG         = false;
    FILE_LOGFILE       = false;
    FILE_KEEPALIVE     = "24h";
    FILE_AUTOWARMUP    = true;
}

// 在配置文件中按类型取值，尽量不使用 JsonValue.asInt()(类型不符会报警)
string JsonText(const string &in json, const string &in key, const string &in def)
{
    JsonReader reader;
    JsonValue root;
    string doc = json;                 // parse() 需要非 const 引用，这里拷一份
    if (!reader.parse(doc, root) || !root.isObject()) return def;
    JsonValue v = root[key];
    if (v.isString()) return StrTrim(v.asString());
    if (v.isBool()) return v.asBool() ? "true" : "false";
    if (v.isNumeric() && v.canString()) return StrTrim(v.asString());
    return def;
}

void LoadConfigFile()
{
    LoadConfigDefaults();

    // 依次尝试：扩展目录旁的同名文件 -> PotPlayer 配置目录里的同名文件（相对路径）
    string folder = HostGetScriptFolder();
    if (folder.length() > 0 && folder[folder.length() - 1] != 0x5C) folder += "\\";
    string path = folder + "ai-translate.json";
    string json = "";
    if (HostFileExist(path))
    {
        json = ReadTextFile(path);
        CFG_SOURCE = "script folder";
    }
    else
    {
        // 写文件 API 的“相对路径”落在 PotPlayer 的配置目录，这里也按同样规则找一遍
        json = ReadTextFile("ai-translate.json");
        path = "ai-translate.json (config folder: " + HostGetConfigFolder() + ")";
        CFG_SOURCE = "config folder";
    }

    if (json.length() == 0)
    {
        CFG_SOURCE = "none (built-in defaults)";
        Log("没有读到配置文件，使用内置默认值 / no config file found, using built-in defaults");
        return;
    }

    JsonReader reader;
    JsonValue root;
    if (!reader.parse(json, root) || !root.isObject())
    {
        AppendLog("配置文件 JSON 解析失败: " + path);
        CFG_SOURCE = "parse error";
        LoadConfigDefaults();
        return;
    }

    FILE_MODEL         = JsonText(json, "model", FILE_MODEL);
    FILE_URL           = JsonText(json, "apiUrl", FILE_URL);
    FILE_KEY           = JsonText(json, "apiKey", FILE_KEY);
    FILE_TEMP          = JsonText(json, "temperature", FILE_TEMP);
    FILE_MAXTOKENS     = JsonText(json, "maxTokens", FILE_MAXTOKENS);
    FILE_TARGET        = JsonText(json, "defaultTargetLang", FILE_TARGET);
    FILE_AUTH_HEADER   = JsonText(json, "authHeader", FILE_AUTH_HEADER);
    FILE_SYSTEM_PROMPT = JsonText(json, "systemPrompt", FILE_SYSTEM_PROMPT);
    FILE_GLOSSARY      = JsonText(json, "glossary", FILE_GLOSSARY);
    FILE_EXTRA_HEADERS = JsonText(json, "extraHeaders", FILE_EXTRA_HEADERS);
    FILE_CONTEXT       = ParseIntA(JsonText(json, "contextLines", formatInt(FILE_CONTEXT)), FILE_CONTEXT);
    FILE_DELAY_MS      = ParseIntA(JsonText(json, "delayMs", formatInt(FILE_DELAY_MS)), FILE_DELAY_MS);
    FILE_RETRY         = ParseIntA(JsonText(json, "retries", formatInt(FILE_RETRY)), FILE_RETRY);
    FILE_TIMEOUT_MS    = ParseIntA(JsonText(json, "timeoutMs", formatInt(FILE_TIMEOUT_MS)), FILE_TIMEOUT_MS);
    FILE_MINCHARS      = ParseIntA(JsonText(json, "minChars", formatInt(FILE_MINCHARS)), FILE_MINCHARS);
    FILE_KEEPALIVE     = JsonText(json, "keepAlive", FILE_KEEPALIVE);

    // 幻觉/静音字幕过滤
    string s;
    s = ToLowerStr(JsonText(json, "blockHallucinations", "true"));
    FILE_BLOCK_HALLUCINATIONS = (s != "false" && s != "0" && s != "no");
    FILE_MIN_INTERVAL_MS      = ParseIntA(JsonText(json, "minIntervalMs", formatInt(FILE_MIN_INTERVAL_MS)), FILE_MIN_INTERVAL_MS);
    FILE_MAX_GAP_MS           = ParseIntA(JsonText(json, "maxGapMs", formatInt(FILE_MAX_GAP_MS)), FILE_MAX_GAP_MS);
    FILE_HALLUCINATION_PATTERNS = JsonText(json, "hallucinationPatterns", FILE_HALLUCINATION_PATTERNS);

    s = ToLowerStr(JsonText(json, "cache", "true"));
    FILE_CACHE = (s != "false" && s != "0" && s != "no");
    s = ToLowerStr(JsonText(json, "keepOriginalOnFailure", "true"));
    FILE_KEEP_ORIG = (s != "false" && s != "0" && s != "no");
    s = ToLowerStr(JsonText(json, "debug", "false"));
    FILE_DEBUG = (s == "true" || s == "1" || s == "yes");
    s = ToLowerStr(JsonText(json, "logFile", "false"));
    FILE_LOGFILE = (s == "true" || s == "1" || s == "yes");
    s = ToLowerStr(JsonText(json, "autoWarmup", "true"));
    FILE_AUTOWARMUP = (s != "false" && s != "0" && s != "no");

    Log("已加载配置文件: " + path);
}

string LoadOverride(const string &in key, const string &in fileVal)
{
    string v = HostLoadString(key, UNSET_MARK);
    if (v == UNSET_MARK) return fileVal;
    return v;
}

// 规范化接口地址：补全 /v1/chat/completions，去掉结尾多余的 '/'
string NormalizeUrl(const string &in url)
{
    string u = StrTrim(url);
    while (u.length() > 0 && u[u.length() - 1] == 0x2F) u = u.substr(0, int(u.length() - 1));   // 去掉结尾 '/'
    if (u.find("chat/completions") != -1) return u;

    // 只写了主机名，例如 https://api.deepseek.com -> 补 /v1/chat/completions
    int scheme = u.find("://");
    int hostEnd = (scheme == -1) ? u.find("/") : u.find("/", scheme + 3);
    if (hostEnd == -1) return u + "/v1/chat/completions";

    // 只写到 /v1 -> 补 /chat/completions
    if (EndsWith(u, "/v1")) return u + "/chat/completions";
    return u;
}

// 把“文件默认值 + 对话框设置”合成为最终配置
void RefreshConfig()
{
    CFG_MODEL       = StrTrim(LoadOverride("aitrans_model", FILE_MODEL));
    CFG_URL         = NormalizeUrl(LoadOverride("aitrans_url", FILE_URL));
    CFG_KEY         = StrTrim(LoadOverride("aitrans_key", FILE_KEY));
    CFG_TEMP        = StrTrim(LoadOverride("aitrans_temp", FILE_TEMP));
    CFG_MAXTOKENS   = StrTrim(LoadOverride("aitrans_maxtokens", FILE_MAXTOKENS));
    CFG_CONTEXT     = ParseIntA(LoadOverride("aitrans_context", formatInt(FILE_CONTEXT)), FILE_CONTEXT);
    CFG_DELAY_MS    = ParseIntA(LoadOverride("aitrans_delay", formatInt(FILE_DELAY_MS)), FILE_DELAY_MS);
    CFG_RETRY       = ParseIntA(LoadOverride("aitrans_retry", formatInt(FILE_RETRY)), FILE_RETRY);

    CFG_TARGET      = FILE_TARGET;
    CFG_AUTH_HEADER = FILE_AUTH_HEADER;
    CFG_SYSPROMPT   = FILE_SYSTEM_PROMPT;
    CFG_GLOSSARY    = FILE_GLOSSARY;
    CFG_EXTRAHDR    = FILE_EXTRA_HEADERS;
    CFG_TIMEOUT_MS  = FILE_TIMEOUT_MS;
    CFG_MINCHARS    = FILE_MINCHARS;
    CFG_CACHE       = FILE_CACHE;
    CFG_KEEP_ORIG   = FILE_KEEP_ORIG;
    CFG_DEBUG       = FILE_DEBUG;
    CFG_LOGFILE     = FILE_LOGFILE;
    CFG_KEEPALIVE   = FILE_KEEPALIVE;
    CFG_AUTOWARMUP  = FILE_AUTOWARMUP;

    // 幻觉/静音字幕过滤
    CFG_BLOCK_HALLUCINATIONS = FILE_BLOCK_HALLUCINATIONS;
    CFG_MIN_INTERVAL_MS      = FILE_MIN_INTERVAL_MS;
    CFG_MAX_GAP_MS           = FILE_MAX_GAP_MS;
    CFG_HALLUCINATION_PATTERNS = FILE_HALLUCINATION_PATTERNS;

    if (CFG_CONTEXT < 0)    CFG_CONTEXT = 0;
    if (CFG_CONTEXT > 20)   CFG_CONTEXT = 20;
    if (CFG_DELAY_MS < 0)   CFG_DELAY_MS = 0;
    if (CFG_DELAY_MS > 10000) CFG_DELAY_MS = 10000;
    if (CFG_RETRY < 0)      CFG_RETRY = 0;
    if (CFG_RETRY > 5)      CFG_RETRY = 5;
    if (CFG_TIMEOUT_MS < 1000)   CFG_TIMEOUT_MS = 1000;
    if (CFG_TIMEOUT_MS > 120000) CFG_TIMEOUT_MS = 120000;
    if (CFG_MINCHARS < 0)   CFG_MINCHARS = 0;
    if (CFG_MIN_INTERVAL_MS < 0) CFG_MIN_INTERVAL_MS = 0;
    if (CFG_MIN_INTERVAL_MS > 10000) CFG_MIN_INTERVAL_MS = 10000;
    if (CFG_MAX_GAP_MS < 0) CFG_MAX_GAP_MS = 0;
    if (CFG_MAX_GAP_MS > 120000) CFG_MAX_GAP_MS = 120000;

    // 解析幻觉拦截词列表
    ParseHallucinationPatterns();
}

// ============================== 语言 ==============================

array<string> BuildLangList(bool withAuto)
{
    array<string> res;
    if (withAuto) res.insertLast("");
    for (uint i = 0; i < LangTable.length(); i++)
    {
        string entry = LangTable[i];
        int p = entry.find("|");
        if (p > 0) res.insertLast(entry.substr(0, p));
    }
    return res;
}

string LangName(const string &in code)
{
    if (code.length() == 0) return "the original language (auto-detected)";
    for (uint i = 0; i < LangTable.length(); i++)
    {
        string entry = LangTable[i];
        int p = entry.find("|");
        if (p > 0 && entry.substr(0, p) == code)
            return entry.substr(p + 1);
    }
    return code;
}

array<string> GetSrcLangs()
{
    return BuildLangList(true);
}

array<string> GetDstLangs()
{
    return BuildLangList(false);
}

// ============================== ASS 标签保护 ==============================
// 形如 {\an8}{\pos(..)} 的样式标签在翻译前替换成 [[n]]，翻译后还原，避免被模型改写。

string ProtectTags(const string &in text, array<string> &inout tags)
{
    string res = "";
    string cur = "";
    bool inTag = false;
    for (uint i = 0; i < text.length(); i++)
    {
        uint8 c = text[i];
        if (!inTag && c == 0x7B)                 // '{'
        {
            inTag = true;
            cur = "{";
            continue;
        }
        if (inTag)
        {
            cur += byteToStr(c);
            if (c == 0x7D)                       // '}'
            {
                inTag = false;
                int idx = int(tags.length());
                tags.insertLast(cur);
                res += TAG_OPEN + formatInt(idx) + TAG_CLOSE;
                cur = "";
            }
            continue;
        }
        res += byteToStr(c);
    }
    if (inTag) res += cur;                       // 未闭合的标签原样保留
    return res;
}

string RestoreTags(const string &in text, array<string> &in tags)
{
    string res = text;
    for (uint i = 0; i < tags.length(); i++)
    {
        string token = TAG_OPEN + formatInt(int(i)) + TAG_CLOSE;
        int p = res.find(token);
        if (p != -1)
            res = res.substr(0, p) + tags[i] + res.substr(uint(p) + token.length());
    }
    return res;
}

// ============================== 请求 / 响应 ==============================

string BuildHeaders()
{
    string h = "Content-Type: application/json\r\n";
    string key = CFG_KEY;
    string lowerKey = ToLowerStr(key);
    if (key.length() > 0 && lowerKey != "nullkey" && key != "-")
    {
        string auth = StrTrim(CFG_AUTH_HEADER);
        if (auth.length() > 0)
        {
            string filled = auth;
            int p = filled.find("{key}");
            if (p != -1)
                filled = filled.substr(0, p) + key + filled.substr(p + 5);
            else
                filled = filled + " " + key;
            h += filled + "\r\n";
        }
    }
    if (StrTrim(CFG_EXTRAHDR).length() > 0)
    {
        array<string> lines = SplitLines(CFG_EXTRAHDR);
        for (uint i = 0; i < lines.length(); i++)
        {
            string line = StrTrim(lines[i]);
            if (line.length() > 0) h += line + "\r\n";
        }
    }
    return h;
}

string BuildPayload(const string &in systemMsg, const string &in userMsg)
{
    string p = "{\"model\":\"" + JsonEscape(CFG_MODEL) + "\"";
    p += ",\"messages\":[{\"role\":\"system\",\"content\":\"" + JsonEscape(systemMsg) + "\"}"
       + ",{\"role\":\"user\",\"content\":\"" + JsonEscape(userMsg) + "\"}]";
    p += ",\"stream\":false";
    if (IsDecimalStr(CFG_TEMP))
        p += ",\"temperature\":" + CFG_TEMP;
    if (IsNumStr(CFG_MAXTOKENS) && ParseIntA(CFG_MAXTOKENS, 0) > 0)
        p += ",\"max_tokens\":" + CFG_MAXTOKENS;
    string ka = StrTrim(CFG_KEEPALIVE);
    if (ka.length() > 0 && IsLocalUrl(CFG_URL))
        p += ",\"keep_alive\":\"" + JsonEscape(ka) + "\"";
    p += "}";
    return p;
}

// 给 potplayer 脚本增加本次调用的超时余量（大模型接口通常需要数秒）
void ExtendTimeout()
{
    HostIncTimeOut(CFG_TIMEOUT_MS);
}

// 单个请求；成功返回译文，失败返回空并把原因写到 errMsg
string RequestOnce(const string &in systemMsg, const string &in userMsg, string &inout errMsg)
{
    errMsg = "";
    ExtendTimeout();

    string headers = BuildHeaders();
    string payload = BuildPayload(systemMsg, userMsg);
    Log("POST " + CFG_URL + " model=" + CFG_MODEL);
    Log("payload=" + payload);

    uint t0 = HostGetTickCount();
    string response = HostUrlGetString(CFG_URL, USER_AGENT, headers, payload);
    uint used = HostGetTickCount() - t0;
    if (response.length() == 0)
    {
        if (IsLocalUrl(CFG_URL))
        {
            LaunchWarmup();
            errMsg = "no response in " + formatInt(int(used)) + "ms - the local model is probably not loaded yet"
                   + " (cold load needs 10-20s, longer than PotPlayer's ~8.5s request limit)."
                   + " warmup=" + WARM_STATUS + "; wait ~15s and retry, or run tools\\warmup-ollama.bat once"
                   + " (equivalent: ollama run --keepalive 24h " + CFG_MODEL + " 'hi'). Check with: ollama ps";
        }
        else
        {
            errMsg = "no response in " + formatInt(int(used)) + "ms (network/timeout/bad url/blocked)";
        }
        return "";
    }
    string brief = response;
    if (int(brief.length()) > 500) brief = brief.substr(0, 500) + "...";
    Log("response(" + formatInt(int(used)) + "ms, " + formatInt(int(response.length())) + " bytes)=" + brief);

    JsonReader reader;
    JsonValue root;
    if (!reader.parse(response, root) || !root.isObject())
    {
        errMsg = "response is not valid JSON: " + response.substr(0, 300);
        return "";
    }

    // 错误信息
    JsonValue err = root["error"];
    if (err.isObject() && err["message"].isString())
        errMsg = err["message"].asString();
    else if (err.isString())
        errMsg = err.asString();
    if (errMsg.length() > 0)
    {
        // 部分接口把错误放在 choices 里，这里仍尝试继续取值
        if (errMsg.length() > 300) errMsg = errMsg.substr(0, 300);
    }

    string content = "";
    JsonValue choices = root["choices"];
    if (choices.isArray() && choices.size() > 0)
    {
        JsonValue c0 = choices[0];
        if (c0.isObject())
        {
            JsonValue msg = c0["message"];
            if (msg.isObject())
            {
                JsonValue ct = msg["content"];
                if (ct.isString())
                {
                    content = ct.asString();
                }
                else if (ct.isArray())            // 少数接口返回 [{type:text,text:...}]
                {
                    for (int i = 0; i < ct.size(); i++)
                    {
                        JsonValue part = ct[i];
                        if (part.isObject() && part["text"].isString())
                            content += part["text"].asString();
                        else if (part.isString())
                            content += part.asString();
                    }
                }
            }
            if (content.length() == 0 && c0["text"].isString())
                content = c0["text"].asString();
            if (c0["finish_reason"].isString() && c0["finish_reason"].asString() == "length")
                Log("警告: 返回被 max_tokens 截断");
        }
    }
    if (content.length() == 0 && root["output_text"].isString())
        content = root["output_text"].asString();
    if (content.length() == 0 && errMsg.length() == 0)
        errMsg = "no translated text found in the response: " + response.substr(0, 300);

    return content;
}

// ============================== 结果清洗 ==============================

bool IsContextLine(const string &in line)
{
    string a = StrTrim(line);
    if (a.length() == 0) return false;
    for (uint i = 0; i < ContextLines.length(); i++)
    {
        if (StrTrim(ContextLines[i]) == a) return true;
    }
    return false;
}

string CleanOutput(const string &in raw, const string &in src)
{
    string t = raw;

    // 去掉思考内容（推理模型）
    int p = t.find("</think");
    if (p != -1)
    {
        int e = t.find(">", p);
        if (e != -1) t = t.substr(e + 1);
    }
    t = StrTrim(t);
    if (t.length() == 0) return t;

    // 去掉 >>> 之类的提示符
    while (t.length() > 0 && StartsWith(t, ">>>"))
        t = StrTrim(t.substr(3));

    // 去掉 “译文:” / “Translation:” 这类前缀（只看第一行）
    array<string> labels = {
        "translation:", "translated text:", "translated:", "translation -",
        "译文:", "译文：", "翻译:", "翻译：", "字幕:", "字幕：",
        "简体中文:", "简体中文：", "繁體中文:", "繁體中文：", "中文:", "中文：",
        "output:", "result:", "answer:"
    };
    for (uint i = 0; i < labels.length(); i++)
    {
        if (StartsWithCI(t, labels[i]))
        {
            string rest = StrTrim(t.substr(int(labels[i].length())));
            if (rest.length() > 0) t = rest;
            break;
        }
    }

    // 去掉整体包裹的引号 / 加粗
    t = StripWrapped(t, "\"", "\"");
    t = StripWrapped(t, "'", "'");
    t = StripWrapped(t, "**", "**");
    t = StripWrapped(t, "\u201C", "\u201D");
    t = StripWrapped(t, "\u2018", "\u2019");
    t = StripWrapped(t, "\u300C", "\u300D");
    t = StripWrapped(t, "\u300E", "\u300F");
    t = StripWrapped(t, "\u300A", "\u300B");

    // 逐行处理：去掉上下文回显、压缩空行
    array<string> lines = SplitLines(t);
    string res = "";
    bool lastBlank = false;
    for (uint i = 0; i < lines.length(); i++)
    {
        string line = StrTrim(lines[i]);
        if (line.length() == 0)
        {
            if (lastBlank) continue;
            lastBlank = true;
            if (res.length() > 0) res += "\n";
            continue;
        }
        if (IsContextLine(line)) continue;
        lastBlank = false;
        if (res.length() > 0 && !EndsWith(res, "\n")) res += "\n";
        res += line;
    }

    return StrTrim(res);
}

// 模型把原文又抄了一遍（没翻译）
bool IsEcho(const string &in translation, const string &in source)
{
    string a = ToLowerStr(StrTrim(translation));
    string b = ToLowerStr(StrTrim(source));
    if (a.length() == 0) return false;
    return a == b;
}

// 译文异常地长（幻觉）
bool LooksOverlong(const string &in translation, const string &in source)
{
    if (int(source.length()) < 12) return false;
    return int(translation.length()) > int(source.length()) * 6;
}

// ============================== 提示词 ==============================

string BuildSystemMsg(const string &in srcCode, const string &in dstCode, const string &in context)
{
    string srcLabel = LangName(srcCode);
    string dstLabel = LangName(dstCode);

    string msg = "";
    if (StrTrim(CFG_SYSPROMPT).length() > 0)
    {
        msg = StrTrim(CFG_SYSPROMPT);
        string a = msg;
        a.replace("{src}", srcLabel);
        a.replace("{dst}", dstLabel);
        msg = a;
    }
    else
    {
        msg = "You are a professional subtitle translator. Translate the user's subtitle line from "
            + srcLabel + " to " + dstLabel + ".\n"
            + "Rules:\n"
            + "1. Output ONLY the translation, without quotes, notes, explanations or romanization.\n"
            + "2. Never repeat, summarize or translate anything else.\n"
            + "3. Keep the original line breaks and keep the length close to the original.\n"
            + "4. Keep markers like [[0]], [[1]] unchanged, and keep stage directions such as [Music], (laughs) or a music note as they are.\n"
            + "5. Keep names, numbers, units and technical terms correct; do not add punctuation that is not there.";
    }

    if (StrTrim(CFG_GLOSSARY).length() > 0)
    {
        msg += "\nGlossary (must be followed exactly):";
        array<string> gl = SplitLines(CFG_GLOSSARY);
        for (uint i = 0; i < gl.length(); i++)
        {
            string g = StrTrim(gl[i]);
            if (g.length() > 0) msg += "\n" + g;
        }
    }

    if (context.length() > 0)
    {
        msg += "\nPrevious subtitle lines (context only, never translate or repeat them):\n" + context;
    }

    return msg;
}

// ============================== 缓存 ==============================

bool CacheGet(const string &in key, string &inout val)
{
    for (uint i = 0; i < CacheKeys.length(); i++)
    {
        if (CacheKeys[i] == key)
        {
            val = CacheVals[i];
            return true;
        }
    }
    return false;
}

void CachePut(const string &in key, const string &in val)
{
    if (CacheKeys.length() > 400)
    {
        for (uint i = 0; i < 200 && CacheKeys.length() > 0; i++)
        {
            CacheKeys.removeAt(0);
            CacheVals.removeAt(0);
        }
    }
    CacheKeys.insertLast(key);
    CacheVals.insertLast(val);
}

// ============================== 设置面板测试 ==============================

bool IsTestText(const string &in text)
{
    string t = ToLowerStr(text);
    if (t.find("potplayer can support online translation") != -1) return true;
    if (t.find("no longer have to wait") != -1) return true;
    if (text.find("实时字幕翻译测试") != -1) return true;
    return false;
}

// PotPlayer 弹出的消息框（“连通性测试”结果、登录框返回的提示）只按 **系统 ANSI 代码页**
// 解释脚本返回的字节；脚本里的中文是 UTF-8，直接返回就是乱码。而用 HostUTF8ToMBCS()
// 转成 GBK 后，字节又会被引擎再转一次，变成一堆替换字符（实测）。所以这类**没有
// {$CP936=...$} 标签**的弹窗统一用纯 ASCII 英文：中文说明放在控制台和 README 里。
// 带标签的文字（引擎名、面板标签）不受影响，交给 PotPlayer 自己按标签处理。
string BuildTestResult()
{
    bool noKey = (CFG_KEY.length() == 0 || ToLowerStr(CFG_KEY) == "nullkey");
    string keyState = "set";
    if (noKey) keyState = "none (local model: fill in nullkey)";
    string s = "[AI Translate] ready"
             + " | model=" + CFG_MODEL
             + " | url=" + CFG_URL
             + " | key=" + keyState
             + " | context=" + formatInt(CFG_CONTEXT)
             + " | warmup=" + WARM_STATUS;
    s += "\n[AI Translate] this test box only reports the settings; it does NOT call the model."
       + " The login button does a real one-shot request.";
    if (IsLocalUrl(CFG_URL))
        s += "\nlocal model: if the first request times out, run tools\\warmup-ollama.bat once"
           + " (or: ollama run --keepalive 24h " + CFG_MODEL + " 'hi'), wait about 15s and retry."
           + " 'ollama ps' must list " + CFG_MODEL + ".";
    return s;
}

// ============================== 登录（配置）==============================

// 登录框（面板）里的值优先于 ai-translate.json。这里列出真正生效的覆盖项，
// 免得出现“我改了配置文件但没生效”这种最费时间的排查。
string PanelNote()
{
    string n = "";
    if (CFG_MODEL != FILE_MODEL)         n += "model=" + CFG_MODEL + "(file=" + FILE_MODEL + ") ";
    if (CFG_URL != FILE_URL)             n += "url=" + CFG_URL + " ";
    if (CFG_KEY != FILE_KEY)             n += "key=(from panel) ";
    if (CFG_TEMP != FILE_TEMP)           n += "temp=" + CFG_TEMP + " ";
    if (CFG_MAXTOKENS != FILE_MAXTOKENS) n += "maxTokens=" + CFG_MAXTOKENS + "(file=" + FILE_MAXTOKENS + ") ";
    if (CFG_CONTEXT != FILE_CONTEXT)     n += "context=" + formatInt(CFG_CONTEXT) + "(file=" + formatInt(FILE_CONTEXT) + ") ";
    if (CFG_DELAY_MS != FILE_DELAY_MS)   n += "delayMs=" + formatInt(CFG_DELAY_MS) + " ";
    if (CFG_RETRY != FILE_RETRY)         n += "retries=" + formatInt(CFG_RETRY) + "(file=" + formatInt(FILE_RETRY) + ") ";
    if (n.length() == 0) return "none";
    return n;
}

string ServerLogin(string User, string Pass)
{
    RefreshConfig();

    string u = StrTrim(User);
    string p = StrTrim(Pass);

    // 复位：清除对话框里保存的配置，回到 ai-translate.json / 内置默认值
    if (ToLowerStr(u) == "-reset-")
    {
        HostSaveString("aitrans_model", UNSET_MARK);
        HostSaveString("aitrans_url", UNSET_MARK);
        HostSaveString("aitrans_key", UNSET_MARK);
        HostSaveString("aitrans_temp", UNSET_MARK);
        HostSaveString("aitrans_maxtokens", UNSET_MARK);
        HostSaveString("aitrans_context", UNSET_MARK);
        HostSaveString("aitrans_delay", UNSET_MARK);
        HostSaveString("aitrans_retry", UNSET_MARK);
        RefreshConfig();
        return "[AI Translate] panel cleared; now model=" + CFG_MODEL + " maxTokens=" + CFG_MAXTOKENS
             + " context=" + formatInt(CFG_CONTEXT) + " retries=" + formatInt(CFG_RETRY)
             + " (from ai-translate.json / built-in defaults)";
    }

    // 两个框都为空：不修改任何配置，仅报告当前状态
    if (u.length() == 0 && p.length() == 0)
    {
        if (CFG_URL.length() == 0 || CFG_MODEL.length() == 0)
            return "[AI Translate] not configured yet: model | apiUrl | temperature | contextLines | delayMs | retries | maxTokens";
        return "200 ok";
    }

    // “模型”栏：模型|接口地址|温度|上下文行数|延迟ms|重试次数|最大token
    array<string> parts = u.split("|");
    string v = "";
    if (parts.length() > 0)
    {
        v = StrTrim(parts[0]);
        if (v.length() > 0) HostSaveString("aitrans_model", v);
    }
    if (parts.length() > 1)
    {
        v = StrTrim(parts[1]);
        if (v.length() > 0) HostSaveString("aitrans_url", NormalizeUrl(v));
    }
    if (parts.length() > 2)
    {
        v = StrTrim(parts[2]);
        if (IsDecimalStr(v)) HostSaveString("aitrans_temp", v);
    }
    if (parts.length() > 3)
    {
        v = StrTrim(parts[3]);
        if (IsNumStr(v)) HostSaveString("aitrans_context", v);
    }
    if (parts.length() > 4)
    {
        v = StrTrim(parts[4]);
        if (IsNumStr(v)) HostSaveString("aitrans_delay", v);
    }
    if (parts.length() > 5)
    {
        v = StrTrim(parts[5]);
        if (IsNumStr(v)) HostSaveString("aitrans_retry", v);
    }
    if (parts.length() > 6)
    {
        v = StrTrim(parts[6]);
        if (IsNumStr(v)) HostSaveString("aitrans_maxtokens", v);
    }

    // “密码”栏：API 密钥（留空表示保持原值；nullkey/- 表示不用密钥）
    if (p.length() > 0) HostSaveString("aitrans_key", p);

    RefreshConfig();

    if (CFG_URL.length() == 0 || CFG_MODEL.length() == 0)
        return "[AI Translate] model name and API url are required";

    if (CFG_KEY.length() == 0 && !IsLocalUrl(CFG_URL))
    {
        return "[AI Translate] saved, but the API key is empty (for a local model put nullkey in the password box)";
    }

    // 连通性测试（本地模型先触发一次后台预热，免得第一次必然超时）
    ExtendTimeout();
    if (IsLocalUrl(CFG_URL)) LaunchWarmup();
    string err = "";
    string probe = RequestOnce("You are a test assistant. Reply with the single word: OK", "ping", err);
    if (probe.length() == 0)
    {
        return "[AI Translate] saved, but the test request failed: " + err;
    }

    return "200 ok; panel overrides: " + PanelNote();
}

void ServerLogout()
{
    // 保留配置，仅清空运行状态
    ContextLines.resize(0);
    CacheKeys.resize(0);
    CacheVals.resize(0);
    LAST_SOURCE = "";
    LAST_TRANSLATE_TICK = 0;
    LAST_SUBTITLE_TICK = 0;
}

// ============================== 生命周期 ==============================

void OnInitialize()
{
    LoadConfigFile();
    RefreshConfig();
    if (CFG_DEBUG) HostOpenConsole();

    // 本地模型：启动时就在后台把它加载进内存，否则第一次翻译必然超时
    if (IsLocalUrl(CFG_URL) && CFG_MODEL.length() > 0 && CFG_AUTOWARMUP)
        LaunchWarmup();

    string keyState = "empty";
    if (CFG_KEY.length() > 0) keyState = "set";
    Log("loaded v" + GetVersion() + ": model=" + CFG_MODEL + " url=" + CFG_URL + " key=" + keyState);
    Log("config: temp=" + CFG_TEMP + " maxTokens=" + CFG_MAXTOKENS + " context=" + formatInt(CFG_CONTEXT)
        + " retry=" + formatInt(CFG_RETRY) + " timeout=" + formatInt(CFG_TIMEOUT_MS)
        + " keepAlive=" + CFG_KEEPALIVE + " source=" + CFG_SOURCE + " warmup=" + WARM_STATUS);
    Log("panel overrides (login box wins over ai-translate.json): " + PanelNote());
    Log("log file: %APPDATA%\\PotPlayerMini64\\aitrans_log.txt");
}

void OnFinalize()
{
    Log("unloaded.");
}

// ============================== 翻译主流程 ==============================

string Translate(string Text, string &in SrcLang, string &in DstLang)
{
    RefreshConfig();

    Log("收到字幕: src=" + SrcLang + " dst=" + DstLang + " len=" + formatInt(int(Text.length())));

    if (Text.length() == 0) return "";

    // PotPlayer 设置面板的“连通性测试”文字
    if (IsTestText(Text)) return BuildTestResult();

    // 注意：只要把 Text 原样还给 PotPlayer，就必须声明它是 UTF8。
    // 否则 PotPlayer 可能按旧编码解释、甚至干脆不显示这条字幕。
    if (CFG_URL.length() == 0 || CFG_MODEL.length() == 0)
    {
        Log("未配置模型/接口地址，请打开“字幕 -> 实时字幕翻译 -> 实时字幕翻译设置”配置。");
        SrcLang = "UTF8"; DstLang = "UTF8";
        return Text;
    }
    if (CFG_KEY.length() == 0 && !IsLocalUrl(CFG_URL))
    {
        Log("未配置 API 密钥，请打开“字幕 -> 实时字幕翻译 -> 实时字幕翻译设置”配置。");
        SrcLang = "UTF8"; DstLang = "UTF8";
        return Text;
    }

    string src = SrcLang;
    string dst = DstLang;
    if (dst.length() == 0)
    {
        dst = CFG_TARGET;
        DstLang = dst;
    }
    if (src.length() > 0 && src == dst)          // 源语言=目标语言，不必翻译
    {
        SrcLang = "UTF8"; DstLang = "UTF8";
        return Text;
    }

    string source = StrTrim(Text);
    if (source.length() == 0) return "";
    if (CFG_MINCHARS > 0 && int(source.length()) < CFG_MINCHARS)
    {
        SrcLang = "UTF8"; DstLang = "UTF8";
        return Text;
    }
    if (!HasTranslatableContent(source))
    {
        SrcLang = "UTF8"; DstLang = "UTF8";
        return Text;
    }

    // 检测长间隙：如果距离上一次字幕超过阈值，返回空以清除残留字幕
    uint now = HostGetTickCount();
    if (CFG_MAX_GAP_MS > 0 && LAST_SUBTITLE_TICK > 0)
    {
        uint gap = now - LAST_SUBTITLE_TICK;
        if (gap > uint(CFG_MAX_GAP_MS))
        {
            Log("检测到静音间隙 " + formatInt(int(gap)) + "ms > " + formatInt(CFG_MAX_GAP_MS) + "ms，返回空清除残留字幕");
            LAST_SUBTITLE_TICK = now;
            return "";  // 返回空字符串让 PotPlayer 隐藏字幕
        }
    }
    LAST_SUBTITLE_TICK = now;

    // 拦截常见幻觉/静音字幕（如"谢谢观看"、"[Music]"等）
    if (IsHallucination(source))
    {
        Log("拦截幻觉字幕: " + source);
        return "";  // 返回空字符串让 PotPlayer 隐藏字幕
    }

    // 去重：同一文本在最小间隔内重复出现，直接跳过
    if (IsDuplicateTooSoon(source))
    {
        Log("跳过重复字幕(间隔过短): " + source);
        return "";  // 返回空字符串让 PotPlayer 隐藏字幕
    }

    // 缓存
    string cacheKey = src + "||" + dst + "||" + source;
    if (CFG_CACHE)
    {
        string hit = "";
        if (CacheGet(cacheKey, hit))
        {
            Log("cache hit");
            SrcLang = "UTF8";
            DstLang = "UTF8";
            return hit;
        }
    }

    // 取出前几句作为上下文
    string context = "";
    if (CFG_CONTEXT > 0)
    {
        int used = 0;
        for (uint i = ContextLines.length(); i > 0; i--)
        {
            string line = StrTrim(ContextLines[i - 1]);
            if (line.length() == 0 || line == source) continue;
            context = (context.length() == 0) ? line : (line + "\n" + context);
            used++;
            if (used >= CFG_CONTEXT) break;
        }
    }

    // ASS 样式标签保护
    array<string> tags;
    string plain = ProtectTags(source, tags);
    array<string> plainLines = SplitLines(plain);
    int maxSrcLines = int(plainLines.length());

    string systemMsg = BuildSystemMsg(src, dst, context);
    string userMsg = plain;
    string echoSystem = systemMsg
        + "\nIMPORTANT: your previous answer was wrong because you returned the source text unchanged. "
        + "Answer with the pure translation in " + LangName(dst) + " only.";

    string errMsg = "";
    string translation = "";
    int attempts = 0;
    int maxAttempts = 1 + CFG_RETRY;
    bool echoRetried = false;

    while (attempts < maxAttempts)
    {
        if (attempts > 0 && CFG_DELAY_MS > 0) HostSleep(CFG_DELAY_MS);
        attempts++;

        errMsg = "";
        string useSystem = systemMsg;
        if (echoRetried) useSystem = echoSystem;
        translation = RequestOnce(useSystem, userMsg, errMsg);
        if (translation.length() == 0)
        {
            Log("请求失败: " + errMsg);
            continue;
        }

        translation = CleanOutput(translation, source);
        if (translation.length() == 0)
        {
            Log("返回内容为空，重试。");
            continue;
        }

        // 模型把原文照抄
        if (!echoRetried && IsEcho(translation, plain))
        {
            Log("检测到未翻译(回显原文)，换用更强的提示词重试");
            echoRetried = true;
            translation = "";
            continue;
        }

        // 明显过长的幻觉
        if (LooksOverlong(translation, source))
        {
            Log("译文异常过长，重试。");
            translation = "";
            continue;
        }

        break;
    }

    if (translation.length() == 0)
    {
        Log("翻译失败，本次保留原文。最后错误: " + errMsg);
        if (CFG_KEEP_ORIG)
        {
            SrcLang = "UTF8"; DstLang = "UTF8";
            Log("返回给 PotPlayer: 原文(未翻译) " + StrTrim(Text));
            return Text;
        }
        return "";
    }

    translation = RestoreTags(translation, tags);

    // 字幕行数对齐（最多比原文多一行，避免译文铺满画面）
    int maxOut = maxSrcLines + 1;
    if (maxOut < 2) maxOut = 2;
    if (maxOut > 3) maxOut = 3;
    array<string> outLines = SplitLines(translation);
    string joined = "";
    int kept = 0;
    for (uint i = 0; i < outLines.length() && kept < maxOut; i++)
    {
        string line = StrTrim(outLines[i]);
        if (line.length() == 0) continue;
        if (kept > 0) joined += "\n";
        joined += line;
        kept++;
    }
    if (joined.length() > 0) translation = joined;

    // 右到左语言加方向标记
    if (dst == "ar" || dst == "he" || dst == "fa" || dst == "ur")
        translation = "\u202B" + translation;

    ContextLines.insertLast(plain);
    if (ContextLines.length() > 64) ContextLines.removeAt(0);

    if (CFG_CACHE) CachePut(cacheKey, translation);

    // 更新去重追踪状态
    LAST_SOURCE = StrTrim(source);
    LAST_TRANSLATE_TICK = HostGetTickCount();

    SrcLang = "UTF8";
    DstLang = "UTF8";
    Log("返回给 PotPlayer: " + translation);
    return translation;
}
