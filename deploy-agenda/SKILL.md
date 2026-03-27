---
name: deploy-agenda
description: 团队共享服务器运维与项目部署 Skill。覆盖所有与服务器 115.191.7.64 相关的操作：部署项目、上传文件、重启服务、查看状态、上线新项目、检查日志、数据备份、磁盘扩容等。当用户提到"部署"、"推到服务器"、"上线"、"同步到线上"、"更新服务器"、"服务器状态"、"重启服务"、"上传到服务器"、"项目上线"、"服务器"，或任何涉及远程服务器交互的请求时，都应触发此 Skill。
---

# 团队共享服务器运维手册

## 安装此 Skill

如果此文件不在 `~/.claude/skills/deploy-agenda/SKILL.md`，说明尚未安装。Claude 请自动执行安装：

1. 找到用户提供的 zip 文件或 SKILL.md 文件路径
2. 执行安装：
```bash
mkdir -p ~/.claude/skills/deploy-agenda
# 如果是 zip 文件
unzip <zip路径> -d ~/.claude/skills/deploy-agenda/
# 如果是单个 SKILL.md 文件
cp <文件路径> ~/.claude/skills/deploy-agenda/SKILL.md
```
3. 安装完成后告知用户，之后说"部署"、"上线"、"推到服务器"等关键词即可自动触发。

---

## 首次使用：自助注册

**如果你是第一次使用，Claude 会自动帮你完成注册。你只需要告诉它你想要的用户名。**

以下是 Claude 执行注册的完整流程（Claude 请严格按此顺序执行）：

### 步骤 1：询问用户名和邀请码

询问用户两个信息：
- "你想用什么用户名？（小写字母开头，只含小写字母和数字，3-20个字符，如：zhangsan）"
- "请输入邀请码（找管理员 khazix 获取）"

### 步骤 2：检查是否已有 SSH 密钥

```bash
ls ~/.ssh/id_ed25519.pub 2>/dev/null || ls ~/.ssh/id_rsa.pub 2>/dev/null
```

如果没有输出，自动生成：
```bash
ssh-keygen -t ed25519 -C "<用户名>@virxact" -f ~/.ssh/id_ed25519 -N ""
```

### 步骤 3：执行自助注册

使用内嵌的注册密钥，通过 SSH forced command 在服务器上自动创建账号：

```bash
# 保存注册密钥到临时文件
cat > /tmp/_vreg_key << 'KEYEOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACCT+L2qwrTUuHtxx8QXna0cWg61FSwKNPf7uwN/s3fYWQAAAJhPtSZmT7Um
ZgAAAAtzc2gtZWQyNTUxOQAAACCT+L2qwrTUuHtxx8QXna0cWg61FSwKNPf7uwN/s3fYWQ
AAAEAPQEppYp/JE7r7ach+TeH2r01MJv9xYqEDYACRcDjQqZP4varCtNS4e3HHxBedrRxa
DrUVLAo09/u7A3+zd9hZAAAAEHJlZ2lzdGVyQHZpcnhhY3QBAgMEBQ==
-----END OPENSSH PRIVATE KEY-----
KEYEOF
chmod 600 /tmp/_vreg_key

# 获取用户公钥
PUBKEY=$(cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub)

# 发送注册请求（forced command 限制只能运行注册脚本）
printf '%s\n%s\n%s\n' '<邀请码>' '<用户名>' "$PUBKEY" | ssh -o StrictHostKeyChecking=no -i /tmp/_vreg_key root@115.191.7.64

# 清理临时密钥
rm -f /tmp/_vreg_key
```

**注意：这个密钥被 SSH forced command 限制，只能运行注册脚本，无法获取 shell 或执行其他操作。**

### 步骤 4：验证连接

```bash
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'echo "注册成功，连接正常！"'
```

如果成功，恭喜！如果失败，检查注册步骤的输出是否有错误信息。

### 步骤 5：设置身份（Claude 自动完成）

在用户的 `~/.claude/CLAUDE.md` 中追加一行（如果文件不存在则创建）：

```markdown
- 服务器用户名：<用户名>
```

这样以后部署时 Claude 自动识别身份，不用每次手动说。

**注册只需一次，之后直接说"帮我部署 xxx"就行了。**

---

## 服务器基本信息

