# jumphost

通过 frp 反向代理管理跳板机，一行命令让内网服务器对外可达。

## 快速开始（30 秒）

```bash
# 1. 在跳板机上部署 frps
./scripts/deploy-jumphost.sh --ip <跳板机公网IP>

# 2. 添加目标服务器
./scripts/add-server.sh my-server

# 3. 把生成的配置 scp 到目标服务器并安装
scp output/servers/my-server/* user@my-server:/tmp/
ssh user@my-server 'cd /tmp && sudo ./install-frpc.sh'

# 4. 生成本地 SSH config，直接连
./scripts/generate-ssh-config.sh
ssh my-server
```

## 它是什么？

```
你的电脑 ──SSH──> 跳板机 (frps, 公网IP) ──反向隧道──> 目标服务器 (frpc)
                   端口 7000                    端口 22001-22050
```

内网服务器运行 frpc，向公网跳板机注册一条 SSH 反向隧道。你在本地只需 `ssh my-server`，SSH ProxyJump 自动经跳板机中转，无需在目标服务器上开放任何额外端口。

### 典型场景：管理多台内网机器

假设你有 3 台内网服务器（数据库、Web、开发机），都没有公网 IP，但都有一台公网跳板机可达。

**第一步**：在跳板机上运行 `deploy-jumphost.sh`，frps 安装并启动，生成 token 和 dashboard 密码，信息保存到 `output/jumphost-info.json`。

**第二步**：依次添加每台服务器：

```bash
./add-server.sh mysql-db          # 自动分配 22001
./add-server.sh web-app           # 自动分配 22002
./add-server.sh dev-machine       # 自动分配 22003
```

每条命令在 `output/servers/<name>/` 下生成 `frpc.toml` 和 `install-frpc.sh`，scp 到对应服务器执行即可。

**第三步**：生成本地 SSH config：

```bash
./generate-ssh-config.sh root ~/.ssh/id_ed25519
```

生成的配置文件：

```
Host jumphost
    HostName 1.2.3.4
    User root
    IdentityFile ~/.ssh/id_ed25519

Host mysql-db
    HostName 127.0.0.1
    Port 22001
    ProxyJump jumphost

Host web-app
    HostName 127.0.0.1
    Port 22002
    ProxyJump jumphost

Host dev-machine
    HostName 127.0.0.1
    Port 22003
    ProxyJump jumphost
```

之后 `ssh mysql-db`、`ssh web-app`、`ssh dev-machine` 直连。

## 前提条件

- 一台有公网 IP 的 Linux 服务器（跳板机）
- 目标服务器能访问跳板机的 7000 端口
- 本地通过 SSH 可达跳板机
- Bash 4+（macOS / Linux 均可）

## 脚本说明

| 脚本 | 用途 | 运行位置 |
|------|------|----------|
| `deploy-jumphost.sh [--ip <IP>]` | 安装并启动 frps | 跳板机 |
| `add-server.sh <name> [--port 22] [--remote N]` | 生成 frpc 配置和安装脚本 | 本地 |
| `generate-ssh-config.sh [<user>] [<ssh-key>]` | 生成带 ProxyJump 的 SSH config | 本地 |

## 配置文件

| 文件 | 说明 |
|------|------|
| `config/frps.toml` | 跳板机 frp 服务端模板 |
| `config/frpc.toml` | 目标服务器 frp 客户端模板（`{{VAR}}` 占位符） |
| `config/servers.csv` | 服务器清单：`name,ssh_port,remote_port,description` |

## 端口规划

- **7000** — frps 通信端口（跳板机监听）
- **7500** — frps Dashboard（仅监听 127.0.0.1，跳板机本地访问）
- **22001-22050** — SSH 反向隧道端口，每台目标服务器分配一个

## FAQ

**需要安装 Python 吗？** 不需要，全部是 Bash 脚本。

**frp 在哪下载？** 脚本自动从 GitHub Releases 下载 frp v0.61.1 (Linux amd64)。

**安全吗？** 认证使用随机生成的 token；Dashboard 仅本地监听；目标服务器无需开放额外端口；所有隧道流量走 SSH 加密。

**端口不够用怎么办？** 修改 `config/frps.toml` 中的 `allowPorts` 范围，重启 frps 即可。

## 项目结构

```
jumphost/
├── config/
│   ├── frps.toml          # frp 服务端配置模板
│   ├── frpc.toml          # frp 客户端配置模板
│   └── servers.csv        # 服务器清单
├── scripts/
│   ├── common.sh          # 公共函数库
│   ├── deploy-jumphost.sh # 部署跳板机
│   ├── add-server.sh      # 添加目标服务器
│   └── generate-ssh-config.sh  # 生成 SSH config
└── output/                # 运行产出（不提交，含敏感信息）
```

## 贡献

欢迎提 Issue 和 PR！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## License

MIT
