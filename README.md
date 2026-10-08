# sing-box 原版 Bash 本地加固版

基于 [fscarmen/sing-box](https://github.com/fscarmen/sing-box) v1.3.25，保留原 Bash 菜单、配置编辑、协议增删、服务管理和各客户端导出逻辑。没有 Python 运行时或 Python 管理器。上游固定提交与原文件 SHA-256 见 [upstream.json](upstream.json)，修改日期为 2026-10-08，沿用 GPL-3.0 许可证。

## 安全修改

- `sb` 只运行本地保存的 Bash 文件；删除在线脚本入口及 BBR、ArgoX、SBA、TCP 优化脚本的下载执行。原菜单项仍显示，但明确标为已停用。
- 删除 Reality 私钥上传接口。保留本地 OpenSSL/xxd 转换；缺失依赖由系统软件源自动安装。
- 删除脚本运行次数上报、日常菜单的 IP 信息查询和 OpenAI 解锁探测。首次安装未指定 `--SERVER_IP` 时，仅通过 Cloudflare HTTPS trace 查询公网 IP，不发送配置或密钥。
- 禁止脚本和已安装内核自动更新。首次安装从官方 GitHub Release 下载固定版本 sing-box，选择 Argo 时下载固定版本 cloudflared；均校验代码中固定的 SHA-256，校验失败拒绝执行。`sb -v` 只查询本地版本。
- 本地固定订阅模板；不从浮动分支自动下载模板。Clash 默认关闭 LAN 访问，控制端口仅监听回环地址。
- 删除第三方二维码链接和未经源码审查的二维码二进制调用。无订阅服务时，Clash 两种导出均为独立配置。
- 停用新的公开 HTTP 订阅服务；客户端导出文件仍保留。已有订阅服务不会被此补丁自动关闭，需自行迁移或在原菜单中关闭。
- 停用在线 WARP 注册及共享私钥回退；已有 WARP 配置及手动输入个人账户的功能保留。
- 停用脚本代办 Cloudflare 隧道创建；已有隧道管理保留。
- 删除启动和查看节点时隐式迁移配置、重启服务、重新签发证书的逻辑。
- 使用随机私有临时目录和 `umask 077`；本地入口清理继承环境并加互斥锁。sed 表达式通过私有文件传入，避免凭据出现在 sed 进程参数中。
- 修改节点信息时，只修改配置、订阅和节点列表，避免原来的全目录替换误改脚本、二进制及备份。

## 使用

支持全新安装和管理已有的 fscarmen sing-box 安装。基础依赖（包括 jq、curl、OpenSSL、xxd、ip/ss、flock）由系统软件源自动安装；缺失的 `/etc/sing-box/jq` 会自动补齐。

下载完整仓库后，一条命令自动完成依赖安装、内核下载校验、证书与配置生成、服务启动和本地 `sb` 入口部署：

```sh
git clone https://github.com/gallexy-liu/sing-bash.git
cd sing-bash
sudo bash install-local.sh
```

默认安装 Reality + Hysteria2，起始端口 8881，自动生成凭据与本地私钥，不注册 WARP，不开启公开 HTTP 订阅或 Argo。公网 IP 自动检测失败会停止并提示指定地址。NAT、端口映射或使用域名时应显式指定：

```sh
sudo bash install-local.sh --SERVER_IP proxy.example.com --START_PORT 40101
```

也可运行 `sudo bash sing-box.sh` 使用原版交互菜单；`sudo bash sing-box.sh --install` 为无人值守安装。用 `--CHOOSE_PROTOCOLS bc` 选择 Reality + Hysteria2，其他协议仍沿用原菜单的字母编号；WS 等协议需要相应域名参数。`--ARGO true` 才安装 cloudflared。`--SUBSCRIBE true` 仍拒绝开启不安全的公开 HTTP 订阅。

首次安装固定 sing-box **1.15.0-alpha.9**（原版生成器使用 1.15 配置字段），可选 cloudflared **2026.10.0**。不会查询 latest 或升级已有内核。支持的发布包架构为 amd64、arm64、armv7 及 Alpine musl 变体。

已有配置或服务时，`sing-box.sh --install` 拒绝覆盖；`install-local.sh` 则仅修复缺失依赖并更新本地管理入口。日常管理：

```sh
sudo sb           # 原 Bash 菜单
sudo sb -d        # 原配置编辑菜单
sudo sb -r        # 原协议增删菜单
sudo sb -n        # 导出节点：含凭据，仅限 root 查看
sudo sb -v        # 查看本地内核版本
sudo sb --check   # 校验服务端配置
```

`-s` 仍按原版切换服务启停；`-u` 仍为卸载并删除配置。管理入口安装器保存原管理入口到 root 专用的 `/var/backups/sing-box-bash.*`，已有安装的管理入口更新不修改节点配置和证书，不重启服务。之前的 Python 版本如已存在会保留作回退，但新的 `sb` 不再调用它。

## 仍保留的联网行为

首次安装会访问系统软件源、官方 GitHub Release，以及未指定服务器地址时的 Cloudflare 公网 IP 查询接口。私钥始终本地生成，不发送到上述下载和地址查询接口。这不是整个代理服务的离线模式。添加自定义路由规则时，脚本可通过校验 TLS 的 HTTPS 请求读取 GitHub 官方 API 的规则目录；这两个固定请求不包含节点凭据。菜单可读取本机回环地址上的流量统计和 cloudflared 指标。已有 cloudflared 服务仍按其配置连接 Cloudflare。路由规则数据仍可按客户端或服务端原配置更新，未将其误当作 Shell 代码更新删除。用户明确修改功能时，原版防火墙等分支仍可能通过系统包管理器安装依赖。

## 验证

```sh
bash -n sing-box.sh
sudo bash test-local.sh
sudo bash tests/download-integrity.sh
sudo bash tests/fresh-config.sh
```

测试使用 root 私有的临时配置副本，在无网络命名空间中运行原 Bash 导出逻辑，核对客户端节点参数及服务端配置/证书内容，并检查导出权限。测试不会修改运行中服务。只覆盖当前已有节点组合，并非所有协议和发行版的完整回归测试。

`tests/download-integrity.sh` 使用模拟下载验证校验成功、摘要不匹配、下载失败和不允许的来源；失败时保留原目标文件。`tests/fresh-config.sh` 在私有临时目录复用已有内核，验证缺失 jq 的准备流程、Reality/Hysteria2 配置与证书生成、客户端导出、有 TUN 但无 WARP 账户及重复安装保护。它模拟包管理器和服务操作，不启动容器或代理服务。受测试机器内存限制，尚未完成干净系统上的真实下载、依赖安装及服务启动全流程验证。

不要提交 `/etc/sing-box`、订阅导出、私钥、账号文件、运行日志或服务器备份到 GitHub。
