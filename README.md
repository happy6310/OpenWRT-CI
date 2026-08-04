# OpenWRT-CI

## 项目简介

OpenWRT-CI 是一个用于云编译 OpenWRT 固件的 CI 项目，特别针对 JD 雅典娜（jdcloud_re-cs-02）和红米 AX6000（redmi-router-ax6000-ubootmod）路由器进行了优化。

## 支持的设备

- **JD 雅典娜路由器**：`jdcloud_re-cs-02`
- **红米 AX6000 路由器  Xiaomi Redmi Router AX6000 (OpenWrt U-Boot layout)  **：`redmi-router-ax6000-ubootmod`

## 源码来源

- **官方版**：https://github.com/immortalwrt/immortalwrt.git
- **高通版**：https://github.com/VIKINGYFY/immortalwrt.git

## U-BOOT

- **高通版**：
  - https://github.com/chenxin527/uboot-ipq60xx-emmc-build
  - https://github.com/chenxin527/uboot-ipq60xx-nand-build
  - https://github.com/chenxin527/uboot-ipq60xx-nor-build
- **联发科版**：
  - https://drive.wrt.moe/uboot/mediatek

## 固件说明

- 固件每天早上 4 点自动编译
- 固件信息里的时间为编译开始的时间，方便核对上游源码提交时间
- 支持的平台：MEDIATEK 系列、QUALCOMMAX 系列、ROCKCHIP 系列、X86 系列

## 目录结构

- **workflows**：自定义 CI 配置
- **Scripts**：自定义脚本
- **Config**：自定义配置

### Scripts 脚本说明

| 脚本 | 说明 |
|------|------|
| `diy.sh` | 核心自定义脚本：安装插件、追加配置、源码补丁、Clash 内核下载、Docker 修复、Go 工具链更新、初始化脚本 |
| `Packages.sh` | 软件包安装和版本管理：主题、OpenClash、sing-box 自动更新 |
| `Settings.sh` | 系统设置：主题、IP 地址、WiFi 名称密码、root 密码、主机名 |
| `Handles.sh` | 编译修复补丁：HomeProxy 数据、argon 主题、NSS 驱动、Tailscale、Rust、DiskMan、netspeedtest |
| `99_ttyd-nopass.sh` | ttyd 免密登录 uci-defaults |
| `99_dropbear_setup.sh` | dropbear SSH 配置修复 |
| `99_fix_ipsec_server.sh` | IPSec 服务器 init 脚本替换 |
| `ddns-go.init` | DDNS-GO 启动脚本 |

## 编译配置

### JD 雅典娜路由器

- 配置文件：`Config/jdcloud_ax6600.txt`
- CI 工作流：`.github/workflows/OWRT-JDCLOUD-AX6600.yml`

### 红米 AX6000 路由器

- 配置文件：`Config/redmi-router-ax6000.txt`
- CI 工作流：`.github/workflows/OWRT-REDMI-AX6000.yml`

## 内置应用

- **openclash**：网络代理工具（预装 Clash Meta 内核）
- **ipsec-server**：VPN 服务（启用但不预设密码，首次在 LuCI 界面设置）
- **tailscale**：组网工具
- **bandix**：网络流量监控
- **turboacc**：网络加速
- **socat**：网络工具
- **wolplus**：网络唤醒工具
- **istore**：应用商店
- **cups**：打印服务
- **speedtest-cli**：网络测速
- **advanced**：高级功能插件
- **webadmin**：Web 管理工具
- **filemanager**：文件管理器
- **argon**：主题及配置工具

### AX6600 专属应用

- **sqm-nss**：NSS 流量整形
- **samba4**：文件共享
- **docker**（可选）：容器管理（需在配置中启用）

## WiFi 优化

固件首次启动时自动应用以下 WiFi 配置（`99-init-config`）：

| 参数 | 2.4G (radio0) | 5G (radio1) |
|------|---------------|-------------|
| 国家码 | US | US |
| 信道 | 11 | 149 |
| 模式 | HE40 | HE160 |
| MU-MIMO | 开启 | 开启 |
| MU-EDCA | - | 开启 |
| DFS (doth) | 关闭 | 关闭 |

## 编译流程

1. **环境初始化**：清理 Ubuntu，安装编译依赖
2. **磁盘合并**：扩展编译空间
3. **源码克隆**：拉取 immortalwrt 源码
4. **缓存检查**：toolchain 缓存加速二次编译
5. **Feeds 更新**：加载官方软件源
6. **自定义包**：执行 `Packages.sh` + `Handles.sh`
7. **自定义设置**：执行 `Settings.sh` + `diy.sh`
8. **下载编译**：`make download` → `make -j$(nproc)`
9. **打包发布**：重命名固件文件，创建 GitHub Release

## 使用方法

1. **手动编译**：
   - 进入 GitHub 仓库的 Actions 页面
   - 选择对应的工作流（OWRT-JDCLOUD-AX6600 或 OWRT-REDMI-AX6000）
   - 点击 "Run workflow" 按钮
   - 等待编译完成，在 "Artifacts" 中下载固件

2. **自动编译**：
   - 系统会在每天早上 4 点自动编译固件
   - 编译完成后会创建 Release，可在 Releases 页面下载

## 技术特点

- **自动化编译**：使用 GitHub Actions 实现完全自动化的编译流程
- **缓存机制**：使用 GitHub Actions 缓存加速编译过程
- **错误处理**：添加了详细的错误处理和重试机制
- **依赖管理**：优化了依赖包的管理，确保编译稳定性
- **灵活性**：支持多种设备平台和自定义配置
- **条件执行**：Docker 修复仅在配置启用时执行，Go 工具链更新失败不中断编译
- **安全**：IPSec 不预设密码，WiFi 满血优化

## 注意事项

- 编译过程可能需要较长时间，请耐心等待
- 确保 GitHub Actions 有足够的权限和资源
- 如有编译失败，请查看 CI 日志获取详细信息
- Go 工具链更新依赖网络，失败时自动回退源码默认版本

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

## 许可证

本项目采用 MIT 许可证。
