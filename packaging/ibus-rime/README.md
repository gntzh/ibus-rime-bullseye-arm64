# Debian 11 bullseye arm64 ibus-rime AppImage

Build repository: https://github.com/gntzh/ibus-rime-bullseye-arm64

Native `ubuntu-24.04-arm` GitHub Actions runner; all application compilation occurs inside Debian bullseye (glibc 2.31). The newer host is used only for packaging with a SHA256-verified aarch64 appimagetool and static type-2 runtime.

Based on [hchunhui/ibus-rime.AppImage](https://github.com/hchunhui/ibus-rime.AppImage), pinned at `012daad0f2ab8585b59c57815763ccdc050fe3d9`. Retains its relocation patches, AppRun installer and bundled tools. Uses ibus-rime 1.6.1, librime 1.17.0, pinned Lua/Octagram/Charcode plugin commits, minimal default Rime data, and private C++ runtime libraries. `BUILD-INFO.txt` records actual source commits and Debian package versions; this is not a claim of bit-for-bit reproducible builds.

The host still needs IBus 1.5 and its normal desktop dependencies. This AppImage does not provide an IBus daemon or GTK/Qt frontend modules. The payload does not include Rime Ice; import that separately after basic Rime input works.

## Download and installation

Use a successful Actions run's `ibus-rime-bullseye-arm64` artifact, or a verified release asset. Contents:

- `ibus-rime-bullseye-aarch64.AppImage`
- `SHA256SUMS`
- `BUILD-INFO.txt`
- `VERIFICATION.txt`

On the target machine:

```bash
sha256sum -c SHA256SUMS
mkdir -p "$HOME/Applications"
cp ibus-rime-bullseye-aarch64.AppImage "$HOME/Applications/"
chmod +x "$HOME/Applications/ibus-rime-bullseye-aarch64.AppImage"
"$HOME/Applications/ibus-rime-bullseye-aarch64.AppImage"
```

Run in the ordinary logged-in desktop user session. The no-argument command registers the Rime engine and deploys default data. After a successful setup notification, restart IBus and add Rime in `ibus-setup`. Do not move the AppImage after registration. Preserve existing `~/.config/ibus/rime` data before setup.

If FUSE is unavailable, the included runtime supports extraction and execution:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 "$HOME/Applications/ibus-rime-bullseye-aarch64.AppImage"
```

For subsequent engine launches without FUSE, the IBus daemon must also inherit `APPIMAGE_EXTRACT_AND_RUN=1` (including after login), since it launches the registered AppImage path. The flag used only in a setup terminal does not configure the desktop session. Prefer normal FUSE launching when available.

On X11, IBus and kitty need:

```bash
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export GLFW_IM_MODULE=ibus
ibus-daemon -drx
ibus engine rime
kitty -o linux_display_server=x11
```

Stop Fcitx4/Fcitx5 first; do not run competing input method daemons. After testing, configure these values and IBus autostart for the desktop login session. Rime Ice configuration belongs in `~/.config/ibus/rime`; retain the AppImage installer-created `appimage/` subdirectory.

Bundled tools can be invoked as arguments:

```bash
"$HOME/Applications/ibus-rime-bullseye-aarch64.AppImage" version
"$HOME/Applications/ibus-rime-bullseye-aarch64.AppImage" rime_deployer --help
```

## Verification boundaries

The workflow checks the AppImage and every bundled ELF are aarch64, no bundled ELF requires GLIBC newer than 2.31, and dependencies resolve in a clean bullseye container with host IBus installed. It tests extraction without FUSE, CLI tools, default dictionary deployment, plugin registration and a Lua-generated Chinese candidate/commit.

These checks do not replace Kylin desktop testing: tray integration, candidate popup placement, the graphical installer notification, GTK/Qt host clients and real kitty keystrokes must be verified on the target desktop. The host IBus/GLib ABI is still relevant; glibc compatibility alone does not prove compatibility with every Kylin package.

## Build again

Run the `ibus-rime bullseye arm64` workflow manually or push a packaging change. Bullseye package sources use Debian's archive because the normal security pool no longer has all indexed packages. Tool hashes intentionally fail closed if mutable upstream `continuous` assets change; update them only after reviewing the new assets.
