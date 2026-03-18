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
#UPDATE_PACKAGE "luci-app-ipsec-server" "Ivaneus/luci-app-ipsec-server" "main"
#UPDATE_PACKAGE "luci-app-ipsec-vpnserver-manyusers" "https://github.com/Ivaneus/luci-app-ipsec-vpnserver-manyusers" "main"
#UPDATE_PACKAGE "luci-app-ipsec-vpnserver-manyusers" "https://github.com/immortalwrt/luci" "openwrt-21.02" "pkg"


#small-package
# UPDATE_PACKAGE "xray-core xray-plugin dns2tcp dns2socks haproxy hysteria \
#         naiveproxy v2ray-core v2ray-geodata v2ray-geoview v2ray-plugin \
#         tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev \
#         luci-app-passwall smartdns luci-app-smartdns v2dat mosdns luci-app-mosdns \
#         taskd luci-lib-xterm luci-lib-taskd luci-app-passwall2 \
#         luci-app-store quickstart luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest \
#         luci-theme-argon netdata luci-app-netdata lucky luci-app-lucky luci-app-openclash mihomo \
#         luci-app-nikki frp luci-app-ddns-go ddns-go docker dockerd" "kenzok8/jell" "main" "pkg"

#small-package
UPDATE_PACKAGE "luci-app-ipsec-server \
                taskd luci-lib-xterm luci-lib-taskd luci-app-store \
                " "https://github.com/kenzok8/jell" "main" "pkg"




# 网络测试 speedtest-cli 以及 vlmcsd
UPDATE_PACKAGE "speedtest-cli luci-app-netspeedtest \
                 luci-app-socat \
                 " "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"

UPDATE_PACKAGE "cups luci-app-cupsd \
                 " "https://github.com/fichenx/openwrt-package" "main" "pkg"


# UPDATE_PACKAGE "vlmcsd" "https://github.com/Wind4/vlmcsd.git" "master"

# 
UPDATE_PACKAGE "luci-app-advancedplus" "https://github.com/sirpdboy/luci-app-advancedplus" "main"


# 带宽监控 bandix
UPDATE_PACKAGE "openwrt-bandix" "timsaya/openwrt-bandix" "main"
UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"

# 直接安装所需的应用
UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"

# WOL Plus
UPDATE_PACKAGE "luci-app-wolplus" "VIKINGYFY/packages" "main"

# Athena LED
# UPDATE_PACKAGE "luci-app-athena-led" "Sh1rokoDev/luci-app-athena-led" "LuCI2-JS"

####################


# keywords_to_delete=(
#     #"xiaomi_ax3600" "xiaomi_ax9000" "xiaomi_ax1800" "glinet" "jdcloud_ax6600" "linksys" "link_nn6600" "re-cs-02" "nn6600" "mr7350"
#     "uugamebooster" "luci-app-wol" "luci-i18n-wol-zh-cn" "CONFIG_TARGET_INITRAMFS" "ddns"  "mihomo" "nikki"
#     "smartdns" "kucat" "bootstrap" "kucat" "luci-app-partexp" "luci-app-upnp"
# )

# [[ $WRT_CONFIG == *"WIFI-NO"* ]] && keywords_to_delete+=("usb" "wpad" "hostapd")
# [[ $WRT_CONFIG != *"EMMC"* ]] && keywords_to_delete+=("samba" "autosamba" "disk")

# for keyword in "${keywords_to_delete[@]}"; do
#     sed -i "/$keyword/d" ./.config
# done




####################
 