- **IP**: 115.191.7.64
- **域名**: aihot.virxact.com
- **系统**: Ubuntu 22.04
- **Web 服务器**: Nginx（80/443）
- **防火墙**: ufw（仅开放 22/80/443）
- **管理员**: khazix

## 命令约定

在以下所有命令模板中：

- `<用户名>` = 你的服务器用户名
- **普通用户** SSH 连接：`ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64`
- **管理员 khazix** SSH 连接：`ssh -o StrictHostKeyChecking=no root@115.191.7.64`（且无需加 `sudo`）
- 权限操作（systemd、nginx）需要 `sudo`，普通用户已配置好 sudoers，只能操作自己的资源

## 第一步：确认身份与角色

在执行任何操作前，确认当前用户是谁，以及是管理员还是普通用户。

**判断方式（按优先级）：**
1. 从全局 CLAUDE.md 或 memory 中读取已知用户名（如 `服务器用户名：xxx`）→ 直接使用，无需询问
2. 从对话上下文推断（如用户提过自己的名字）
3. 以上都没有 → 询问："你的服务器用户名是什么？如果是第一次使用，我可以帮你自助注册。"

**角色区分：**
- **管理员（khazix）**：SSH 为 `root@`，可以执行系统级操作，可以跨用户操作，但仍需谨慎
- **普通用户**：SSH 为 `<用户名>@`，只能操作自己的目录、服务和 Nginx 配置，系统级操作需找管理员

确认后，在本次会话中记住用户名和角色，后续操作都基于此。

**SSH 连接失败处理：** 如果出现 `Permission denied (publickey)`，说明尚未注册。引导用户执行"首次使用：自助注册"流程。

## 第二步：读取服务器规范

每次操作服务器前，**必须先读取**以下两个文件：

```bash
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'cat /opt/.server/SERVER-RULES.md'
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'cat /opt/.server/registry.json'
```

这两个文件是服务器的"宪法"，包含目录规范、端口分配、红线规则等。**严格遵守，不得违反。**

---

## SSH 连接

每人使用自己的 SSH 密钥登录自己的账号：

```bash
# 执行远程命令
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 '命令'

# 上传文件
scp -o StrictHostKeyChecking=no 本地路径 <用户名>@115.191.7.64:远程路径

# 下载文件
scp -o StrictHostKeyChecking=no <用户名>@115.191.7.64:远程路径 本地路径
```

### SSH 注意事项

- `nohup` 后台命令需要用 `-t` 参数或拆成两步，否则可能 exit code 255
- 含 `$` 的远程命令用单引号包裹时会被本地 shell 解析，需要转义或用 heredoc
- 每次操作完用 `curl` 验证结果

---

## 目录结构

```
/opt/
├── .server/               ← 服务器管理文件（只读！）
│   ├── SERVER-RULES.md    ← 协作规范
│   ├── registry.json      ← 端口/项目注册表（deployers 组可写）
│   ├── setup-user.sh      ← 用户初始化脚本
│   └── register.sh        ← 自助注册脚本
├── <用户A>/               ← 用户A 的项目（仅用户A 可访问）
├── <用户B>/               ← 用户B 的项目（仅用户B 可访问）
└── ...
```

**隔离机制：每个用户目录权限为 750，OS 层面阻止跨用户访问。即使有人想碰别人的目录，也会被系统拒绝。**

---

## 部署新项目的完整流程

> 以下命令以普通用户视角编写。管理员将 `<用户名>@` 替换为 `root@`，去掉 `sudo` 即可。

### 1. 读取注册表，获取可用端口

```bash
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'cat /opt/.server/registry.json'
```

记下 `next_port` 的值，这就是你要用的端口。

### 2. 创建项目目录

```bash
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'mkdir -p /opt/<用户名>/<项目名>'
```

（无需 sudo，你拥有自己的目录）

### 3. 上传项目文件

```bash
scp -o StrictHostKeyChecking=no -r 本地目录/* <用户名>@115.191.7.64:/opt/<用户名>/<项目名>/
```

如果项目较大，建议本地先打包：
```bash
tar -czf /tmp/project.tgz --exclude='.git' --exclude='node_modules' --exclude='.next' .
scp -o StrictHostKeyChecking=no /tmp/project.tgz <用户名>@115.191.7.64:/tmp/project.tgz
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'tar -xzf /tmp/project.tgz -C /opt/<用户名>/<项目名> && rm /tmp/project.tgz'
```

