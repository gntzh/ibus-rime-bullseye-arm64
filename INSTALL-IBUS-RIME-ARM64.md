# 安装已构建的 arm64 ibus-rime AppImage

目标：Debian 11 bullseye arm64，以及待实机验证的麒麟 V10 SP1 arm64（glibc 2.31）。

下载：[GitHub Releases](https://github.com/gntzh/ibus-rime-bullseye-arm64/releases)。构建源码和自动检查流程：[构建说明](packaging/ibus-rime/README.md)。

## 包含与前提

包含 ibus-rime 1.6.1、librime 1.17.0、Lua/Octagram/Charcode 插件、基础拼音数据和私有 C++ 运行库。不包含 IBus 框架、雾凇配置及可选的大型语法模型。

系统必须已有可用的 IBus 1.5 及其桌面依赖；先确认 `ibus version` 能正常执行。旧源缺少 Rime 引擎可由这个包解决，缺少 IBus 框架本身仍需另行补齐。

## 1. 下载、校验并固定位置

下载 AppImage、`SHA256SUMS`、`BUILD-INFO.txt` 和 `VERIFICATION.txt`，放在同一目录，执行：

```bash
sha256sum -c SHA256SUMS
mkdir -p "$HOME/Applications"
cp ibus-rime-bullseye-aarch64.AppImage "$HOME/Applications/"
chmod +x "$HOME/Applications/ibus-rime-bullseye-aarch64.AppImage"
```

安装注册后不要移动或删除 AppImage，IBus 组件会引用这个绝对路径。`BUILD-INFO.txt` 记录源码及构建包版本，`VERIFICATION.txt` 保存容器自动检查输出。

## 2. 在当前桌面用户下试用

不要以 root 或 SSH 会话代替桌面终端。先备份已有的 `~/.config/ibus/rime` 和登录输入法配置。

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

最后一条不带参数的命令负责安装注册和默认数据部署。看到成功通知后，执行 `ibus restart`，再运行 `ibus-setup`，添加“中文 → Rime/中州韵”。

```bash
ibus list-engine
ibus engine rime
kitty -o linux_display_server=x11
```

先在新 kitty 中验证基础拼音输入。默认附带的是精简朙月拼音，可能默认输出繁体字；导入雾凇后再使用其简体全拼或小鹤双拼。

## 3. 没有 FUSE 时

该 AppImage 的运行时支持提取后执行。当前用户没有其他 IBus 输入任务时，可退出现有 IBus，在同一终端执行：

```bash
ibus exit
export APPIMAGE_EXTRACT_AND_RUN=1
ibus-daemon -drx
"$HOME/Applications/ibus-rime-bullseye-aarch64.AppImage"
```

然后继续配置和测试。如果采用此方式，登录自启动的 IBus 也必须继承 `APPIMAGE_EXTRACT_AND_RUN=1`；只在安装时临时设置一次不够。优先使用系统正常的 FUSE 启动方式。

## 4. 导入雾凇与持久化

按 [IBus + Rime + 雾凇方案](CANDIDATE-IBUS-RIME.md) 第 4～7 节配置登录启动、小鹤/全拼、自定义短语和重新部署。

雾凇文件放在 `~/.config/ibus/rime/`，保留安装器创建的 `appimage/` 目录。先完成备份，避免清空用户词库。不要将 Fcitx5 的配置路径用于 IBus。

## 验证范围

已在干净的 bullseye arm64 容器检查包内 ELF 架构、GLIBC <= 2.31、动态库依赖、无 FUSE 提取执行、默认数据部署、三个插件注册，并验证 Lua 生成中文候选和提交。

容器检查不代替麒麟桌面验证：安装通知、托盘、候选窗位置、kitty 实际键盘输入及注销重登仍需在目标机器测试。若需要回退，恢复原登录环境和 Fcitx5 自启动；原来的 Fcitx5 安装包无需卸载。
