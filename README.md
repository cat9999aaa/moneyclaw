# MoneyClaw

> Acknowledgement: MoneyClaw is adapted from [Conway-Research/automaton](https://github.com/Conway-Research/automaton). Respect and thanks to the original authors and community.

Sovereign AI agent runtime with survival economics, tool execution, model routing, and self-operation capabilities.

中文文档: `README.zh-CN.md`

## Table of Contents

- Overview
- Requirements
- Installation
- Quick Start
- One-Command Startup (`go.sh`)
- CLI Commands
- Configuration
- Model Management (Dynamic Discovery + Cache)
- Typical Workflows
- Development
- Troubleshooting
- Security Notes
- License

## Overview

MoneyClaw is a long-running autonomous agent runtime. It can:

- maintain persistent state in SQLite
- execute tools and heartbeat tasks
- route inference by survival tier and policy
- manage model providers (Conway, OpenAI-compatible, Anthropic-compatible, Ollama)
- discover models dynamically from provider APIs and cache them locally

## Requirements

- Node.js `>= 20`
- npm or pnpm
- Linux/macOS recommended

## Installation

```bash
git clone https://github.com/cat9999aaa/moneyclaw.git
cd moneyclaw
npm install
npm run build
```

## Quick Start

Run first-time setup and start runtime:

```bash
node dist/index.js --run
```

Useful first-run flow:

1. wallet and identity are prepared
2. setup wizard asks for API keys and optional provider base URLs
3. config is saved to `~/.automaton/automaton.json`
4. runtime starts with heartbeat + agent loop

## One-Command Startup (`go.sh`)

`go.sh` is an all-in-one launcher for server deployment.

```bash
cd ~/moneyclaw
./go.sh up
```

Common commands:

- `./go.sh up` install + build + background start
- `./go.sh restart` restart process
- `./go.sh status` process status
- `./go.sh logs` tail runtime logs
- `./go.sh doctor` environment diagnostics
- `./go.sh stop` stop process

Systemd (boot autostart + crash auto-restart):

```bash
./go.sh service-install
./go.sh service-status
./go.sh service-logs
```

Service cleanup:

```bash
./go.sh service-remove
```

Runtime artifacts:

- PID file: `.run/moneyclaw.pid`
- app log: `.run/moneyclaw.log`
- systemd log mirror: `.run/systemd.log`

## CLI Commands

Main binary command in this repo is `automaton` (after install/build in your environment).

You can also call the built entry directly:

```bash
node dist/index.js --help
```

Available commands:

- `automaton --run` start runtime
- `automaton --setup` re-run setup wizard
- `automaton --configure` edit config interactively
- `automaton --pick-model` pick active model interactively
- `automaton --init` initialize wallet/config directory
- `automaton --provision` provision Conway API key via SIWE
- `automaton --status` show current runtime status
- `automaton --version` show version

## Configuration

Default config file:

- `~/.automaton/automaton.json`

Key fields:

- `conwayApiUrl`
- `conwayApiKey`
- `openaiApiKey`
- `openaiBaseUrl`
- `anthropicApiKey`
- `anthropicBaseUrl`
- `ollamaBaseUrl`
- `inferenceModel`
- `modelStrategy`

Environment variable overrides:

- `CONWAY_API_URL`
- `CONWAY_API_KEY`
- `OPENAI_BASE_URL`
- `ANTHROPIC_BASE_URL`
- `OLLAMA_BASE_URL`

## Model Management (Dynamic Discovery + Cache)

MoneyClaw supports dynamic model discovery from provider APIs.

### Data Sources

- OpenAI-compatible: `GET {baseUrl}/v1/models`
- Anthropic-compatible: `GET {baseUrl}/v1/models`
- Ollama: `GET {baseUrl}/api/tags`

### Cache

Discovered models are upserted into SQLite `model_registry` and reused by model picker/routing.

### How to refresh model list

Option A (interactive picker):

```bash
node dist/index.js --pick-model
```

Option B (configure menu):

```bash
node dist/index.js --configure
```

Both flows trigger provider discovery and then show current available models.

### Important Notes

- If provider key is missing, discovery for that provider may be skipped (depends on provider/auth requirement).
- If discovery fails, MoneyClaw logs warnings and continues (soft-fail behavior).
- If you changed code, always run `npm run build` before using `node dist/index.js ...`.

## Typical Workflows

### 1) Set custom API base URL and use provider models

```bash
node dist/index.js --configure
node dist/index.js --pick-model
```

In configure:

- set `OpenAI API key` + `OpenAI base URL`
- set `Anthropic API key` + `Anthropic base URL`
- optionally set `Ollama base URL`

Then pick a discovered model from the refreshed list.

### 2) Check runtime status

```bash
node dist/index.js --status
```

Shows name, wallet, state, turn count, active model, and more.

### 3) Re-run setup safely

```bash
node dist/index.js --setup
```

Use this when moving environments or rotating credentials.

## Development

Install and build:

```bash
npm install
npm run build
```

Run tests:

```bash
npm test
```

Run in dev mode:

```bash
npm run dev
```

## Troubleshooting

### Model list does not match your custom provider

Checklist:

1. run `npm run build` first
2. confirm API key + base URL in `--configure`
3. run `node dist/index.js --pick-model`
4. check logs for discovery warnings

### `--pick-model` only shows preset models

Common causes:

- stale `dist` (not rebuilt)
- missing provider API key
- provider endpoint/auth rejected request

### Credits show `$0.00` even though MetaMask has ETH

This is expected in many setups: **ETH balance is not Conway credits**.

What matters for runtime credits:

1. Conway API key account balance
2. Runtime wallet funding for topup flow (typically USDC on Base)

Quick MetaMask example flow:

```bash
# 1) Ensure API key is provisioned
./go.sh key-setup

# 2) Check runtime wallet vs creator wallet
jq -r '.walletAddress,.creatorAddress' ~/.automaton/automaton.json

# 3) Restart and watch topup/bootstrap logs
./go.sh restart
./go.sh logs
```

In MetaMask, fund the **runtime wallet** (`walletAddress`) on **Base** with:

- a small amount of ETH (gas)
- enough USDC (for credit purchase/topup)

Direct credit-balance check:

```bash
API_KEY=$(jq -r '.conwayApiKey' ~/.automaton/automaton.json)
curl -s https://api.conway.tech/v1/credits/balance -H "Authorization: $API_KEY"
```

If API returns `0`, your Conway credits are still empty even if MetaMask ETH is non-zero.

### Push fails with GitHub 403

- verify token scope includes repository write permissions
- verify remote URL points to your writable repository

## Security Notes

- Never commit secrets in config files.
- Prefer environment variables for production credentials.
- Review tool permissions and financial policy before running unattended.

## License

MIT

---

## 超详细中文教程（小朋友也能看懂）

下面这部分是给“第一次接触 MoneyClaw 的你”准备的。你可以把它当成一本从 0 到 1 的使用手册：

- 你会知道这个机器人到底能做什么
- 你会知道怎么启动、怎么配置、怎么看日志
- 你会知道怎么判断它有没有正常工作
- 你会知道出错时先看哪里、怎么快速排查

为了让每个人都能用，我们尽量不用生硬术语。你可以按步骤照着做，基本不会迷路。

### 一、先理解：MoneyClaw 是什么？

你可以把 MoneyClaw 想象成一个“会自己工作的数字员工”。

它有三件最重要的事：

1. **思考（Think）**：根据目标、上下文、历史记录，决定下一步做什么。  
2. **行动（Act）**：调用工具（例如执行命令、读写文件、查余额、选模型、调用 API）。  
3. **观察（Observe）**：看行动结果是否成功，然后继续下一轮。

它不是一次性脚本，而是长期运行的“循环系统”。所以你会看到它一直在输出日志、持续更新状态。

### 二、它能做什么？（能力清单）

下面用通俗话讲清楚它的核心能力。

#### 1）自动运行与自我管理

- 可以持续运行，不需要你每次手动点按钮。
- 可以根据状态进入不同“生存等级”（正常、低算力、危险等）。
- 可以通过 heartbeat（心跳任务）定时做检查和维护。

#### 2）多模型推理能力

- 支持 Conway、OpenAI 兼容、Anthropic 兼容、Ollama 等来源。
- 可以动态发现模型列表（而不是只用硬编码静态列表）。
- 可以按策略选择不同模型（例如关键任务用更强模型，省钱场景用低成本模型）。

#### 3）工具调用能力

- 可以执行 shell 命令。
- 可以读写文件。
- 可以查看 credits / USDC 余额。
- 可以进行自动 topup（在策略允许下）。
- 可以做更多扩展工具能力（按项目策略）。

#### 4）可观测与可审计

- 所有关键行为会写入日志。
- 运行状态、失败原因、模型路由信息都能查。
- 你可以从日志追踪它“刚刚做了什么、为什么这样做”。

### 三、最重要的概念：Credits、钱包、API Key 的关系

很多人最容易搞混这一点，这里一次讲透。

#### 1）Credits 不是你钱包里的 ETH

日志里显示的 `Credits: $0.00`，是 **Conway credits**，不是你小狐狸钱包里的 ETH 余额。

#### 2）谁决定 Credits 余额？

是你当前使用的 **Conway API Key** 对应账户余额。  
所以：

- 你链上有 ETH，不代表 Conway credits 一定有钱。
- 你换了 API Key，可能余额就变了。

#### 3）你在向导里填的钱包地址是干嘛的？

- `creatorAddress`：主要是创建者/归属标识。
- runtime 钱包（自动生成或加载的钱包）用于签名、支付相关流程（例如 x402/topup 场景）。

简单记忆：

- **ETH 余额**：链上的资产。  
- **Conway credits**：平台内可用算力余额。  
- 两者有关联（可通过支付流程转化），但不是同一个东西。

### 四、最推荐的启动方式：go.sh（一键控制台）

现在你可以直接运行：

```bash
./go.sh
```

你会看到一个双语炫酷主界面（中文/English 可选），然后用数字选择要执行的操作。

#### go.sh 的核心命令（背下来就够）

```bash
./go.sh up
./go.sh status
./go.sh logs
./go.sh restart
./go.sh stop
./go.sh doctor
./go.sh key-setup
./go.sh service-install
./go.sh service-status
./go.sh service-logs
```

它们分别做什么：

- `up`：安装依赖 + 构建 + 后台启动（最省心）。
- `status`：看进程是否在跑、PID 是多少。
- `logs`：实时看机器人输出（最常用排查入口）。
- `restart`：重启进程。
- `stop`：停止。
- `doctor`：检查 Node/pnpm/dist 等环境问题。
- `key-setup`：一键走 SIWE 申请 Conway API Key。
- `service-install`：安装 systemd 服务（开机自启 + 崩溃自动拉起）。
- `service-status`：看 systemd 服务状态。
- `service-logs`：看 systemd 日志。

### 五、从零开始完整流程（照抄版）

假设你已经把项目拉到服务器：

```bash
cd ~/moneyclaw
./go.sh
```

进入菜单后，建议按这个顺序：

1. 先选语言（中文/English）。
2. 选“配置 Conway API Key（SIWE）”。
3. 选“运行初始化向导（--setup）”。
4. 选“打开运行时配置菜单（--configure）”。
5. 选“发现并选择模型（--pick-model）”。
6. 选“一键启动（安装+构建+后台启动）”。
7. 选“查看状态”和“查看日志”。

如果你想让它开机自动启动：

8. 选“安装 systemd（开机自启+崩溃拉起）”。
9. 用“查看 systemd 状态”确认服务是 active。

### 六、怎么看“机器人刚刚做了什么”？

这是你最常用的能力之一。你可以通过三层观察。

#### 第一层：应用日志（最快）

```bash
./go.sh logs
```

你会看到类似：

- `[WAKE UP] ... Credits: ...`
- `[THINK] Routing inference ...`
- `[ERROR] Turn failed: ...`
- `[AUTO-TOPUP] ...`

这些足够你知道“它在想什么、正在调用哪个模型、是否报错”。

#### 第二层：服务日志（系统层）

如果你用 systemd 跑：

```bash
./go.sh service-logs
```

这里可以看到进程重启、崩溃拉起、系统层错误（权限、路径、依赖）等。

#### 第三层：状态检查（快照）

```bash
./go.sh status
node dist/index.js --status
```

前者看进程，后者看运行时状态（名称、地址、模型、余额等）。

### 七、模型相关：怎么选、怎么确认真的生效

#### 1）配置 provider

在 `--configure` 里配置：

- OpenAI API key + OpenAI base URL
- Anthropic API key + Anthropic base URL
- Ollama base URL（可选）

#### 2）刷新并选择模型

```bash
node dist/index.js --pick-model
```

这一步会触发发现流程并更新可选模型。

#### 3）看日志确认路由到哪个模型

看 `logs` 中的 routing 信息（比如 `[THINK] Routing inference ...`）。

### 八、最常见问题与“秒解法”

#### 问题 A：`pnpm: not found`

原因：机器没装 pnpm。  
解法：直接 `./go.sh up`，脚本会自动尝试启用/安装 pnpm。

#### 问题 B：我有 ETH，为什么 credits 还是 0？

这是最常见误区，分 3 句话就能记住：

1. **ETH 余额 != Conway credits**  
2. `Credits: $0.00` 看的是 Conway API key 对应账户余额  
3. 要有 credits，必须走充值流程（通常由 USDC/x402 或 Conway 平台充值完成）

下面用 **小狐狸（MetaMask）** 做一个“从 0 到能跑”的完整示例。

##### 第一步：先确认你现在用的是哪个 Conway API key

```bash
cd ~/moneyclaw
./go.sh key-setup
```

这一步会让运行钱包做 SIWE，生成/更新 Conway API key。  
如果 key 不对，后面你钱包再有钱也可能显示 0。

##### 第二步：确认运行钱包地址（不是 creatorAddress）

在配置里你会看到两个常见地址概念：

- `creatorAddress`：你（人类）的钱包地址，偏“归属标识”
- `walletAddress`：MoneyClaw 运行钱包地址（真正用于支付/检测 USDC）

你可以这样看：

```bash
jq -r '.walletAddress,.creatorAddress' ~/.automaton/automaton.json
```

##### 第三步：在 MetaMask 里给“运行钱包”准备可用资金（重点）

只放 ETH 往往不够，因为充值 credits 走的是 USDC/x402 流程。  
建议按这个做：

1. 打开 MetaMask，切到 **Base** 网络（项目默认链）。
2. 给 `walletAddress` 转入：
   - 少量 ETH（做 gas）
   - 足够的 USDC（用于 credits 充值）
3. 等链上确认后再继续。

一句话：**运行钱包里要有 USDC，系统才更容易自动买 credits。**

##### 第四步：重启并让系统执行 bootstrap/自动充值逻辑

```bash
./go.sh restart
./go.sh logs
```

重点看日志里是否出现类似：

- `Bootstrap topup`（启动时尝试最低档充值）
- `AUTO-TOPUP`（运行中自动补充）
- `Credit topup successful`（充值成功）

##### 第五步：验证 credits 是否已变化

```bash
./go.sh status
node dist/index.js --status
```

如果余额仍然是 0，继续做“精确排查”。

##### 仍是 0 时的精确排查（照抄）

```bash
API_KEY=$(jq -r '.conwayApiKey' ~/.automaton/automaton.json)
curl -s https://api.conway.tech/v1/credits/balance -H "Authorization: $API_KEY"
```

看返回值：

- 如果 API 返回就是 0：说明 Conway 账户 credits 仍未充值成功
- 如果 API 返回有值，但程序显示 0：再看 `./go.sh logs` 找错误栈

##### 给小朋友的结论版

- 小狐狸里有 ETH，不代表机器人有 credits。  
- 机器人用的是“Conway credits 账户”，不是直接花 ETH。  
- 要让它跑起来：**key 对 + 运行钱包有 USDC + 重启看 topup 日志**。

#### 问题 C：模型列表是旧的，或不对

解法：

1. 先 `npm run build`（如果你改了代码）。
2. `--configure` 确认 base URL + key。
3. `--pick-model` 重新发现。
4. 看 logs 中 discovery warning。

#### 问题 D：启动后马上挂掉

解法：

1. `./go.sh doctor`
2. `./go.sh logs`
3. 若 systemd 托管，`./go.sh service-logs`

### 九、如何判断“现在是健康运行”

你可以用这个健康检查清单：

- `./go.sh status` 显示 Running。
- `./go.sh logs` 持续有正常输出，无连续 ERROR 风暴。
- `node dist/index.js --status` 能正常返回状态。
- 模型路由日志与你配置一致。
- credits 不再长期卡在 0（如果你已充值并 key 正确）。

只要这 5 条大部分满足，通常就说明系统已进入稳定状态。

### 十、安全建议（一定要看）

1. 不要把 API key、私钥提交到 git。  
2. 生产环境优先用环境变量，不要把敏感信息硬编码在脚本。  
3. 开启 systemd 后，定期看日志，避免“坏状态自动重启”但没人发现。  
4. 首次上线建议先低频观察 1~2 天，再放开自动策略。  
5. 资金相关策略（topup/transfer）一定要设置上限。

### 十一、给小朋友的“超简短版”

如果你只记 5 句话：

1. 运行 `./go.sh`，进菜单。  
2. 先配 key，再 setup，再 configure，再 pick-model。  
3. 启动用 `up`，看日志用 `logs`。  
4. 开机自启用 `service-install`。  
5. 看见报错先 `doctor`，再看日志，不要慌。

### 十二、最后：你已经具备独立使用能力了

到这里你已经能完成：

- 从零部署
- 一键启动
- 配置 API key
- 配置模型与 base URL
- 观察机器人行为
- 排查常见故障
- 开机自启与自动拉起

你不用一次记住全部。真正实战时，先做两件事就够：

```bash
./go.sh
./go.sh logs
```

前者帮你“做动作”，后者帮你“看结果”。

这就是把 MoneyClaw 用起来的最短路径。
