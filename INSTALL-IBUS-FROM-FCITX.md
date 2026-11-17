# 从 Fcitx 首次切换到 IBus + Rime AppImage

适用：麒麟 V10 SP1 arm64，当前使用 Fcitx4/Fcitx5，从未安装或启动过 IBus，桌面会话为 X11。

安装顺序是 **系统 IBus 框架和前端 → 临时切换 → 注册 Rime AppImage → 验证 → 登录持久化 → 导入雾凇**。AppImage 已携带 Rime 引擎及相关库，但不会安装 IBus 框架。

## 1. 保持 Fcitx 可用，先安装系统 IBus

先查看麒麟源是否提供框架包：

```bash
apt-cache policy ibus ibus-gtk3 ibus-gtk im-config
```

使用当前麒麟源更新索引并模拟安装：

```bash
sudo apt-get update
sudo apt-get -s --no-remove install ibus ibus-gtk3
```

确认没有非预期删除、没有要求替换系统 Qt、GLib、glibc 或 UKUI 后，执行：

```bash
sudo apt-get --no-remove install ibus ibus-gtk3
```

- `ibus`：守护进程、控制命令和设置界面等核心组件。
- `ibus-gtk3`：GTK3 应用的输入模块。
- `ibus-gtk`：有 GTK2 应用时再安装，包名以麒麟源实际提供的为准。
- `im-config`：登录输入法选择工具，可选；已有时直接使用。
- Qt5 应用使用 Qt 自身的 IBus 输入上下文插件，需要目标 Qt 构建实际包含它；不用寻找名为 `ibus-qt5` 的包。

此路线由 AppImage 提供 Rime，APT 安装目标中无需加入 `ibus-rime` 或系统 `librime`。安装 IBus 时先保留 Fcitx，待测试成功后再切换自启动；不卸载 Fcitx。

验证命令可用：

```bash
command -v ibus
command -v ibus-daemon
command -v ibus-setup
ibus version
```

如果安装后只在某些 Qt5 应用中无效，可检查系统 Qt 插件文件；这不影响先验证 kitty 的 IBus 通路：

```bash
dpkg -L libqt5gui5:arm64 | grep -i ibus
```

## 2. 如果麒麟源连 IBus 框架也缺包

AppImage 无法补齐这个前提。需要从同版麒麟官方源、官方介质对应的软件仓库，或同版同更新级别的联网麒麟 arm64 环境获得 IBus 系统包及依赖。不能仅凭 glibc 2.31 就把 Debian bullseye 的整个 IBus/GTK/GLib 包集混入麒麟。

推荐使用目标系统克隆作为下载环境，保持安装状态一致。在联网克隆环境用**麒麟源**执行：

```bash
sudo apt-get update
sudo apt-get --download-only --no-install-recommends --no-remove install ibus ibus-gtk3
```

将解析得到的所需 deb 从 `/var/cache/apt/archives/` 复制到单独目录，生成 `sha256sum ./*.deb > SHA256SUMS`，带回目标机。克隆机如果已经安装了目标机缺少的依赖，APT 会跳过它们，包集可能不完整；以目标机模拟结果为准。

在离线目标机、deb 目录中执行：

```bash
sha256sum -c SHA256SUMS
sudo apt-get -s --no-download --no-remove install ./*.deb
```

解决全部缺依赖并检查安装计划后再执行：

```bash
sudo apt-get --no-download --no-remove install ./*.deb
```

不要使用 `dpkg --force-depends`。如果没有任何可获得的同版麒麟 IBus 框架包，当前方案仍缺前提，需要另行解决框架打包；现有 Rime AppImage 不能独立承担这个角色。

## 3. 备份登录配置

以下都在目标机器当前登录桌面的普通用户终端执行，不用 sudo 或 SSH 代替桌面会话。

```bash
switch_backup="$HOME/ibus-switch-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$switch_backup"
for item in .xinputrc .xprofile .profile .config/autostart .config/ibus; do
  if [ -e "$HOME/$item" ]; then
    cp -a --parents "$HOME/$item" "$switch_backup/"
  fi
done
printf '备份：%s\n' "$switch_backup"
```

## 4. 临时切换并安装 AppImage

先按 [AppImage 安装指南](INSTALL-IBUS-RIME-ARM64.md) 第 1 节完成下载、校验，将文件固定放在 `~/Applications/ibus-rime-bullseye-aarch64.AppImage`。

退出当前用户的 Fcitx，再在当前终端设置环境并启动 IBus：

```bash
pkill -u "$(id -u)" -x fcitx5 || true
pkill -u "$(id -u)" -x fcitx || true

export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export GLFW_IM_MODULE=ibus

ibus-daemon -drx
"$HOME/Applications/ibus-rime-bullseye-aarch64.AppImage"
```

AppImage 首次不带参数运行，负责注册 Rime 和部署基础数据。安装成功后执行：

```bash
ibus restart
ibus-setup
```

在设置界面添加“中文 → Rime/中州韵”，然后：

```bash
ibus list-engine
ibus engine rime
kitty -o linux_display_server=x11
```

验证新 kitty 能输入中文。默认数据为精简朙月拼音，可能默认输出繁体字。没有 FUSE 时的提取执行方法见 [AppImage 安装指南](INSTALL-IBUS-RIME-ARM64.md) 第 3 节；该模式下 IBus 守护进程也需要继承相应变量。

## 5. 测试成功后再持久化

若 `im-config -l` 列出 `ibus`，以当前桌面用户执行：

```bash
im-config -n ibus
```

检查此前设置过的 `~/.xprofile`、`~/.profile`，将会生效的输入法变量统一为：

```bash
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export GLFW_IM_MODULE=ibus
```

在麒麟“启动应用”中停用 Fcitx4/Fcitx5 自启动。若 im-config/桌面已有 IBus 启动机制就不重复添加；否则添加 `ibus-daemon -drx`。注销重登后再验证 kitty、GTK/Qt 应用和托盘。

成功后按 [雾凇候选方案](CANDIDATE-IBUS-RIME.md) 导入小鹤、全拼和自定义短语。回退时恢复备份的登录配置和 Fcitx 自启动，不需要卸载任一框架。

## 日志反馈

目前没有收到此次安装的实际报错，尚不能判断其原因。日志中 `ibus: command not found`、`ibus not found!`、动态库缺失、D-Bus 连接失败和 Rime 注册失败是不同症状。反馈时保留完整报错及前后几行，注明在哪条命令出现，不要只提供“安装失败”。
