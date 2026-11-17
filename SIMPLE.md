# 简单方案：Fcitx5 + 小鹤双拼 + kitty

适用：银河麒麟 V10 SP1 2203、arm64、X11。直接使用系统已安装的包，无需下载 Debian 包或安装图形配置工具。

已由用户验证：kitty 中文输入、小鹤双拼均成功。下面的全拼/双拼切换快捷键、QuickPhrase 是可选配置，尚未收到目标机验证结果。

## 1. 修改前先退出、备份

在桌面普通用户终端执行，不使用 sudo：

```bash
pkill -u "$(id -u)" -x fcitx5 || true
```

确认 `pgrep -a -u "$(id -u)" -x fcitx5` 没有输出后再备份：

```bash
cp -a ~/.config/fcitx5 ~/.config/fcitx5.backup-$(date +%Y%m%d-%H%M%S)
mkdir -p ~/.config/fcitx5/conf
```

## 2. 输入法列表

`~/.config/fcitx5/profile`：英文放第一位，中文默认使用双拼，同时保留全拼。

```ini
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=shuangpin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=shuangpin
Layout=

[Groups/0/Items/2]
Name=pinyin
Layout=

[GroupOrder]
0=Default
```

## 3. 小鹤双拼

`~/.config/fcitx5/conf/pinyin.conf` 文件开头、任何 `[节名]` 之前设置；已有选项就修改原值：

```ini
ShuangpinProfile=Xiaohe
PageSize=5
CloudPinyinEnabled=False
```

输入法列表使用 `shuangpin`，配置文件仍然叫 `pinyin.conf`。这里是小鹤双拼音码，不包含小鹤音形辅助码。

## 4. 切换快捷键（可选，待目标机验证）

编辑 `~/.config/fcitx5/config`，合并以下设置。已有同名节或键时修改原内容，不重复追加：

```ini
[Hotkey]
EnumerateWithTriggerKeys=False
EnumerateSkipFirst=True

[Hotkey/TriggerKeys]
0=Control+space

[Hotkey/EnumerateForwardKeys]
0=Control+Shift+space
```

| 按键 | 用途 |
|---|---|
| Ctrl+Space | 英文 ↔ 当前中文输入法 |
| 中文状态下 Ctrl+Shift+Space | 小鹤双拼 ↔ 全拼 |
| 空格 / 数字 | 选首项 / 选指定候选 |

先上屏或取消正在组字的内容再切换。英文必须保持列表第一项，才能被 `EnumerateSkipFirst` 跳过。也可直接从托盘菜单选择拼音/双拼。

## 5. 快速短语（可选，待目标机验证）

```bash
mkdir -p ~/.local/share/fcitx5/data
```

编辑 UTF-8 文件 `~/.local/share/fcitx5/data/QuickPhrase.mb`，已有文件先备份并保留原条目。每行是“编码 空格 内容”：

```text
yx name@example.com
dz 上海市某区某路123号
qm 张三｜研发部
hh 你好，收到后我会尽快回复。
```

若设置过 `XDG_DATA_HOME`，数据文件应放在 `$XDG_DATA_HOME/fcitx5/data/QuickPhrase.mb`。

在 `~/.config/fcitx5/conf/quickphrase.conf` 中合并：

```ini
[TriggerKey]
0=Control+Alt+semicolon
```

使用：中文状态、没有正在组字时，按 `Ctrl+Alt+;`，输入 `yx`，选择邮箱候选；`Esc` 退出。此方式需要先进入快速短语模式，不会在普通拼音候选中自动置顶。

## 6. 启动与登录后生效

沿用已验证的环境和启动方式：

```bash
export XMODIFIERS=@im=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
fcitx5 -d
kitty -o linux_display_server=x11
```

不要同时运行 Fcitx4 或 ibus-daemon。这里 `ibus` 表示 kitty 使用的协议，实际服务由 Fcitx5 提供。

若已有登录自启动，无需重复设置。否则，`im-config -l` 列出 `fcitx5` 时执行 `im-config -n fcitx5`，将 `export GLFW_IM_MODULE=ibus` 加入 `~/.xprofile`，然后注销重登。没有 im-config 支持时的手动自启动方法见 [详细说明](README.md)。

恢复时退出 Fcitx5，将备份目录内容恢复到 `~/.config/fcitx5` 后重新启动。QuickPhrase 数据文件是独立文件，需要单独恢复其备份或移除本次新增条目。

离线补包、故障诊断及官方参考见 [README.md](README.md)。当前简单方案无需 Rime 或雾凇；其他引擎方案另行讨论。