# 配置项
provided_config_lines=(
    # 基础工具和库
    "CONFIG_PACKAGE_bash=y"
    # "CONFIG_PACKAGE_dnsmasq-full=y"
    #"CONFIG_PACKAGE_curl=y"
    #"CONFIG_PACKAGE_ca-bundle=y"
     # iptables 防火墙
    #"CONFIG_PACKAGE_iptables=y"
    # IPv6 防火墙
    #"CONFIG_PACKAGE_ip6tables=y"          
    # 完整的 IP 工具
    #"CONFIG_PACKAGE_ip-full=y"
    "CONFIG_PACKAGE_ruby=y"
    "CONFIG_PACKAGE_ruby-yaml=y"
    #"CONFIG_PACKAGE_kmod-tun=y"
    #"CONFIG_PACKAGE_kmod-inet-diag=y"
    "CONFIG_PACKAGE_unzip=y"
    #"CONFIG_PACKAGE_kmod-nft-tproxy=y"
    #"CONFIG_PACKAGE_luci-compat=y"
    #
    # EXT4 文件系统支持"
    "CONFIG_PACKAGE_kmod-fs-ext4=y"
    # NTFS 文件系统支持"
    "CONFIG_PACKAGE_kmod-fs-ntfs3=y"
    # FAT 文件系统支持"
    "CONFIG_PACKAGE_kmod-fs-vfat=y"
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
    #"CONFIG_PACKAGE_luci-app-acl=y"
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
    ##### luci-app-filemanager  基于 Web 的文件管理 (如果需要更强大的文件管理功能，可以考虑安装 luci-app-filemanager)
    "CONFIG_PACKAGE_luci-app-filemanager=y"
    #"CONFIG_PACKAGE_luci-i18n-filemanager-zh-cn=y"
    ##### luci-app-autoreboot 定时自动重启 (如果需要定期重启以保持系统稳定，可以考虑安装 luci-app-autoreboot)
    #"CONFIG_PACKAGE_luci-app-autoreboot=y"
    #"CONFIG_PACKAGE_luci-i18n-autoreboot-zh-cn=y"
    ##### luci-app-sqm SQM 流量管理 (如果需要流量整形或 QoS 功能，可以考虑安装 luci-app-sqm)
    "CONFIG_PACKAGE_luci-app-sqm=y"
    #"CONFIG_PACKAGE_luci-i18n-sqm-zh-cn=y"
    #
    #
    # 5. 存储与共享
    ##### luci-app-samba4 Samba 文件共享 (如果需要共享本地文件系统到 Windows 或 macOS 等系统，可以考虑安装 luci-app-samba4)
    #"CONFIG_PACKAGE_luci-app-samba4=y"
    #"CONFIG_PACKAGE_luci-i18n-samba4-zh-cn=y"
    ##### luci-app-upnp UPnP 服务 (如果需要自动端口映射功能，可以考虑安装 luci-app-upnp)
    #"CONFIG_PACKAGE_luci-app-upnp=y"    
    #"CONFIG_PACKAGE_luci-i18n-upnp-zh-cn=y"
    #
    #
    # 6. 其他实用工具
    ##### luci-app-package-manager 软件包管理器 (如果需要通过 LuCI 界面安装和管理软件包，可以考虑安装 luci-app-package-manager)
    "CONFIG_PACKAGE_luci-app-package-manager=y"
    #"CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn=y"
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
    "CONFIG_PACKAGE_luci-theme-argon=y"
    "CONFIG_PACKAGE_luci-app-argon-config=y"
    # 自定义 IPsec 服务器 (如果需要 IPsec VPN 功能，可以考虑安装 luci-app-ipsec-server)
    "CONFIG_PACKAGE_luci-app-ipsec-server=y"
    #"CONFIG_PACKAGE_luci-app-ipsec-vpnserver-manyusers=y"
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
    ## luci-app-advancedplus
    "CONFIG_PACKAGE_luci-app-advancedplus=y"
)


# 为 ax6600 追加配置
[[ $WRT_CONFIG == *"ax6600"* ]] && provided_config_lines+=(
    ## 开启 sqm-nss 插件 (如果需要 NSS 流量整形功能，可以考虑安装 luci-app-sqm)
    "CONFIG_PACKAGE_luci-app-sqm=y"
    "CONFIG_PACKAGE_luci-i18n-sqm-zh-cn=y"
    "CONFIG_PACKAGE_sqm-scripts-nss=y"
    # 开启 dockerman 插件 (如果需要 Docker 容器管理功能，可以考虑安装 luci-app-dockerman)
    #"CONFIG_PACKAGE_luci-app-dockerman=y"
    # store 插件 (如果需要软件包存储功能，可以考虑安装 luci-app-store)
    # "CONFIG_PACKAGE_luci-app-store=y"
)


# 追加配置
for line in "${provided_config_lines[@]}"; do
    echo "$line" >> .config
