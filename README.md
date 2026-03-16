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

## 编译配置

### JD 雅典娜路由器

- 配置文件：`Config/jdcloud_ax6600.txt`
- CI 工作流：`.github/workflows/OWRT-JDCLOUD-AX6600.yml`

### 红米 AX6000 路由器

- 配置文件：`Config/redmi-router-ax6000.txt`
- CI 工作流：`.github/workflows/OWRT-REDMI-AX6000.yml`

## 内置应用

- **openclash**：网络代理工具
- **ddns**：动态 DNS 服务
- **socat**：网络工具
- **ipsec-server**：VPN 服务
- **bandix**：网络流量监控
- **wireguard**：VPN 服务
- **wolplus**：网络唤醒工具
- **crontab**：定时任务
- **ttyd**：终端工具
- **autoreboot**：自动重启

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

## 注意事项

- 编译过程可能需要较长时间，请耐心等待
- 确保 GitHub Actions 有足够的权限和资源
- 如有编译失败，请查看 CI 日志获取详细信息

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

## 许可证

本项目采用 MIT 许可证。

---

[![Stargazers over time](https://starchart.cc/VIKINGYFY/OpenWRT-CI.svg?variant=adaptive)](https://starchart.cc/VIKINGYFY/OpenWRT-CI)




https://github.com/immortalwrt/immortalwrt.git

'packages' from 'https://github.com/immortalwrt/packages.git'
'luci' from 'https://github.com/immortalwrt/luci.git'
'routing' from 'https://github.com/openwrt/routing.git'
'telephony' from 'https://github.com/openwrt/telephony.git'
'video' from 'https://github.com/openwrt/video.git'

