# 候选方案：IBus + Rime + 雾凇拼音

适用目标：银河麒麟 V10 SP1 2203、arm64、glibc 2.31，优先使用已验证可运行 kitty 的 X11 会话。本文是供选择的实施方案，尚未在目标机器执行。现有 [Fcitx5 简单方案](SIMPLE.md) 保留作为回退。

2026-11-17 补充：用户确认目标 apt 源的 IBus/Rime 包也有缺失，当前优先考虑路线 B 的 arm64 构建；路线 A 保留为包可获得时的参考。AppImage 仍依赖主机 IBus，不能把缺失的 IBus 框架一并视为已解决。[Fcitx5-Rime 便携方案核对](CANDIDATE-FCITX5-RIME-PORTABLE.md) 另列。

构建进展：本项目已自行打包 Debian bullseye aarch64 AppImage，并通过干净 bullseye arm64 容器中的依赖、GLIBC、部署和 Lua 中文候选/提交检查。实际安装以 [构建与安装说明](packaging/ibus-rime/README.md) 为准。下文“上游无 arm64 成品”仍成立，但不再代表本项目没有产物；麒麟桌面集成尚待目标机验证。

## 路线与当前限制

推荐顺序：

1. 使用麒麟源的 IBus + ibus-rime，先验证 Rime 基础输入。
2. 核对 librime 与 Lua 插件，再离线导入雾凇，启用全拼、小鹤双拼和自定义短语。
3. 系统 Rime 太旧或缺插件时，考虑 [hchunhui/ibus-rime.AppImage](https://github.com/hchunhui/ibus-rime.AppImage)。

**AppImage 存在架构前提：截至 2026-11-16 核对，项目的 `continuous`、`legacy` 发布均只有 `ibus-rime-x86_64.AppImage` 和其 minimal 版本，没有 arm64/aarch64 二进制。不能下载 x86_64 包在这台机器直接执行。**

项目标明需要 IBus 1.5、glibc >= 2.27 和 FUSE2/3；目标 glibc 2.31 满足其公布的 glibc 下限，但不解决架构不匹配。若未来发布 arm64 包，或自行构建并验证 arm64 产物，再执行本文后备流程。现有打包脚本还写死了 x86_64 的 appimagetool，不能把“克隆后直接运行 build.sh”当成已可用的 arm64 构建方法。

## 1. 准备与备份

在目标桌面普通用户终端记录环境：

```bash
dpkg --print-architecture
ldd --version | head -1
printf 'session=%s desktop=%s\n' "$XDG_SESSION_TYPE" "$XDG_CURRENT_DESKTOP"
ibus version
apt-cache policy ibus ibus-rime librime1 librime-plugin-lua librime-lua
```

包名可能因麒麟仓库而不同，可用 `apt-cache search librime` 查找实际插件。记录安装前状态：

```bash
ibus_backup="$HOME/ibus-candidate-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ibus_backup"
for item in .xinputrc .xprofile .profile .config/fcitx5 .config/ibus .config/autostart; do
  if [ -e "$HOME/$item" ]; then
    cp -a --parents "$HOME/$item" "$ibus_backup/"
  fi
done
dpkg-query -W > "$ibus_backup/packages-before.txt"
if command -v gsettings >/dev/null; then
  gsettings list-recursively org.freedesktop.ibus.general \
    > "$ibus_backup/ibus-general-before.txt" 2>/dev/null || true
fi
printf '备份目录：%s\n' "$ibus_backup"
```

将输出路径保存下来。若是 Wayland，本文 X11 环境变量与启动方式不能直接作为原生 Wayland 方案。

## 2. 路线 A：系统包

使用目标机原有麒麟源。先模拟，确认没有非预期删除、没有替换系统 Qt、glibc 或 UKUI，再安装：

```bash
sudo apt-get -s --no-remove install ibus ibus-rime
sudo apt-get --no-remove install ibus ibus-rime
```

如果源提供 `librime-plugin-lua`，按同样方式模拟后安装；若实际叫其他名字，以仓库为准。没有 Lua 插件时可先测基础 Rime，暂不导入完整雾凇。

### 完全离线安装

在联网的**同版、同更新级别、同 arm64 架构且安装状态一致的目标系统克隆**中，用麒麟源执行：

```bash
sudo apt-get update
sudo apt-get --download-only --no-remove install ibus ibus-rime
# 如果仓库提供 Lua 插件，还要按实际包名下载它及依赖。
```

将本次需要的 `/var/cache/apt/archives/*.deb` 复制到单独目录，生成 `sha256sum ./*.deb > SHA256SUMS`，带回目标机。在目标目录执行：

```bash
sha256sum -c SHA256SUMS
sudo apt-get -s --no-download --no-remove install ./*.deb
sudo apt-get --no-download --no-remove install ./*.deb
```

模拟不通过则补齐缺失的精确版本依赖后再安装。APT 不会下载克隆机已经满足的依赖；不要用安装状态不同的机器来判断包集完整性。系统已满足的包无需重新安装，不混入 Debian/Ubuntu 其他发行版源。

## 3. 临时切换到 IBus，先测基础 Rime

先退出当前用户的 Fcitx5/Fcitx4，不卸载包：

```bash
pkill -u "$(id -u)" -x fcitx5 || true
pkill -u "$(id -u)" -x fcitx || true

export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export GLFW_IM_MODULE=ibus

ibus-daemon -drx
ibus-setup
```

`ibus-setup` 中添加“中文 → Rime/中州韵”，名称可能随版本变化。可用以下命令确认引擎并选择：

```bash
ibus list-engine
ibus engine rime
GLFW_IM_MODULE=ibus kitty -o linux_display_server=x11
```

若列表没有 `rime`，先解决组件安装/注册问题，不导入雾凇。若发行版要求通过注销重登启动 IBus，则使用下一节的登录配置后再测。

在新 kitty 和普通 GTK 编辑器分别测试。基础 Rime 能输入、候选窗正常，才能确认 IBus/kitty 通路已经建立。系统 Rime 默认可能是繁体方案，这是基础测试阶段的正常现象。

## 4. 登录后固定使用 IBus

在麒麟输入法管理或“启动应用”中停用原有 Fcitx4/Fcitx5 自启动。保留其配置和安装包。若 `im-config -l` 包含 `ibus`，执行：

```bash
im-config -n ibus
```

检查 `~/.xprofile`、`~/.profile` 中原有的 Fcitx 设置，将会生效的输入法变量统一为：

```bash
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export GLFW_IM_MODULE=ibus
```

优先修改之前实际使用的 `~/.xprofile`，不要同时保留互相覆盖的两组值。kitty 配置继续使用 `linux_display_server x11`。

若 im-config 不可用，在“启动应用”中添加 `ibus-daemon -drx`；已有发行版 IBus 自启动就不重复添加。注销重登后确认 Fcitx5/Fcitx4 没有同时启动，kitty 能输入中文。

## 5. 导入雾凇：联网下载、目标机离线部署

雾凇官方文档的基础要求为 librime >= 1.8.5 并包含 librime-lua；部分功能要求更高版本。以所选雾凇版本文档为准，不能仅凭 `ibus-rime` 已安装就判断兼容。

联网机器从 [雾凇 Releases](https://github.com/iDvel/rime-ice/releases) 选择一个版本，下载其完整 `full.zip`，记录版本、来源和 SHA256。日后更新也固定版本，不在离线步骤里调用 plum/git 下载依赖。

停止 Rime 写入：先上屏未完成的内容，再执行 `ibus exit`。将 IBus 的整个 Rime 用户目录备份，然后解压到临时目录：

```bash
if [ -d "$HOME/.config/ibus/rime" ]; then
  cp -a "$HOME/.config/ibus/rime" \
    "$HOME/.config/ibus/rime.before-ice-$(date +%Y%m%d-%H%M%S)"
fi
```

检查解压后含 `rime_ice.schema.yaml`、`double_pinyin_flypy.schema.yaml`、`lua/`、`cn_dicts/` 等文件。将**这些文件所在目录的内容**复制到 `~/.config/ibus/rime/`，不要多套一层 `full/` 或仓库名目录。

首次使用建议干净导入：系统包路线可将旧的 `rime` 目录改名保存，再创建新目录；AppImage 路线必须保留 `rime/appimage/`，因为它保存组件注册文件。两条路线均不要把旧的 `build/` 编译缓存混入新方案。不要将 Fcitx5 的配置目录当成 IBus 的用户目录。

### 只保留小鹤双拼与全拼

在 `~/.config/ibus/rime/default.custom.yaml` 中设置；已有 `patch:` 时合并到同一个映射：

```yaml
patch:
  schema_list:
    - schema: double_pinyin_flypy
    - schema: rime_ice
  menu/page_size: 5
  switcher/hotkeys:
    - F4
    - Control+grave
  ascii_composer/switch_key/Shift_L: commit_code
  ascii_composer/switch_key/Shift_R: noop
```

`Shift_L` 在有未上屏输入时会提交原始编码后切英文。若不希望误提交，可改成 `clear`（丢弃未上屏内容）；不希望 Shift 切换则设为 `noop`，改用方案菜单中的中/英文开关。

按当前上游的双拼适配方式，另建两个补丁文件；如果选用的历史版本格式不同，以该版本文档为准：

`melt_eng.custom.yaml`：

```yaml
patch:
  speller/algebra:
    __include: melt_eng.schema.yaml:/algebra_double_pinyin_flypy
```

`radical_pinyin.custom.yaml`：

```yaml
patch:
  speller/algebra:
    __include: radical_pinyin.schema.yaml:/algebra_double_pinyin_flypy
```

这两个补丁适配英文符号派生及拆字反查/辅码，基础小鹤键位已经包含在小鹤方案内。首先不安装可选的大型语法模型，先验证基本输入和 Lua。

## 6. 自定义短语

与 Fcitx5 QuickPhrase 不同，雾凇可让短语直接进入普通输入候选。建议全拼和双拼共用独立文件，避免更新覆盖：

`rime_ice.custom.yaml` 和 `double_pinyin_flypy.custom.yaml` 都加入：

```yaml
patch:
  custom_phrase/user_dict: my_phrases
```

若已有补丁，则合并，不覆盖其他设置。在用户目录创建 `my_phrases.txt`。下面命令演示**新建**文件并确保分隔符为真实 Tab，已有文件时请编辑或追加而非覆盖：

```bash
printf '# Rime table\n# coding: utf-8\n#@/db_name\tmy_phrases.txt\n#@/db_type\ttabledb\n\nname@example.com\tyx\t100\n上海市某区某路123号\tdz\t100\n你好，收到后我会尽快回复。\thh\t100\n' \
  > "$HOME/.config/ibus/rime/my_phrases.txt"
```

格式为“输出内容 Tab 编码 Tab 权重”，不是 QuickPhrase 的“编码 空格 内容”。编码可自定义；尽量选择不干扰常用字词的缩写。如果希望原生词条参与学习、组句，不要用同一完整拼音编码把它固定成自定义短语，候选置顶应另用雾凇的置顶功能。

## 7. 部署与使用

启动 IBus，选择 Rime，然后在 Rime 托盘菜单点“重新部署”：

```bash
ibus-daemon -drx
ibus engine rime
```

首次部署词典可能需要等待。重新部署与重启 IBus 是两件事；修改方案或短语后应执行“重新部署”。

| 操作 | 建议方式 |
|---|---|
| 普通中文/英文切换 | 左 Shift，在没有待上屏内容时切换最清楚 |
| 小鹤双拼/全拼切换 | F4 或 Ctrl+反引号，打开 Rime 方案菜单选择 |
| 快速短语 | 中文模式直接输入 yx、dz、hh 后选词 |
| 纯英文程序输入 | 切到 Rime 英文模式，或用 IBus 快捷键切到英文键盘 |

在 `ibus-setup` 的快捷键设置中明确 IBus 框架的切换键，例如 Super+Space。不要让 IBus 和 Rime 用同一快捷键承担两种切换。桌面已有占用时换键。

验收：小鹤输入 `nihk`、全拼输入 `nihao` 都可选“你好”；`yx` 出现邮箱；测试 `date` 是否出现日期以初步确认所选版本的日期 Lua 正常（历史版本触发码可能不同）；kitty、GTK、Qt 应用都能输入；注销重登仍有效。

## 8. 路线 B：系统 Rime 不够用时改 AppImage

### 架构门槛

当前上游没有可直接用的 arm64 发布资产。本项目后续已构建并完成 bullseye 容器检查，下载与安装见 [arm64 安装指南](INSTALL-IBUS-RIME-ARM64.md)。AppImage 只替换 Rime 引擎及其打包依赖，系统 IBus 仍然需要安装。

本项目的移植使用联网的原生 arm64 runner 和 Debian bullseye 容器，替换写死的 x86_64 打包工具和运行时，记录 ibus-rime/librime/插件/依赖源码版本，并检查 GLIBC <= 2.31。交付文件包括 aarch64 AppImage、源码版本清单、验证记录和 SHA256；实际引擎注册和候选窗仍需在目标桌面验证。

### 有合适 arm64 产物后的安装步骤

1. 备份 `~/.config/ibus/rime`，将 AppImage 放在固定路径，例如 `~/Applications/ibus-rime-aarch64.AppImage`。
2. 执行 `file ~/Applications/ibus-rime-aarch64.AppImage`，应显示 ARM aarch64 ELF；校验提供者给出的 SHA256，添加可执行权限。
3. 在普通桌面用户下执行该 AppImage **不带参数**，按项目安装流程完成注册，看到成功提示后重启 IBus，在 `ibus-setup` 中添加/选择 Rime。
4. 先测试基础 Rime，再按前述方法放入雾凇；保留用户目录中的 `appimage/` 注册目录，执行重新部署。

安装后不能移动或删除 AppImage，注册的引擎会引用这个绝对路径。FUSE 挂载失败时先解决本机 FUSE 条件；不要把随意解包执行当成已验证的替代安装方法。

系统包和 AppImage 都可能注册名为 `rime` 的引擎。出现注册冲突时，先在 IBus 中移除 Rime、停止 IBus，检查 `~/.config/ibus/rime/appimage/rime.xml` 与系统组件文件，再决定保留哪个。必要时仅模拟移除 `ibus-rime` 包，确认不牵连桌面后再移除；不要卸载 IBus 框架。

AppImage 内置工具可用 `~/Applications/ibus-rime-aarch64.AppImage help` 查看，版本清单可尝试其 `version` 工具。不要用系统旧版部署工具来编译新版 AppImage 的方案；优先使用运行中 Rime 的“重新部署”。

## 9. 排查与回退

没有候选/没有 Rime：检查 `ibus list-engine`、`ibus engine`，确认只运行一种框架。分享诊断前检查日志中的用户名和路径。

```bash
ibus version
ibus engine
pgrep -a -u "$(id -u)" -x ibus-daemon
pgrep -a -u "$(id -u)" -x fcitx5
pgrep -a -u "$(id -u)" -x fcitx
dpkg-query -W 'ibus*' 'librime*' 2>/dev/null
ls -l ~/.config/ibus/rime/build
```

Rime 基础输入正常而雾凇失败：优先检查部署日志里的 Lua、插件、缺文件和 YAML 错误，核对固定的雾凇版本与引擎版本；不要仅通过换快捷键排查引擎错误。

回到已验证的 Fcitx5：

1. 退出 IBus，在输入法管理中恢复 Fcitx5（支持时 `im-config -n fcitx5`）。
2. 停用本次新增 IBus 自启动，恢复原 Fcitx5 自启动。
3. 从第 1 节备份中恢复原 `.xprofile`/`.xinputrc` 等本次修改的文件，以及需要恢复的 IBus 设置；备份使用 `cp --parents`，保留原路径层级。
4. 确认环境回到 `GTK_IM_MODULE=fcitx`、`QT_IM_MODULE=fcitx`、`XMODIFIERS=@im=fcitx`；kitty 的 `GLFW_IM_MODULE=ibus` 保留。
5. 注销重登，按 [SIMPLE.md](SIMPLE.md) 验证小鹤。此方案不要求卸载 Fcitx5，切换 IBus 不会自动迁移原来的 Fcitx5 用户词库。

卸载 AppImage 时先按项目说明从 IBus 移除 Rime，保存用户词库与短语，再处理 AppImage 和其注册/缓存；不能只删 AppImage 留下失效引擎路径。

## 资料与验证范围

- [IBus-Rime 官方项目](https://github.com/rime/ibus-rime)：系统包路线与运行依赖。
- [kitty 输入法变量](https://sw.kovidgoyal.net/kitty/glossary/#envvar-GLFW_IM_MODULE)：X11 下启用 IBus 协议。
- [雾凇安装要求](https://github.com/iDvel/rime-ice/blob/main/others/docs/Installation.md)：引擎/插件要求及手动离线导入。
- [雾凇默认配置](https://github.com/iDvel/rime-ice/blob/main/default.yaml)、[自定义短语格式](https://github.com/iDvel/rime-ice/blob/main/custom_phrase.txt)。
- [AppImage 项目说明](https://github.com/hchunhui/ibus-rime.AppImage)、[发布资产](https://github.com/hchunhui/ibus-rime.AppImage/releases)、[打包脚本](https://github.com/hchunhui/ibus-rime.AppImage/blob/master/build.sh)。

已完成文档、上游发布信息核对及本项目 AppImage 的 bullseye arm64 容器检查，未执行目标机安装。下文历史架构说明针对上游发布；系统包候选版本、麒麟桌面集成和雾凇部署以目标机验收为准。
