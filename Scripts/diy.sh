#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    
    # 清理旧的包(更精确的匹配)
    read -ra PKG_NAMES <<< "$PKG_NAME"
    for NAME in "${PKG_NAMES[@]}"; do
        # 使用更精确的匹配,避免误删
        find feeds/luci/ feeds/packages/ package/ -maxdepth 3 -type d \( -name "$NAME" -o -name "luci-*-$NAME" \) -exec rm -rf {} + 2>/dev/null
    done
    
    # 克隆仓库
    if [[ $PKG_REPO == http* ]]; then
        local REPO_NAME=$(basename "$PKG_REPO" .git)
    else
        local REPO_NAME=$(echo "$PKG_REPO" | cut -d '/' -f 2)
        PKG_REPO="https://github.com/$PKG_REPO.git"
    fi
    
    # 尝试克隆仓库，最多重试3次
    local RETRY=3
    local COUNT=0
    while [ $COUNT -lt $RETRY ]; do
        echo "尝试克隆仓库 $PKG_REPO (尝试 $((COUNT+1))/$RETRY)..."
        if git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "$PKG_REPO" "package/$REPO_NAME"; then
            echo "成功克隆仓库 $PKG_REPO"
            break
        else
            echo "克隆失败，等待 5 秒后重试..."
            sleep 5
            COUNT=$((COUNT+1))
        fi
    done
    
    # 检查是否克隆成功
    if [ ! -d "package/$REPO_NAME" ]; then
        echo "错误: 克隆仓库失败 $PKG_REPO"
        return 1
    fi
    
    # 根据 PKG_SPECIAL 处理包
    case "$PKG_SPECIAL" in
        "pkg")
            for NAME in "${PKG_NAMES[@]}"; do
                # 从仓库根目录搜索,不限制路径结构
                find "./package/$REPO_NAME" -maxdepth 3 -type d \( -name "$NAME" -o -name "luci-*-$NAME" \) -print0 | \
                    xargs -0 -I {} cp -rf {} ./package/ 2>/dev/null
            done
            rm -rf "./package/$REPO_NAME/"
            ;;
        "name")
            # 避免重命名冲突
            rm -rf "./package/$PKG_NAME"
            mv -f "./package/$REPO_NAME" "./package/$PKG_NAME"
            ;;
    esac
}

# 主题
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"

####### 安装必要的应用

# IPsec 服务器
UPDATE_PACKAGE "luci-app-ipsec-server" "Ivaneus/luci-app-ipsec-server" "main"


# 网络测试 speedtest-cli 以及 vlmcsd
UPDATE_PACKAGE "speedtest-cli luci-app-netspeedtest \
                 luci-app-socat \
                 " "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"

UPDATE_PACKAGE "cups luci-app-cupsd \
                 " "https://github.com/fichenx/openwrt-package" "main" "pkg"


# UPDATE_PACKAGE "vlmcsd" "https://github.com/Wind4/vlmcsd.git" "master"



# 带宽监控 bandix
UPDATE_PACKAGE "openwrt-bandix" "timsaya/openwrt-bandix" "main"
UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"

# 直接安装所需的应用
UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"

# WOL Plus
UPDATE_PACKAGE "luci-app-wolplus" "VIKINGYFY/packages" "main"

# Athena LED
# UPDATE_PACKAGE "luci-app-athena-led" "Sh1rokoDev/luci-app-athena-led" "LuCI2-JS"



