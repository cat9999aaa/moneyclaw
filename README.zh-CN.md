# MoneyClaw（中文文档）

面向自主运行场景的 AI Agent Runtime，支持生存策略、工具执行、模型路由与模型动态发现。

English doc: `README.md`

## 目录

- 项目简介
- 环境要求
- 安装
- 快速开始
- 一键启动（`go.sh`）
- CLI 命令
- 配置说明
- 模型管理（动态发现 + 缓存）
- 常见使用流程
- 开发指南
- 故障排查
- 安全说明
- 许可证

## 项目简介

MoneyClaw 是一个可长期运行的自治 Agent Runtime，核心能力包括：

- 使用 SQLite 持久化状态
- 执行工具与心跳任务
- 按生存等级与策略进行推理路由
- 接入多种模型提供方（Conway / OpenAI 兼容 / Anthropic 兼容 / Ollama）
- 从 API 动态拉取模型并缓存到本地注册表

## 环境要求

- Node.js `>= 20`
- npm 或 pnpm
- 推荐 Linux/macOS

## 安装

```bash
git clone https://github.com/cat9999aaa/moneyclaw.git
cd moneyclaw
npm install
npm run build
```

## 快速开始

首次运行并启动：

```bash
node dist/index.js --run
```

首次运行会自动进入向导，完成：

1. 钱包与身份初始化
2. 采集 API Key 与可选 Base URL
3. 写入 `~/.automaton/automaton.json`
4. 启动 Runtime（heartbeat + agent loop）

## 一键启动（`go.sh`）

`go.sh` 是面向服务器部署的一体化启动脚本。

```bash
cd ~/moneyclaw
./go.sh up
```

常用命令：

- `./go.sh up` 安装依赖 + 构建 + 后台启动
- `./go.sh restart` 重启进程
- `./go.sh status` 查看进程状态
- `./go.sh logs` 实时日志
- `./go.sh doctor` 环境诊断
- `./go.sh stop` 停止进程

Systemd（开机自启动 + 崩溃自动拉起）：

```bash
./go.sh service-install
./go.sh service-status
./go.sh service-logs
```

移除服务：

```bash
./go.sh service-remove
```

运行相关文件：

- PID 文件：`.run/moneyclaw.pid`
- 运行日志：`.run/moneyclaw.log`
- systemd 日志镜像：`.run/systemd.log`

## CLI 命令

仓库当前命令入口仍为 `automaton`（安装后可直接调用）。

也可以直接执行构建产物：

```bash
node dist/index.js --help
```

常用命令：

- `automaton --run` 启动运行时
- `automaton --setup` 重新执行初始化向导
- `automaton --configure` 进入配置菜单
- `automaton --pick-model` 交互式选择模型
- `automaton --init` 初始化钱包和配置目录
- `automaton --provision` 通过 SIWE 申请 Conway API Key
- `automaton --status` 查看当前状态
- `automaton --version` 查看版本

## 配置说明

默认配置文件：

- `~/.automaton/automaton.json`

关键字段：

- `conwayApiUrl`
- `conwayApiKey`
- `openaiApiKey`
- `openaiBaseUrl`
- `anthropicApiKey`
- `anthropicBaseUrl`
- `ollamaBaseUrl`
- `inferenceModel`
- `modelStrategy`

环境变量覆盖（优先级更高）：

- `CONWAY_API_URL`
- `CONWAY_API_KEY`
- `OPENAI_BASE_URL`
- `ANTHROPIC_BASE_URL`
- `OLLAMA_BASE_URL`

## 模型管理（动态发现 + 缓存）

MoneyClaw 支持从 Provider API 动态发现模型并缓存。

### 拉取接口

- OpenAI 兼容：`GET {baseUrl}/v1/models`
- Anthropic 兼容：`GET {baseUrl}/v1/models`
- Ollama：`GET {baseUrl}/api/tags`

### 缓存位置

发现结果会写入 SQLite 的 `model_registry`，供路由与模型选择复用。

### 刷新方式

方式 A（推荐）：

```bash
node dist/index.js --pick-model
```

方式 B：

```bash
node dist/index.js --configure
```

两者都会触发模型发现，再展示可选模型。

### 注意事项

- 若缺少对应 Provider API Key，可能跳过该 Provider 发现（视服务鉴权而定）。
- 发现失败会记录 warning 日志并继续运行（软失败）。
- 改过源码后，请先 `npm run build` 再执行 `node dist/index.js ...`。

## 常见使用流程

### 1）使用自定义 API Base URL 并切换模型

```bash
node dist/index.js --configure
node dist/index.js --pick-model
```

在 `--configure` 中设置：

- OpenAI：`openaiApiKey` + `openaiBaseUrl`
- Anthropic：`anthropicApiKey` + `anthropicBaseUrl`
- Ollama：可选 `ollamaBaseUrl`

然后在 `--pick-model` 中选择动态拉取到的模型。

### 2）查看运行状态

```bash
node dist/index.js --status
```

会显示名称、钱包地址、状态、轮次、当前模型等信息。

### 3）迁移环境后重置向导

```bash
node dist/index.js --setup
```

适用于换机器、更新凭据、重新初始化。

## 开发指南

安装与构建：

```bash
npm install
npm run build
```

测试：

```bash
npm test
```

开发模式：

```bash
npm run dev
```

## 故障排查

### 自定义 API 的模型列表不对

按顺序检查：

1. 先执行 `npm run build`
2. 在 `--configure` 确认 Key + Base URL
3. 执行 `node dist/index.js --pick-model`
4. 查看日志中 discovery warning

### `--pick-model` 只显示预设模型

常见原因：

- `dist` 不是最新（未 build）
- Provider API Key 未配置
- Provider 接口鉴权失败或返回异常

### 明明 MetaMask 有 ETH，为什么 Credits 还是 `$0.00`

这在很多场景是正常的：**ETH 余额不等于 Conway credits**。

运行时真正看的是：

1. 当前 Conway API Key 对应账户的 credits
2. 运行钱包是否具备可走 topup 的资金（通常是 Base 上的 USDC）

按小狐狸（MetaMask）可用流程排查：

```bash
# 1）先保证 API key 重新配置到位
./go.sh key-setup

# 2）确认运行钱包和创建者钱包
jq -r '.walletAddress,.creatorAddress' ~/.automaton/automaton.json

# 3）重启并观察 bootstrap/topup 日志
./go.sh restart
./go.sh logs
```

在 MetaMask 里，给 **运行钱包**（`walletAddress`）在 **Base** 网络补充：

- 少量 ETH（gas）
- 足够 USDC（用于 credits 充值）

直接查询 credits：

```bash
API_KEY=$(jq -r '.conwayApiKey' ~/.automaton/automaton.json)
curl -s https://api.conway.tech/v1/credits/balance -H "Authorization: $API_KEY"
```

如果 API 返回仍是 `0`，说明 Conway credits 账户还没有充值成功，即使 ETH 不为 0。

### 推送 GitHub 出现 403

- 检查 Token 是否有仓库写权限
- 检查 remote URL 是否是你有权限的仓库

## 安全说明

- 不要把密钥写进仓库。
- 生产环境优先使用环境变量管理凭据。
- 无人值守前请先检查工具权限与资金策略。

## 许可证

MIT
