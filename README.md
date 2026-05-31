# 周易三式占卜 · Claude Code Skill

[![Release](https://img.shields.io/github/v/release/y001j/zhouyi-divination-skill?label=release&color=brightgreen)](https://github.com/y001j/zhouyi-divination-skill/releases/latest)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux%20%7C%20Windows-blue)](#支持的平台)
[![Claude Code Skill](https://img.shields.io/badge/Claude%20Code-Skill-8A63D2)](https://docs.anthropic.com/en/docs/claude-code)

一个把中式术数（**周易六爻 / 奇门遁甲 / 大六壬 / 三式互参**）封装成的 Claude Code skill。
你对它说「帮我算一卦」「用奇门看看方位」「六壬断断这个人」，它就会**起盘排卦**，并产出一份结构化的解卦材料，由 Claude 按传统解卦规则替你解读。

> ⚠️ 占卜结果仅供参考与启发，是换个角度思考问题的工具，**不构成医疗、法律、投资等任何专业建议**。

## 这个仓库是什么

一个**轻量的 skill 发行仓库**——只含说明书与一个挑选/下载二进制的脚本，本体只有几 KB：

```
zhouyi-divination/
├── SKILL.md                # 给 Claude 读的说明书（何时触发、怎么调用）
├── README.md               # 本文件，给人看的安装说明
├── VERSION                 # 对应的二进制版本（latest = 始终取最新 Release）
├── scripts/
│   └── ensure_binary.sh    # 按平台挑出本地二进制，没有就从 Release 自动下载
└── bin/                    # 运行时下载/缓存二进制的地方（仓库里不含，首次运行自动填充）
```

真正干活的 Go 二进制**不入仓库**，按平台分发为 GitHub Release 附件。两种拿到它的方式：

- **在线（默认，零配置）**：首次调用时 `ensure_binary.sh` 自动从 Release 下载当前平台的二进制到 `bin/` 并缓存，之后离线可用。
- **离线**：从 [Releases](https://github.com/y001j/zhouyi-divination-skill/releases) 下载 `zhouyi-divination-skill-offline.zip`，解压后 `bin/` 已含五平台二进制，完全不联网。

## 安装

### 方式 A：克隆仓库（在线，推荐）

```bash
git clone https://github.com/y001j/zhouyi-divination-skill.git \
  ~/.claude/skills/zhouyi-divination
```

或放到项目级：`<你的项目>/.claude/skills/zhouyi-divination/`。

首次让 Claude 占卜时，脚本会自动下载对应平台二进制（需联网一次）。

### 方式 B：离线 zip（完全不联网）

1. 从 [Releases](https://github.com/y001j/zhouyi-divination-skill/releases) 下载 `zhouyi-divination-skill-offline.zip`。
2. 解压，把里面的 `zhouyi-divination/` 整个目录放进：
   - 项目级：`<你的项目>/.claude/skills/zhouyi-divination/`
   - 用户级：`~/.claude/skills/zhouyi-divination/`
3. （macOS/Linux）如担心权限丢失：
   ```bash
   chmod +x zhouyi-divination/scripts/ensure_binary.sh
   chmod +x zhouyi-divination/bin/*
   ```

### 用起来

在 Claude Code 里直接说占卜需求即可，例如：
- 「帮我算一卦，问问明年工作运势」
- 「用奇门看看我该往哪个方向发力」
- 「六壬断断这件事什么时候有结果」

Claude 会自动识别并激活本 skill。

## 支持的平台

| 平台 | 二进制 |
|---|---|
| Apple 芯片 Mac (M1/M2/M3…) | `zhouyi-darwin-arm64` |
| Intel Mac | `zhouyi-darwin-amd64` |
| Linux x86_64 | `zhouyi-linux-amd64` |
| Linux ARM64 | `zhouyi-linux-arm64` |
| Windows x86_64 | `zhouyi-windows-amd64.exe` |

不在此列（如某些国产架构）？拿到 Go 源码后，在项目根 `go build` 自行编译并放进 `bin/`，`ensure_binary.sh` 会自动识别。

## 手动试一下（可选）

不经过 Claude，直接命令行验证它能跑：

```bash
cd zhouyi-divination
BIN=$(bash scripts/ensure_binary.sh)
"$BIN" cast -m zhouyi -q "今年事业如何" -t career
```

会输出一段 JSON，其中 `prompt` 字段就是解卦材料，`summary` 是一句话盘面摘要。

## 四种术怎么选

| 术 | 所长 | 适合 |
|---|---|---|
| 周易 `zhouyi` | 明义理、辨吉凶、示进退 | 该不该做、人生方向、心态决策 |
| 奇门 `qimen` | 谋大局、定方位、择时机 | 选址方位、出行择时、布局谋略 |
| 六壬 `liuren` | 看人心、断曲折、定应期 | 具体人事、对方心意、何时应验 |
| 互参 `huican` | 三式合参 | 重大或复杂之事，多角度印证 |

不指定时，Claude 会按问题性质替你挑。

## 常见问题

**Q：首次下载二进制安全吗？会泄露数据吗？**
A：下载只是从本仓库的 GitHub Release 拉取预编译二进制，不上传任何东西。二进制本身完全本地运行，不联网、不上传；起盘只用系统当前时间（或你指定的时间）。介意联网的用离线 zip。

**Q：macOS 提示「无法验证开发者」打不开二进制？**
A：因为二进制未签名。可执行 `xattr -d com.apple.quarantine zhouyi-divination/bin/*` 解除隔离，或在「系统设置 → 隐私与安全性」里允许。

**Q：每次结果都一样吗？**
A：奇门/六壬/互参在同一时刻同一问题下结果确定；周易默认用铜钱法（随机起卦），每次不同——这符合「即时起卦」的传统。

## 许可与免责

本工具基于传统术数典籍实现，仅供学习、研究与娱乐。占卜不能预测未来，请勿用于迷信或重大决策。涉及健康、法律、财务等，请咨询相应领域的专业人士。