# 配置项
provided_config_lines=(
    # 基础工具和库
    "CONFIG_PACKAGE_bash=y"
    "CONFIG_PACKAGE_dnsmasq-full=y"
    "CONFIG_PACKAGE_curl=y"
    "CONFIG_PACKAGE_ca-bundle=y"
    "CONFIG_PACKAGE_ip-full=y"
    "CONFIG_PACKAGE_ruby=y"
    "CONFIG_PACKAGE_ruby-yaml=y"
    "CONFIG_PACKAGE_kmod-tun=y"
    "CONFIG_PACKAGE_kmod-inet-diag=y"
    "CONFIG_PACKAGE_unzip=y"
    "CONFIG_PACKAGE_kmod-nft-tproxy=y"
    "CONFIG_PACKAGE_luci-compat=y"
    ## 2. 网络基础与管理
    ##### luci-app-firewall 和 luci-app-firewall4 只能选一个，否则会有冲突，导致coremark错误
    "CONFIG_PACKAGE_luci-app-firewall=y"
    #"CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y"
    ##### luci-app-network 网络接口管理 (如果需要更复杂的网络配置，可以考虑安装 luci-app-advanced-reboot 或其他网络管理工具)
    #"CONFIG_PACKAGE_luci-app-network=y"
    #"CONFIG_PACKAGE_luci-i18n-network-zh-cn=y"
    ##### luci-app-statistics 系统和网络流量监控 (如果需要更详细的性能监控，可以考虑安装 luci-app-statistics-mod 或其他性能监控工具)
    "CONFIG_PACKAGE_luci-app-statistics=y"
    #"CONFIG_PACKAGE_luci-i18n-statistics-zh-cn=y"
    ##### luci-app-dnsmasq DNS 服务器和 DHCP 服务 (如果需要更高级的 DNS 功能，可以考虑安装 luci-app-dnscrypt-proxy 或其他 DNS 工具)
    #"CONFIG_PACKAGE_luci-app-dnsmasq=y"
    #"CONFIG_PACKAGE_luci-i18n-dnsmasq-zh-cn=y"
    ##### luci-app-arpbind ARP 绑定 (如果需要静态 IP 绑定或防止 ARP 欺骗攻击，可以考虑安装 luci-app-arpbind)
    "CONFIG_PACKAGE_luci-app-arpbind=y"
    #"CONFIG_PACKAGE_luci-i18n-arpbind-zh-cn=y"
    ##### luci-app-wireless 无线设置 (如果需要更复杂的无线配置，可以考虑安装 luci-app-advanced-wireless 或其他无线管理工具)
    #"CONFIG_PACKAGE_luci-app-wireless=y"
    #"CONFIG_PACKAGE_luci-i18n-wireless-zh-cn=y"
    #
    #
    # 3. 远程访问与安全
    ##### luci-app-sshd SSH 服务器 (如果需要远程命令行访问，可以考虑安装 luci-app-sshd)
    "CONFIG_PACKAGE_luci-app-sshd=y"
    #"CONFIG_PACKAGE_luci-i18n-sshd-zh-cn=y"
    ##### luci-app-ufw 基于 UFW 的防火墙管理 (如果需要更简单的防火墙配置界面，可以考虑安装 luci-app-ufw)
    #"CONFIG_PACKAGE_luci-app-ufw=y"
    #"CONFIG_PACKAGE_luci-i18n-ufw-zh-cn=y"
    ##### luci-app-acl 访问控制列表 (如果需要基于 IP 或 MAC 地址的访问控制，可以考虑安装 luci-app-acl)
    "CONFIG_PACKAGE_luci-app-acl=y"
    #"CONFIG_PACKAGE_luci-i18n-acl-zh-cn=y"
    ##### wireguard VPN 支持 (如果需要 VPN 功能，可以考虑安装 luci-app-wireguard)
    "CONFIG_PACKAGE_kmod-wireguard=y"
    "CONFIG_PACKAGE_wireguard-tools=y"
    "CONFIG_PACKAGE_luci-proto-wireguard=y"
    #
    #
    # 4. 服务与工具
    ##### ttyd 基于 Web 的终端 (如果需要通过浏览器访问命令行，可以考虑安装 luci-app-ttyd)
    "CONFIG_PACKAGE_ttyd=y"
    "CONFIG_PACKAGE_luci-app-ttyd=y"
    #"CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y"
    ##### luci-app-filebrowser 文件浏览器 (如果需要通过浏览器访问文件系统，可以考虑安装 luci-app-filebrowser)
    "CONFIG_PACKAGE_luci-app-filebrowser=y"
    #"CONFIG_PACKAGE_luci-i18n-filebrowser-zh-cn=y"
    ##### luci-app-filemanager  基于 Web 的文件管理 (如果需要更强大的文件管理功能，可以考虑安装 luci-app-filemanager)
    "CONFIG_PACKAGE_luci-app-filemanager=y"
    #"CONFIG_PACKAGE_luci-i18n-filemanager-zh-cn=y"
    ##### luci-app-autoreboot 定时自动重启 (如果需要定期重启以保持系统稳定，可以考虑安装 luci-app-autoreboot)
    "CONFIG_PACKAGE_luci-app-autoreboot=y"
    "CONFIG_PACKAGE_luci-i18n-autoreboot-zh-cn=y"
    ##### luci-app-sqm SQM 流量管理 (如果需要流量整形或 QoS 功能，可以考虑安装 luci-app-sqm)
    "CONFIG_PACKAGE_luci-app-sqm=y"
    "CONFIG_PACKAGE_luci-i18n-sqm-zh-cn=y"
    #
    #
    # 5. 存储与共享
    ##### luci-app-samba4 Samba 文件共享 (如果需要共享本地文件系统到 Windows 或 macOS 等系统，可以考虑安装 luci-app-samba4)
    "CONFIG_PACKAGE_luci-app-samba4=y"
    #"CONFIG_PACKAGE_luci-i18n-samba4-zh-cn=y"
    ##### luci-app-upnp UPnP 服务 (如果需要自动端口映射功能，可以考虑安装 luci-app-upnp)
    "CONFIG_PACKAGE_luci-app-upnp=y"    
    #"CONFIG_PACKAGE_luci-i18n-upnp-zh-cn=y"
    #
    #
    # 6. 其他实用工具
    ##### luci-app-package-manager 软件包管理器 (如果需要通过 LuCI 界面安装和管理软件包，可以考虑安装 luci-app-package-manager)
    "CONFIG_PACKAGE_luci-app-package-manager=y"
    #"CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn=y"
    ##### luci-app-advanced-reboot 高级重启选项 (如果需要更多的重启选项，可以考虑安装 luci-app-advanced-reboot)
    "CONFIG_PACKAGE_luci-app-advanced-reboot=y" 
    #"CONFIG_PACKAGE_luci-i18n-advanced-reboot-zh-cn=y"
    ##### luci-app-advanced-wireless 高级无线设置 (如果需要更复杂的无线配置选项，可以考虑安装 luci-app-advanced-wireless)
    #"CONFIG_PACKAGE_luci-app-advanced-wireless=y"
    #"CONFIG_PACKAGE_luci-i18n-advanced-wireless-zh-cn=y"
    ##### vlmcsd KMS 服务器 (如果需要激活 Windows 或 Office 等软件，可以考虑安装 luci-app-vlmcsd)
    "CONFIG_PACKAGE_vlmcsd=y"
    "CONFIG_PACKAGE_luci-app-vlmcsd=y"
    #
    #
    ##### 7.自定义仓库
    ##### argon 主题和配置 (如果需要美观的界面，可以考虑安装 luci-theme-argon 和 luci-app-argon-config)
    "CONFIG_PACKAGE_luci-app-argon-config=y"
    # 自定义 IPsec 服务器 (如果需要 IPsec VPN 功能，可以考虑安装 luci-app-ipsec-server)
    "CONFIG_PACKAGE_luci-app-ipsec-server=y"
    ## socat 网络工具 (如果需要网络调试工具，可以考虑安装 luci-app-socat)
    "CONFIG_PACKAGE_luci-app-socat=y"
    ## openclash 基于 Clash 的透明代理 (如果需要科学上网功能，可以考虑安装 luci-app-openclash)
    "CONFIG_PACKAGE_luci-app-openclash=y"
    ## bandix 带宽监控工具 (如果需要实时监控网络带宽，可以考虑安装 luci-app-bandix)
    "CONFIG_PACKAGE_luci-app-bandix=y"
    ## WOL Plus Wake-on-LAN 增强工具 (如果需要更强大的远程唤醒功能，可以考虑安装 luci-app-wolplus)
    "CONFIG_PACKAGE_luci-app-wolplus=y"
    ## netspeedtest 网络测速工具 (如果需要快速测试网络速度，可以考虑安装 luci-app-netspeedtest)
    "CONFIG_PACKAGE_luci-app-netspeedtest=y"
)