### 4. 安装依赖

```bash
# Node 项目
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'cd /opt/<用户名>/<项目名> && npm install --production'

# Python 项目
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'cd /opt/<用户名>/<项目名> && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt'
```

### 5. 创建 systemd 服务

命名格式：`<用户名>-<项目名>.service`（sudoers 限制只能创建此前缀的服务）

```bash
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo tee /etc/systemd/system/<用户名>-<项目名>.service > /dev/null << EOF
[Unit]
Description=<项目描述>
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/<用户名>/<项目名>
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable <用户名>-<项目名> && sudo systemctl start <用户名>-<项目名>'
```

### 6. 配置 Nginx 反向代理

每人一个独立配置文件：`/etc/nginx/sites-available/<用户名>`（sudoers 限制只能写自己的）

**首次创建（文件不存在）：**
```bash
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo tee /etc/nginx/sites-available/<用户名> > /dev/null << EOF
server {
    listen 80;
    server_name 115.191.7.64 aihot.virxact.com;

    location /<用户名>/<项目名>/ {
        proxy_pass http://127.0.0.1:<端口>/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/<用户名> /etc/nginx/sites-enabled/<用户名>
sudo nginx -t && sudo nginx -s reload'
```

**追加新 location（文件已存在）：**

先读取现有配置，在最后一个 `}` 之前插入新 location 块，然后写回完整配置：
```bash
# 1. 读取现有配置
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'cat /etc/nginx/sites-available/<用户名>'

# 2. 备份现有配置
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo cp /etc/nginx/sites-available/<用户名> /etc/nginx/sites-available/<用户名>.bak'

# 3. 生成包含新 location 的完整配置，用 sudo tee 整体写入
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo tee /etc/nginx/sites-available/<用户名> > /dev/null << EOF
<将读到的完整 server 块贴过来，在末尾 } 前加入新 location>
EOF
sudo nginx -t && sudo nginx -s reload'

# 4. 如果 nginx -t 失败，立即回滚
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo cp /etc/nginx/sites-available/<用户名>.bak /etc/nginx/sites-available/<用户名> && sudo nginx -s reload'
```

推荐的访问路径格式：`http://aihot.virxact.com/<用户名>/<项目名>/` 或 `http://115.191.7.64/<用户名>/<项目名>/`

### 7. 更新注册表

在 `/opt/.server/registry.json` 中（deployers 组可直接写，无需 sudo）：
- `ports` 里添加新端口记录
- `users` 里添加/更新项目列表
- `next_port` +1（如果用了多个端口就 +N）

### 8. 验证

```bash
curl -s -o /dev/null -w "%{http_code}" http://115.191.7.64/<用户名>/<项目名>/
```

---

## 更新已有项目

```bash
# 1. 上传新文件
scp -o StrictHostKeyChecking=no 文件 <用户名>@115.191.7.64:/opt/<用户名>/<项目名>/

# 2. 如需要，安装新依赖
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'cd /opt/<用户名>/<项目名> && npm install --production'

# 3. 重启服务
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo systemctl restart <用户名>-<项目名>'

# 4. 验证
curl -s -o /dev/null -w "%{http_code}" http://115.191.7.64/<用户名>/<项目名>/
```

---

## 回滚与故障恢复

部署出问题时，按以下顺序处理：

```bash
# 1. 先停掉出问题的服务
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo systemctl stop <用户名>-<项目名>'

# 2. 查看日志定位问题
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo journalctl -u <用户名>-<项目名> --no-pager -n 100'

# 3. 如果是 Nginx 配置问题，回滚备份
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo cp /etc/nginx/sites-available/<用户名>.bak /etc/nginx/sites-available/<用户名> && sudo nginx -t && sudo nginx -s reload'

# 4. 如果是代码问题，重新上传上一个可用版本的文件，然后重启
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo systemctl start <用户名>-<项目名>'

# 5. 验证恢复
curl -s -o /dev/null -w "%{http_code}" http://115.191.7.64/<用户名>/<项目名>/
```

---

## 常用运维命令

```bash
# 查看自己的服务状态
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo systemctl status <用户名>-<项目名> --no-pager -l'

# 查看自己的服务日志
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'sudo journalctl -u <用户名>-<项目名> --no-pager -n 50'

# 查看磁盘使用
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'df -h /'

# 查看注册表
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'cat /opt/.server/registry.json'

# 查看自己的目录大小
ssh -o StrictHostKeyChecking=no <用户名>@115.191.7.64 'du -sh /opt/<用户名>/*'
```

