# 候选方案核对：Fcitx5-Rime 便携安装

核对日期：2026-11-17。目标是麒麟 V10 SP1、arm64、glibc 2.31；现有 Fcitx5 为 2020 年版本。用户补充：麒麟 apt 源的 IBus/Rime 包也不完整，不能再把系统源完整提供依赖作为默认前提。

后续已选择 IBus 路线，本项目自行构建的 arm64 AppImage 见 [构建与安装说明](packaging/ibus-rime/README.md)。本文保留当时对 Fcitx5 便携成品的核对，不是最终采用路线。

## 结论

没有找到并验证可直接给目标机使用的 **Fcitx5-Rime arm64 AppImage**。这不等于不存在所有第三方实现，但当前不能提供一个已确认可用的下载包。

确实有另一种打包路线：Flathub 的 Fcitx5 主程序和独立 Rime 扩展。它有完整构建清单，包含新版 librime 与 Lua，但不是单文件 AppImage。当前核对到的两个项目最新提交构建状态都只有 `builds/x86_64`；尚未通过 Flathub 远端引用查询确认 aarch64 可安装产物，不能写成“已有 arm64 即装即用”。

| 路线 | 查到的事实 | 对这台机器的意义 |
|---|---|---|
| Fcitx5-Rime AppImage | 未找到已验证的 arm64 成品 | 不能直接切换到现成 AppImage |
| Fcitx5 + Rime Flatpak | 有主程序、Rime 扩展及构建清单 | 可作为后备，但需确认 aarch64 产物及主机 Flatpak 支持 |
| 自制 Fcitx5-Rime 便携目录/AppImage | 可设计为新版框架、引擎和私有依赖整体打包 | 仍是需要构建、桌面集成和验证的工程任务 |
| ibus-rime.AppImage arm64 移植 | 上游有打包实现，现有发布仅 x86_64 | 若主机 IBus 可用，可继续作为主要移植方向 |

## 已确认的 Flatpak 内容

- 主程序：`org.fcitx.Fcitx5`。
- Rime 扩展：`org.fcitx.Fcitx5.Addon.Rime`。
- 核对时主程序清单使用 Fcitx5 5.1.23、KDE Platform 6.11，并打包 Qt 配置工具。
- Rime 扩展清单使用 fcitx5-rime 5.1.16、librime 1.17.0，包含 librime-lua、octagram 等插件源码。
- 扩展依附该 Flatpak Fcitx5 主程序，不是供宿主机旧 Fcitx5 直接加载的插件包。

这些是仓库构建清单信息，不代表同版本 aarch64 二进制已发布，也不代表已验证旧版麒麟上的运行效果。

## 如果继续核实 Flatpak

在已有 Flatpak、已配置 Flathub 的联网机器上查询两个 aarch64 引用：

```bash
flatpak remote-info --arch=aarch64 flathub org.fcitx.Fcitx5
flatpak remote-info --arch=aarch64 --runtime flathub org.fcitx.Fcitx5.Addon.Rime
```

两者都存在才考虑现成包路线；记录分支、提交及运行时。任一缺失就不能靠安装命令获得整套 arm64 软件，需另行构建。下载机可以是其他架构，但查询必须显式指定 `aarch64`。

目标机还要具备可工作的 Flatpak、Bubblewrap、内核沙箱能力及桌面会话 D-Bus。运行库由 Flatpak 提供可以减少系统 Qt/glibc 混装，但不能据此保证旧系统兼容。

离线分发必须同时携带主程序、Rime 扩展及对应运行时；不能只拷一个应用文件。可在确认支持的 Flatpak 版本中使用 `flatpak create-usb` 等离线分发机制，实际命令应根据已确认的引用和版本生成。

## 与现有 Fcitx5 的关系

不能从新版 Flatpak/AppImage 中取出 `rime.so` 或 librime，直接塞入 2020 年旧 Fcitx5：插件还依赖框架 ABI 和配套动态库。

便携 Fcitx5 方案应整体运行新版主程序，停用宿主旧 Fcitx5 自启动，并处理以下事项：

- 通过会话 D-Bus/IBus 兼容接口与 kitty 通信；X11 下 kitty 继续使用 `GLFW_IM_MODULE=ibus`。
- 将框架配置、Rime 用户目录和雾凇配置放到新环境实际读取的位置；Flatpak 用户数据位置不能直接套用普通 deb 路径。
- GTK/Qt 宿主应用的前端模块仍需单独验证，打包主程序不等于所有宿主应用自动获得前端。
- 验证候选窗、托盘、自启动、注销重登和回退；不同时启动多个输入法框架。

## 当前建议

现阶段不把“存在 Fcitx5 Flatpak 项目”当作“已找到麒麟 arm64 的 AppImage 替代品”。

如果目标系统的 IBus 守护进程和前端本身可用，优先移植 `ibus-rime.AppImage` 到 arm64：它可保留主机 IBus，仅携带 Rime 及引擎依赖。若 IBus 框架本身也缺失，则还需要解决 IBus 的系统安装，AppImage 不会替代该框架。

Fcitx5 Flatpak 留作候选：后续查到可用的 aarch64 主程序、扩展与运行时，并验证目标 Flatpak 环境后，再与 AppImage 构建成本比较。当前仅完成核对，没有创建或安装便携二进制。

## 一手资料

- [Fcitx5 Flatpak 主程序清单](https://github.com/flathub/org.fcitx.Fcitx5/blob/master/org.fcitx.Fcitx5.yaml)。
- [Rime Flatpak 扩展清单](https://github.com/flathub/org.fcitx.Fcitx5.Addon.Rime/blob/master/org.fcitx.Fcitx5.Addon.Rime.yaml)。
- [Fcitx5 当前提交构建状态 API](https://api.github.com/repos/flathub/org.fcitx.Fcitx5/commits/master/status)、[Rime 扩展构建状态 API](https://api.github.com/repos/flathub/org.fcitx.Fcitx5.Addon.Rime/commits/master/status)。这些地址反映查询时最新状态，后续可能变化。
- [ibus-rime.AppImage 发布资产](https://github.com/hchunhui/ibus-rime.AppImage/releases)。