# 为 ax6600 追加配置
[[ $WRT_CONFIG == "ax6600"* ]] && provided_config_lines+=(
    ## 开启 sqm-nss 插件 (如果需要 NSS 流量整形功能，可以考虑安装 luci-app-sqm)
    "CONFIG_PACKAGE_luci-app-sqm=y"
    "CONFIG_PACKAGE_sqm-scripts-nss=y"
    ## 设置 NSS 固件版本 (根据设备选择合适的版本，确保兼容性)
    "CONFIG_NSS_FIRMWARE_VERSION_12_5=y"
    "CONFIG_NSS_FIRMWARE_VERSION_12_2=n"
    ## cupsd 打印服务器 (如果需要打印功能，可以考虑安装 luci-app-cupsd)
    "CONFIG_PACKAGE_luci-app-cupsd=y"
    ## 其他 ax6600 特定的配置项可以在这里添加

)


# 追加配置
for line in "${provided_config_lines[@]}"; do
    echo "$line" >> .config
done

# 修复 ttyd 为免密
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_ttyd-nopass.sh" "package/base-files/files/etc/uci-defaults/99_ttyd-nopass"



# 修复 cmake 版本问题
if ! grep -q "CMAKE_POLICY_VERSION_MINIMUM" include/cmake.mk; then
    echo 'CMAKE_OPTIONS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5' >> include/cmake.mk
fi




# 在脚本末尾添加
# 自动下载 Clash 内核
mkdir -p package/base-files/files/etc/openclash/core/
cat > package/base-files/files/etc/uci-defaults/99-openclash-core << 'EOF'
#!/bin/sh
# 下载 Clash 内核
mkdir -p /etc/openclash/core/
cd /etc/openclash/core/
wget -O clash-linux-arm64.tar.gz https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz
tar -xzf clash-linux-arm64.tar.gz
mv clash-linux-arm64 clash_meta
chmod +x clash_meta
rm -f clash-linux-arm64.tar.gz
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-openclash-core



# 安装 Go
ensure_latest_go() {
    echo "🔍 Installing Go..."
    
    # 使用固定版本的 Go，避免依赖外部 API
    local GO_VERSION="1.25.6"
    local URL="https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    echo "⬇️  Installing Go ${GO_VERSION} from ${URL}..."

    # 流式下载并解压
    if ! curl -fsSL "$URL" | sudo tar -C /usr/local -xzf -; then
        echo "❌ Go installation failed."
        return 1
    fi

    # 写入 GITHUB_PATH，让后续 Steps 生效
    echo "/usr/local/go/bin" >> "$GITHUB_PATH"
    
    # 让当前 step 后续命令也能用
    export PATH="/usr/local/go/bin:$PATH"
    
    echo "✅ Successfully installed Go ${GO_VERSION}"
}

# 执行函数
ensure_latest_go