done

# 第一部分：主题颜色修改
find ./ -name "cascade.css" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.css" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "cascade.less" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.less" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;

# 第二部分：网络接口获取函数修复
find ./ -name "getifaddr.c" -exec sed -i 's/return 1;/return 0;/g' {} \;


#修改ttyd为免密
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_ttyd-nopass.sh" "package/base-files/files/etc/uci-defaults/99_ttyd-nopass"

install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_set_argon_primary" "package/base-files/files/etc/uci-defaults/99_set_argon_primary"

install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99-distfeeds.conf" "package/emortal/default-settings/files/99-distfeeds.conf"
sed -i '/define Package\/default-settings\/install/a \
\t$(INSTALL_DIR) $(1)/etc\n\t$(INSTALL_DATA) ./files/99-distfeeds.conf $(1)/etc/99-distfeeds.conf' \
package/emortal/default-settings/Makefile

sed -i "/exit 0/i\\
[ -f \'/etc/99-distfeeds.conf\' ] && mv \'/etc/99-distfeeds.conf\' \'/etc/opkg/distfeeds.conf\'\n\
sed -ri \'/check_signature/s@^[^#]@#&@\' /etc/opkg.conf\n" "package/emortal/default-settings/files/99-default-settings"

#解决 dropbear 配置的 bug
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_dropbear_setup.sh" "package/base-files/files/etc/uci-defaults/99_dropbear_setup"


# cd /tmp
# # install luci-app-openclash, will try to get latest version later
# #https://github.com/vernesong/OpenClash/releases
# wget --no-check-certificate https://github.com/vernesong/OpenClash/releases/download/v0.45.02-beta/luci-app-openclash_0.45.02-beta_all.ipk -O luci-app-openclash_0.45.02-beta_all.ipk
# opkg install /tmp/luci-app-openclash_*.ipk
# rm -f /tmp/luci-app-openclash_*.ipk



#fix makefile for apk
if [ -f ./package/v2ray-geodata/Makefile ]; then
    sed -i 's/VER)-\$(PKG_RELEASE)/VER)-r\$(PKG_RELEASE)/g' ./package/v2ray-geodata/Makefile
fi
if [ -f ./package/luci-lib-taskd/Makefile ]; then
    sed -i 's/>=1\.0\.3-1/>=1\.0\.3-r1/g' ./package/luci-lib-taskd/Makefile
fi
if [ -f ./package/luci-app-openclash/Makefile ]; then
    sed -i '/^PKG_VERSION:=/a PKG_RELEASE:=1' ./package/luci-app-openclash/Makefile
fi
if [ -f ./package/luci-app-quickstart/Makefile ]; then
    # 把 PKG_VERSION:=x.y.z-n 拆成 PKG_VERSION:=x.y.z 和 PKG_RELEASE:=n
    sed -i -E 's/PKG_VERSION:=([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/PKG_VERSION:=\1\nPKG_RELEASE:=\2/' ./package/luci-app-quickstart/Makefile
fi
if [ -f ./package/luci-app-store/Makefile ]; then
    # 把 PKG_VERSION:=x.y.z-n 拆成 PKG_VERSION:=x.y.z 和 PKG_RELEASE:=n
    sed -i -E 's/PKG_VERSION:=([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/PKG_VERSION:=\1\nPKG_RELEASE:=\2/' ./package/luci-app-store/Makefile
fi

if ! grep -q "CMAKE_POLICY_VERSION_MINIMUM" include/cmake.mk; then
    echo 'CMAKE_OPTIONS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5' >> include/cmake.mk
fi


if [ -f ./package/luci-app-ddns-go/ddns-go/file/ddns-go.init ]; then
    cp ${GITHUB_WORKSPACE}/Scripts/ddns-go.init ./package/luci-app-ddns-go/ddns-go/file/ddns-go.init
	chmod +x ./package/luci-app-ddns-go/ddns-go/file/ddns-go.init
	echo "ddns-go.init has been replaced successfully."
fi





# # install openclash Dev core
if [ -d *"luci-app-openclash"* ]; then 
    echo "开始下载 clash-linux-arm64.tar.gz..." 
    # 创建目录时使用 sudo 获取权限
    sudo mkdir -p /etc/openclash/core/ 
    cd /etc/openclash/core/ 
    # 移除 URL 中的反引号
    if sudo wget -O clash-linux-arm64.tar.gz https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz; then 
        echo "下载成功，正在解压..." 
        if sudo tar -xzf clash-linux-arm64.tar.gz; then 
            echo "解压成功，正在重命名..." 
            sudo mv clash-linux-arm64 clash_meta 
            sudo chmod +x clash_meta 
            sudo rm -f clash-linux-arm64.tar.gz 
            echo "Clash 内核安装成功！" 
        else 
            echo "解压失败！" 
            sudo rm -f clash-linux-arm64.tar.gz 
        fi 
    else 
        echo "下载失败！" 
    fi 
fi




# =======================================================
# 1. 解决 opkg 报错：正确补齐 dockerman 及其依赖
# =======================================================
echo "Handling Docker dependencies..."

# 清理环境，防止残留冲突
rm -rf package/feeds/luci/luci-app-dockerman
rm -rf package/feeds/luci/luci-lib-docker
rm -rf package/luci-app-dockerman
rm -rf package/luci-lib-docker

# 处理 luci-app-dockerman
echo "Cloning luci-app-dockerman..."
git clone --depth 1 https://github.com/lisaac/luci-app-dockerman.git temp_dockerman
mv temp_dockerman/applications/luci-app-dockerman package/luci-app-dockerman
rm -rf temp_dockerman

# 处理 luci-lib-docker
echo "Cloning luci-lib-docker..."
git clone --depth 1 https://github.com/lisaac/luci-lib-docker.git temp_libdocker
if [ -d "temp_libdocker/collections/luci-lib-docker" ]; then
    mv temp_libdocker/collections/luci-lib-docker package/luci-lib-docker
else
    mv temp_libdocker package/luci-lib-docker
fi
rm -rf temp_libdocker

# 移除 cgroupfs-mount 依赖
if [ -f "package/luci-app-dockerman/Makefile" ]; then
    echo "Removing cgroupfs-mount dependency..."
    sed -i 's/+cgroupfs-mount //g' package/luci-app-dockerman/Makefile
    sed -i 's/+cgroupfs-mount//g' package/luci-app-dockerman/Makefile
fi

# 安装必要依赖
./scripts/feeds install ttyd
./scripts/feeds install luci-lib-docker

# =======================================================
# 2. 修复 Docker 引擎 (dockerd) 和 CLI (docker)
# =======================================================
# --- 处理 Docker 相关组件 ---
# 定义 Docker 版本和 Commit
DOCKER_VER="29.2.1"
DOCKERD_COMMIT="730e6f2"
DOCKER_CLI_COMMIT="730e6f2"

# 查找 dockerd 和 docker CLI 的 Makefile
dockerd_makefile=$(find package/ feeds/ -name Makefile | xargs grep -l "PKG_NAME:=dockerd" | head -n 1)
docker_makefile=$(find package/ feeds/ -name Makefile | xargs grep -l "PKG_NAME:=docker" | head -n 1)

# --- 处理 dockerd --- 
if [ -f "$dockerd_makefile" ]; then 
    echo "Processing dockerd Makefile at: $dockerd_makefile" 
    # 修复版本号和 Commit 
    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$DOCKER_VER/" "$dockerd_makefile" 
    sed -i "s/PKG_GIT_SHORT_COMMIT:=.*/PKG_GIT_SHORT_COMMIT:=$DOCKERD_COMMIT/g" "$dockerd_makefile" 
    sed -i 's/^PKG_HASH:=.*/PKG_HASH:=skip/' "$dockerd_makefile" 
    
    # 修复下载 URL，使用正确的标签格式
    sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=docker-$DOCKER_VER/" "$dockerd_makefile"
    sed -i "s/^PKG_SOURCE:=.*/PKG_SOURCE:=moby-docker-$DOCKER_VER.tar.gz/" "$dockerd_makefile"
    
    # 彻底重写 Build/Prepare。删除从 # Verify dependencies 到第一个 endef 之间的内容 
    # 然后重新插入一个标准的 Build/Prepare/Default 动作 
    sed -i '/define Build\/Prepare/,/endef/c\define Build\/Prepare\n\t$(Build\/Prepare\/Default)\nendef' "$dockerd_makefile" 
    
    # 移除 Compile 阶段可能残留的强制校验 (EnsureVendored 系列调用) 
    sed -i 's/^\t$(call EnsureVendored/#\t$(call EnsureVendored/g' "$dockerd_makefile" 
fi 

# --- 处理 docker CLI --- 
if [ -f "$docker_makefile" ]; then 
    echo "Processing docker CLI Makefile at: $docker_makefile" 
    # 修复版本号和 Commit 
    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$DOCKER_VER/" "$docker_makefile" 
    sed -i "s/PKG_GIT_SHORT_COMMIT:=.*/PKG_GIT_SHORT_COMMIT:=$DOCKER_CLI_COMMIT/g" "$docker_makefile" 
    sed -i 's/^PKG_HASH:=.*/PKG_HASH:=skip/' "$docker_makefile" 

    # 修复下载 URL，使用正确的标签格式
    sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=docker-$DOCKER_VER/" "$docker_makefile"
    sed -i "s/^PKG_SOURCE:=.*/PKG_SOURCE:=moby-docker-$DOCKER_VER.tar.gz/" "$docker_makefile"

    # 彻底重写 Build/Prepare，防止其内部的 Shell 脚本语法报错 
    sed -i '/define Build\/Prepare/,/endef/c\define Build\/Prepare\n\t$(Build\/Prepare\/Default)\nendef' "$docker_makefile" 
fi
echo "All Docker compilation fixes applied successfully!"




# 修复 OpenWrt 包里不合规（非数字开头）的 PKG_VERSION，
# 搜索范围：传入目录（默认 .）向下最多 3 层的所有 Makefile
fix_openwrt_apk_versions() {
  local ROOT="${1:-.}"
  local MAX_DEPTH="${2:-3}"   # 可选：第二个参数可改最大深度，默认 3

  log() { printf '[fix-apk] %s\n' "$*" >&2; }

  process_file() {
    local f="$1"

    # 读取首个 PKG_VERSION
    local line ver_raw
    line="$(grep -m1 -E '^[[:space:]]*PKG_VERSION:=' "$f" || true)" || true
    [[ -z "$line" ]] && return 0

    ver_raw="$(sed -E 's/^[[:space:]]*PKG_VERSION:=[[:space:]]*//; s/[[:space:]]+$//' <<<"$line")"
    ver_raw="${ver_raw%\"}"; ver_raw="${ver_raw#\"}"

    # 已经是数字开头就无需修复
    if [[ "$ver_raw" =~ ^[0-9] ]]; then
      return 0
    fi

    # 提取数字（可含点）的第一段作为包版本
    local ver_num
    ver_num="$(grep -oE '[0-9]+([.][0-9]+)*' <<<"$ver_raw" | head -n1 || true)"
    if [[ -z "$ver_num" ]]; then
      log "WARN: $f 的 PKG_VERSION='$ver_raw' 无法提取数字，跳过。"
      return 0
    fi

    log "修复 $f: PKG_VERSION '$ver_raw' -> '$ver_num'"
    cp -n "$f" "$f.bak" 2>/dev/null || true

    # 1) 替换首个 PKG_VERSION 为数字版本
    sed -i -E "0,/^[[:space:]]*PKG_VERSION:=/ s//PKG_VERSION:=${ver_num}/" "$f"

    # 2) 若无 PKG_SOURCE_VERSION，则在第一处 PKG_VERSION 行之后插入
    if ! grep -qE '^[[:space:]]*PKG_SOURCE_VERSION:=' "$f"; then
      awk -v raw="$ver_raw" '
        BEGIN{added=0}
        {
          print $0
          if (!added && $0 ~ /^[[:space:]]*PKG_VERSION:=/) {
            print "PKG_SOURCE_VERSION:=" raw
            added=1
          }
        }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi

    # 3) 若无 PKG_BUILD_DIR，则在 PKG_SOURCE_VERSION 后面补一行
    if ! grep -qE '^[[:space:]]*PKG_BUILD_DIR:=' "$f"; then
      awk '
        BEGIN{added=0}
        {
          print $0
          if (!added && $0 ~ /^[[:space:]]*PKG_SOURCE_VERSION:=/) {
            print "PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_SOURCE_VERSION)"
            added=1
          }
        }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi

    # 4) 让 PKG_SOURCE / PKG_SOURCE_URL 里的 $(PKG_VERSION) 指向 $(PKG_SOURCE_VERSION)
    sed -i -E '/^[[:space:]]*PKG_SOURCE:=/ s/\$\((PKG_VERSION)\)/$(PKG_SOURCE_VERSION)/g' "$f"
    sed -i -E '/^[[:space:]]*PKG_SOURCE_URL:=/ s/\$\((PKG_VERSION)\)/$(PKG_SOURCE_VERSION)/g' "$f"
  }

  # 在 ROOT 下最多 3 层（或自定义 MAX_DEPTH）寻找所有 Makefile
  while IFS= read -r -d '' mk; do
    process_file "$mk"
  done < <(find "$ROOT" -maxdepth "$MAX_DEPTH" -type f -name Makefile -print0)

  log "扫描与修复完成。"
}

# opkg模式下不需要了
#fix_openwrt_apk_versions package

#fix cmake minimum version issue
if ! grep -q "CMAKE_POLICY_VERSION_MINIMUM" include/cmake.mk; then
  echo 'CMAKE_OPTIONS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5' >> include/cmake.mk
fi

patch_openwrt_go() {
    # 1. 确定 Makefile 路径 (通常在 feeds/packages/lang/golang/golang/Makefile)
    # 使用 find 增加容错，防止目录结构略有不同
    local GO_MAKEFILE
    GO_MAKEFILE=$(find feeds -name "Makefile" | grep "lang/golang/golang/Makefile" | head -n 1)

    if [ -z "$GO_MAKEFILE" ]; then
        echo "❌ Error: Could not find OpenWrt Go Makefile!"
        return 1
    fi
    echo "found go makefile: $GO_MAKEFILE"

    # 2. 获取 Go 最新版本号 (例如 1.25.6)
    local LATEST_VER
    LATEST_VER="$(curl -s "https://go.dev/VERSION?m=text" | head -n 1 | tr -d '[:space:]' | sed 's/^go//')"
    
    if [ -z "$LATEST_VER" ]; then
        echo "❌ Error: Failed to fetch latest Go version."
        return 1
    fi

    # 3. 检查当前 Makefile 里的版本
    local CUR_VER
    CUR_VER=$(grep "^PKG_VERSION:=" "$GO_MAKEFILE" | cut -d= -f2)
    echo "Current OpenWrt Go version: $CUR_VER"
    echo "Target Latest Go version:   $LATEST_VER"

    if [ "$CUR_VER" == "$LATEST_VER" ]; then
        echo "✅ Version is already up to date."
        return 0
    fi

    # 4. 计算源码包的 SHA256 Hash (这是最关键的一步，不改 Hash 会导致下载校验失败)
    # 注意：OpenWrt 编译 Go 用的是 src 包，不是 linux-amd64 包！
    echo "☁️  Downloading source info to calculate hash..."
    local SRC_URL="https://go.dev/dl/go${LATEST_VER}.src.tar.gz"
    local NEW_HASH
    NEW_HASH=$(curl -sL "$SRC_URL" | sha256sum | awk '{print $1}')

    if [ -z "$NEW_HASH" ] || [ ${#NEW_HASH} -ne 64 ]; then
        echo "❌ Error: Failed to calculate SHA256 hash."
        return 1
    fi
    echo "New Hash: $NEW_HASH"

    # 5. 使用 sed 修改 Makefile
    echo "🔧 Patching Makefile..."
    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$LATEST_VER/" "$GO_MAKEFILE"
    sed -i "s/^PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/" "$GO_MAKEFILE"

    # 6. 验证修改
    echo "--------------------------------------"
    grep -E "^PKG_VERSION|^PKG_HASH" "$GO_MAKEFILE"
    echo "--------------------------------------"
    echo "✅ OpenWrt Go toolchain patched to $LATEST_VER successfully!"
}

# 执行补丁
patch_openwrt_go || exit 1

