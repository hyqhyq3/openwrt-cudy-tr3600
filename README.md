# OpenWrt for Cudy TR3600 v1 (openwrt-25.12)

基于 [openwrt-25.12](https://github.com/openwrt/openwrt/tree/openwrt-25.12) 分支 +
[PR #24596](https://github.com/openwrt/openwrt/pull/24596)（`046aec0d`）构建的
Cudy TR3600 v1（MT7987 + MT7990，Wi-Fi 7 旅行路由器）固件，并包含若干**真机实测修复**。

> 官方 OpenWrt 上游（稳定版/snapshot）目前均不包含 TR3600，本仓库在 PR 合入前提供可用固件。

## Release 固件

从 [Releases](../../releases) 下载：

| 文件 | 用途 |
|---|---|
| `openwrt-mediatek-filogic-cudy_tr3600-v1-squashfs-sysupgrade.bin` | 常规刷机（含从 Cudy 原厂 OpenWrt 固件迁移） |
| `openwrt-mediatek-filogic-cudy_tr3600-v1-initramfs-kernel.bin` | 救砖/内存启动（TFTP / U-Boot） |
| `sha256sums` | 校验 |

固件为**通用干净版**：不含任何个人配置，首启为 OpenWrt 默认状态（LAN 192.168.1.1，
双频开放 SSID「OpenWrt」）。

## 相对 PR #24596 的修复

详见 [`cudy-tr3600-v1-fixes.patch`](cudy-tr3600-v1-fixes.patch)（均经真机验证）：

1. **LED 颜色**：GPIO48 = 白、GPIO46 = 红（PR 写反且虚构了蓝色 LED）；boot/failsafe/upgrade 用红、running 用白。
2. **风扇 PWM0@GPIO13**（PR 用了错误的 PWM1@GPIO7），并补充：
   - `cooling-levels = <0 64 128 192 255>`；
   - `cpu_thermal` 增补 65/72/80/88 °C 四档 active trip + cooling-maps，内核温控自动调速。
   - ⚠️ fan 节点**不能**带 `pinctrl-0`：PWM 核心会自行 mux pin13，重复申请会让
     `pwm-fan` probe 失败（-EINVAL），供电保持关闭、风扇不转。
3. **WiFi MAC 布局**：2.4 GHz = base+0（与 LAN 共享，厂商行为）、5 GHz = base+0x10（PR 的 +3/+2 错误）。

以上 1、3 与 PR 维护者 Ylarod 的真机反馈一致；Cudy 官方 GPL 包（`R126.dts`）交叉验证。

### 25.12 snapshot 用户态注意事项

- hostapd 2.12-devel 已删除 `bss_transition` / `ieee80211v` / `wnm_sleep_mode` 配置关键词
  （BSS Transition 常开）。uci 若设置 `ieee80211v=1`，netifd 会写出已废弃的
  `bss_transition=1` 导致 `add_iface` 失败、AP 起不来。**无线只配
  `ieee80211r` / `ft_psk_generate_local` / `mobility_domain` / `ieee80211k`。**
- 未设置 country 时 5G 高频段（ch149+）为 NO-IR，AP 无法启动；需 `option country 'CN'`（按所在地区）。
- 新固件首启默认生成的 wifi-iface 是 `disabled='1'`，记得启用。

## 构建

```bash
git clone -b openwrt-25.12 --depth 1 https://github.com/openwrt/openwrt.git
cd openwrt
git fetch origin pull/24596/head && git checkout FETCH_HEAD
git apply /path/to/cudy-tr3600-v1-fixes.patch
./scripts/feeds update -a && ./scripts/feeds install -a

# 最小配置（或 make menuconfig 自选软件包）
cat > .config <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cudy_tr3600-v1=y
EOF
make defconfig

make -j$(nproc) download
make -j$(nproc)          # root 下编译需 export FORCE_UNSAFE_CONFIGURE=1
```

产物在 `bin/targets/mediatek/filogic/`。Debian 依赖清单见 [build.sh](build.sh)。

个人化配置可在 buildroot 顶层 `files/etc/uci-defaults/` 放置首启脚本
（示例模板见 [examples/](examples/)，含 WireGuard+GRETAP 哑 AP、双频 802.11r/k 漫游组网）。

## 刷机

**从 Cudy 原厂 OpenWrt 版固件（25.12-SNAPSHOT-CUDY / R126）：**

```bash
scp -O openwrt-...-sysupgrade.bin root@10.0.0.x:/tmp/fw.bin
ssh root@10.0.0.x sysupgrade -n -v /tmp/fw.bin    # -n 不保留原厂配置
```

`sysupgrade` 元数据兼容 `cudy,tr3600-v1` 与 `R126`。

**已在 OpenWrt 上升级：** `sysupgrade -k -v /tmp/fw.bin`（保留配置）。

**回退：** Cudy 官方 [TR3600 下载页](https://www.cudy.com/en-us/pages/download-center/tr3600-1-0)
提供原厂 OpenWrt 版 sysupgrade（过渡固件）；救砖用 initramfs-kernel 经 U-Boot 内存启动。

## 已知事项

- 仅支持 TR3600 **v1**。
- 2.5G WAN 口（RTL8221B）已驱动；USB3 可用。
- 设备无 RTC，重启后系统时间回退，NTP 同步前 `wg show` 的 handshake 计时可能异常。

## 致谢

- [soapmancn](https://github.com/openwrt/openwrt/pull/24596) — TR3600 初始移植
- [Ylarod](https://github.com/openwrt/openwrt/pull/24596#issuecomment) — 真机测试与硬件描述修正
- Cudy — GPL 源码包与过渡固件