---

## 权限隔离说明

| 资源 | 隔离方式 | 强度 |
|------|----------|------|
| 项目目录 `/opt/<用户名>/` | Linux 文件权限 750 | **硬隔离** — 系统拒绝跨用户访问 |
| systemd 服务 | sudoers 限制只能操作 `<用户名>-*` | **硬隔离** — sudo 拒绝越权操作 |
| Nginx 配置 | sudoers 限制只能写自己的文件 | **硬隔离** — sudo 拒绝写别人的配置 |
| 注册表 registry.json | deployers 组共享写入 | **软隔离** — 靠规则约束只改自己的记录 |
| 日志、服务状态查看 | 允许查看所有（只读） | 开放 — 方便排查关联问题 |

---

## 红线

### 普通用户（系统层面已阻止）

1. **别人的目录** `/opt/<别人>/` — 系统拒绝访问
2. **别人的服务** — sudo 拒绝操作非本人前缀的服务
3. **别人的 Nginx 配置** — sudo 拒绝写入
4. **SSH 配置** `/etc/ssh/` — 无权限，找管理员
5. **防火墙** `ufw` — 无权限，找管理员
6. **系统级操作**（apt install、内核参数等）— 无权限，找管理员
7. **`/opt/.server/`** — registry.json 可更新（仅添加自己的记录），其他只读

### 管理员（khazix）

可以执行以上所有操作，但应确认操作意图后再执行。

## 磁盘注意

总磁盘 50G：
- 用 `npm install --production` 避免装 devDependencies
- 本地 build 好再上传，别在服务器上跑 build
- 及时清理临时文件和旧日志
- 大文件不要留在服务器上

## 遇到问题

公共配置相关的问题找管理员 khazix，不要自己改。

## 操作原则

1. **先读规范** — 每次操作前读 SERVER-RULES.md 和 registry.json
2. **数据安全** — 数据文件（db、json）不要 scp 覆盖，用 API 操作
3. **先备份再改** — 改 Nginx 等配置前先备份
4. **验证结果** — 每次部署后 curl 验证
5. **更新注册表** — 新项目/端口变更后更新 registry.json
6. **出问题先止血** — 先停服务/回滚配置，再排查原因

---

## 管理员指南（仅 khazix）

### 初始化服务器（只需一次）

将脚本上传到服务器并执行初始化：

```bash
scp -o StrictHostKeyChecking=no setup-user.sh register.sh init-server.sh root@115.191.7.64:/opt/.server/
ssh -o StrictHostKeyChecking=no root@115.191.7.64 'bash /opt/.server/init-server.sh'
```

初始化完成后，同事收到 SKILL.md 即可自助注册，无需管理员介入。

### 邀请码管理

```bash
# 查看当前邀请码
ssh -o StrictHostKeyChecking=no root@115.191.7.64 'cat /opt/.server/invite_code'

# 换一个新邀请码（旧码立即失效，已注册用户不受影响）
ssh -o StrictHostKeyChecking=no root@115.191.7.64 'openssl rand -hex 4 > /opt/.server/invite_code && cat /opt/.server/invite_code'
```

### 手动添加用户（如果自助注册有问题）

```bash
ssh -o StrictHostKeyChecking=no root@115.191.7.64 '/opt/.server/setup-user.sh <用户名>'
ssh -o StrictHostKeyChecking=no root@115.191.7.64 'echo "ssh-ed25519 AAAA..." >> /opt/<用户名>/.ssh/authorized_keys'
```

### 删除用户

```bash
ssh -o StrictHostKeyChecking=no root@115.191.7.64 'userdel <用户名> && rm -f /etc/sudoers.d/deploy-<用户名>'
```

注意：这不会删除 `/opt/<用户名>/` 目录和相关服务，需要手动确认后再清理。

### 吊销注册密钥

如果注册密钥泄露到团队外部，从 root 的 authorized_keys 中删除 `register@virxact` 那行：

```bash
ssh -o StrictHostKeyChecking=no root@115.191.7.64 "sed -i '/register@virxact/d' /root/.ssh/authorized_keys"
```

然后生成新密钥对，更新 SKILL.md 中的密钥内容，重新初始化。
