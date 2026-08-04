#!/bin/bash

# 安装和更新软件包 (带重试机制)
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4

    # 清理旧的包
    read -ra PKG_NAMES <<< "$PKG_NAME"
    for NAME in "${PKG_NAMES[@]}"; do
        find feeds/luci/ feeds/packages/ package/ -maxdepth 3 -type d \( -name "$NAME" -o -name "luci-*-$NAME" \) -exec rm -rf {} + 2>/dev/null
    done

    # 解析仓库地址
    if [[ $PKG_REPO == http* ]]; then
        local REPO_NAME=$(basename "$PKG_REPO" .git)
    else
        local REPO_NAME=$(echo "$PKG_REPO" | cut -d '/' -f 2)
        PKG_REPO="https://github.com/$PKG_REPO.git"
    fi

    # 克隆仓库 (最多重试3次)
    local RETRY=3
    local COUNT=0
    while [ $COUNT -lt $RETRY ]; do
        echo "克隆 $PKG_REPO (第 $((COUNT+1))/$RETRY 次)..."
        if git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "$PKG_REPO" "package/$REPO_NAME"; then
            echo "✓ $REPO_NAME 克隆成功"
            break
        else
            echo "克隆失败，5 秒后重试..."
            sleep 5
            COUNT=$((COUNT+1))
        fi
    done

    if [ ! -d "package/$REPO_NAME" ]; then
        echo "✗ 错误: 克隆失败 $PKG_REPO"
        return 1
    fi

    # 根据类型处理包
    case "$PKG_SPECIAL" in
        "pkg")
            for NAME in "${PKG_NAMES[@]}"; do
                find "./package/$REPO_NAME" -maxdepth 3 -type d \( -name "$NAME" -o -name "luci-*-$NAME" \) -print0 | \
                    xargs -0 -I {} cp -rf {} ./package/ 2>/dev/null
            done
            rm -rf "./package/$REPO_NAME/"
            ;;
        "name")
            rm -rf "./package/$PKG_NAME"
            mv -f "./package/$REPO_NAME" "./package/$PKG_NAME"
            ;;
    esac
}

# =======================================================
# 1. 安装插件包 (argon 和 openclash 由 Packages.sh 安装，此处不重复)
# =======================================================

# IPSec 服务器 + Web 管理 + TurboAcc
UPDATE_PACKAGE "luci-app-ipsec-server \
                luci-app-webadmin \
                luci-app-turboacc \
                " "https://github.com/kenzok8/jell" "main" "pkg"

# iStore 应用商店
UPDATE_PACKAGE "taskd luci-lib-xterm luci-lib-taskd luci-app-store" "https://github.com/linkease/istore" "main" "pkg"

# 网络测试 + Socat
UPDATE_PACKAGE "speedtest-cli luci-app-netspeedtest \
                 luci-app-socat \
                 " "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"

# 打印服务 CUPS
UPDATE_PACKAGE "cups luci-app-cupsd \
                 " "https://github.com/fichenx/openwrt-package" "main" "pkg"

# 高级功能插件
UPDATE_PACKAGE "luci-app-advanced" "https://github.com/sirpdboy/luci-app-advanced" "master"

# 带宽监控 bandix
UPDATE_PACKAGE "openwrt-bandix" "timsaya/openwrt-bandix" "main"
UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"

# 网络唤醒 WolPlus
UPDATE_PACKAGE "luci-app-wolplus" "VIKINGYFY/packages" "main"

# Tailscale 组网
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

# =======================================================
# 2. 追加 .config 配置项
# =======================================================

provided_config_lines=(
    "CONFIG_PACKAGE_luci-app-webadmin=y"
    "CONFIG_PACKAGE_luci-app-filemanager=y"
    "CONFIG_PACKAGE_luci-theme-argon=y"
    "CONFIG_PACKAGE_luci-app-argon-config=y"
    "CONFIG_PACKAGE_luci-app-ipsec-server=y"
    "CONFIG_PACKAGE_luci-app-socat=y"
    "CONFIG_PACKAGE_luci-app-openclash=y"
    "CONFIG_PACKAGE_luci-app-wolplus=y"
    "CONFIG_PACKAGE_luci-app-advanced=y"
    "CONFIG_PACKAGE_luci-app-turboacc=y"
    "CONFIG_PACKAGE_luci-app-tailscale=y"
)

# 为 ax6600 追加配置
[[ $WRT_CONFIG == *"ax6600"* ]] && provided_config_lines+=(
    "CONFIG_PACKAGE_luci-app-sqm=y"
    "CONFIG_PACKAGE_luci-i18n-sqm-zh-cn=y"
    "CONFIG_PACKAGE_sqm-scripts-nss=y"
    "CONFIG_ATH11K_THERMAL=y"
    "CONFIG_PACKAGE_luci-app-samba4=y"
    "CONFIG_PACKAGE_taskd=y"
    "CONFIG_PACKAGE_luci-lib-taskterm=y"
    "CONFIG_PACKAGE_luci-lib-xterm=y"
    "CONFIG_PACKAGE_luci-app-store=y"
)

for line in "${provided_config_lines[@]}"; do
    echo "$line" >> .config
done

# =======================================================
# 3. 源码补丁和修复
# =======================================================

# 网络接口获取函数修复
find ./ -name "getifaddr.c" -exec sed -i 's/return 1;/return 0;/g' {} \;

# ttyd 免密登录
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_ttyd-nopass.sh" "package/base-files/files/etc/uci-defaults/99_ttyd-nopass"

# argon 主题设为默认
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_set_argon_primary" "package/base-files/files/etc/uci-defaults/99_set_argon_primary"

# dropbear 配置修复
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_dropbear_setup.sh" "package/base-files/files/etc/uci-defaults/99_dropbear_setup"

# 强制解锁无线限值 (国家码/DFS/功率)
sed -i 's/REGDOMAIN_GLOBAL/REGDOMAIN_US/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh

# Makefile 版本修复
if [ -f ./package/v2ray-geodata/Makefile ]; then
    sed -i 's/VER)-\$(PKG_RELEASE)/VER)-r\$(PKG_RELEASE)/g' ./package/v2ray-geodata/Makefile
fi
if [ -f ./package/luci-app-openclash/Makefile ]; then
    sed -i '/^PKG_VERSION:=/a PKG_RELEASE:=1' ./package/luci-app-openclash/Makefile
fi
if [ -f ./package/luci-app-quickstart/Makefile ]; then
    sed -i -E 's/PKG_VERSION:=([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/PKG_VERSION:=\1\nPKG_RELEASE:=\2/' ./package/luci-app-quickstart/Makefile
fi

# cmake 版本兼容 (只执行一次)
if ! grep -q "CMAKE_POLICY_VERSION_MINIMUM" include/cmake.mk; then
    echo 'CMAKE_OPTIONS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5' >> include/cmake.mk
fi

# ddns-go 启动脚本替换
if [ -f ./package/luci-app-ddns-go/ddns-go/file/ddns-go.init ]; then
    cp ${GITHUB_WORKSPACE}/Scripts/ddns-go.init ./package/luci-app-ddns-go/ddns-go/file/ddns-go.init
    chmod +x ./package/luci-app-ddns-go/ddns-go/file/ddns-go.init
    echo "ddns-go.init replaced."
fi

# IPSec 服务器 init 脚本替换
if [ -f ./package/luci-app-ipsec-server/root/etc/init.d/luci-app-ipsec-server ]; then
    cp -rf ${GITHUB_WORKSPACE}/Scripts/99_fix_ipsec_server.sh ./package/luci-app-ipsec-server/root/etc/init.d/luci-app-ipsec-server
    chmod +x ./package/luci-app-ipsec-server/root/etc/init.d/luci-app-ipsec-server
    echo "ipsec-server.init replaced."
fi

# =======================================================
# 4. 自动下载 Clash 内核
# =======================================================

if [ -d ./package/luci-app-openclash ]; then
    echo "下载 Clash Meta 内核 (arm64)..."
    mkdir -p package/base-files/files/etc/openclash/core/
    if wget -q -O clash-linux-arm64.tar.gz https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz; then
        if tar -xzf clash-linux-arm64.tar.gz; then
            mv clash package/base-files/files/etc/openclash/core/clash_meta
            chmod +x package/base-files/files/etc/openclash/core/clash_meta
            echo "✓ Clash Meta 内核安装成功"
        else
            echo "✗ Clash 内核解压失败"
        fi
    else
        echo "✗ Clash 内核下载失败，编译后可手动安装"
    fi
    rm -f clash-linux-arm64.tar.gz
fi

# =======================================================
# 5. Docker 修复 (仅当配置启用时执行)
# =======================================================

if grep -q "luci-app-dockerman" .config 2>/dev/null; then
    echo "Docker 已启用，开始修复编译依赖..."

    # 清理残留
    rm -rf package/feeds/luci/luci-app-dockerman package/feeds/luci/luci-lib-docker
    rm -rf package/luci-app-dockerman package/luci-lib-docker

    # 克隆 dockerman 和 lib-docker
    git clone --depth 1 https://github.com/lisaac/luci-app-dockerman.git temp_dockerman
    mv temp_dockerman/applications/luci-app-dockerman package/luci-app-dockerman
    rm -rf temp_dockerman

    git clone --depth 1 https://github.com/lisaac/luci-lib-docker.git temp_libdocker
    if [ -d "temp_libdocker/collections/luci-lib-docker" ]; then
        mv temp_libdocker/collections/luci-lib-docker package/luci-lib-docker
    else
        mv temp_libdocker package/luci-lib-docker
    fi
    rm -rf temp_libdocker

    # 移除 cgroupfs-mount 依赖
    if [ -f "package/luci-app-dockerman/Makefile" ]; then
        sed -i 's/+cgroupfs-mount //g' package/luci-app-dockerman/Makefile
        sed -i 's/+cgroupfs-mount//g' package/luci-app-dockerman/Makefile
    fi

    ./scripts/feeds install ttyd
    ./scripts/feeds install luci-lib-docker

    # 修复 Docker 引擎版本
    DOCKER_VER="29.2.1"
    DOCKER_COMMIT="730e6f2"

    dockerd_makefile=$(find package/ feeds/ -name Makefile | xargs grep -l "PKG_NAME:=dockerd" | head -n 1)
    docker_makefile=$(find package/ feeds/ -name Makefile | xargs grep -l "PKG_NAME:=docker" | head -n 1)

    if [ -f "$dockerd_makefile" ]; then
        echo "修复 dockerd Makefile..."
        sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$DOCKER_VER/" "$dockerd_makefile"
        sed -i "s/PKG_GIT_SHORT_COMMIT:=.*/PKG_GIT_SHORT_COMMIT:=$DOCKER_COMMIT/g" "$dockerd_makefile"
        sed -i 's/^PKG_HASH:=.*/PKG_HASH:=skip/' "$dockerd_makefile"
        sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=docker-$DOCKER_VER/" "$dockerd_makefile"
        sed -i "s/^PKG_SOURCE:=.*/PKG_SOURCE:=moby-docker-$DOCKER_VER.tar.gz/" "$dockerd_makefile"
        sed -i '/define Build\/Prepare/,/endef/c\define Build\/Prepare\n\t$(Build\/Prepare\/Default)\nendef' "$dockerd_makefile"
        sed -i 's/^\t$(call EnsureVendored/#\t$(call EnsureVendored/g' "$dockerd_makefile"
    fi

    if [ -f "$docker_makefile" ]; then
        echo "修复 docker CLI Makefile..."
        sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$DOCKER_VER/" "$docker_makefile"
        sed -i "s/PKG_GIT_SHORT_COMMIT:=.*/PKG_GIT_SHORT_COMMIT:=$DOCKER_COMMIT/g" "$docker_makefile"
        sed -i 's/^PKG_HASH:=.*/PKG_HASH:=skip/' "$docker_makefile"
        sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=docker-$DOCKER_VER/" "$docker_makefile"
        sed -i "s/^PKG_SOURCE:=.*/PKG_SOURCE:=moby-docker-$DOCKER_VER.tar.gz/" "$docker_makefile"
        sed -i '/define Build\/Prepare/,/endef/c\define Build\/Prepare\n\t$(Build\/Prepare\/Default)\nendef' "$docker_makefile"
    fi
    echo "✓ Docker 编译修复完成"
else
    echo "Docker 未启用，跳过修复"
fi

# =======================================================
# 6. Go 工具链自动更新 (网络失败不中断编译)
# =======================================================

patch_openwrt_go() {
    local GO_MAKEFILE
    GO_MAKEFILE=$(find feeds -name "Makefile" | grep "lang/golang/golang/Makefile" | head -n 1)

    if [ -z "$GO_MAKEFILE" ]; then
        echo "未找到 Go Makefile，跳过"
        return 0
    fi

    local LATEST_VER
    LATEST_VER="$(curl -s --max-time 10 "https://go.dev/VERSION?m=text" | head -n 1 | tr -d '[:space:]' | sed 's/^go//')"

    if [ -z "$LATEST_VER" ]; then
        echo "⚠ 无法获取 Go 最新版本 (网络问题)，使用源码默认版本"
        return 0
    fi

    local CUR_VER
    CUR_VER=$(grep "^PKG_VERSION:=" "$GO_MAKEFILE" | cut -d= -f2)
    echo "Go: 当前 $CUR_VER → 最新 $LATEST_VER"

    if [ "$CUR_VER" == "$LATEST_VER" ]; then
        echo "✓ Go 版本已最新"
        return 0
    fi

    echo "下载 Go 源码计算 SHA256..."
    local NEW_HASH
    NEW_HASH=$(curl -sL --max-time 120 "https://go.dev/dl/go${LATEST_VER}.src.tar.gz" | sha256sum | awk '{print $1}')

    if [ -z "$NEW_HASH" ] || [ ${#NEW_HASH} -ne 64 ]; then
        echo "⚠ Go SHA256 计算失败，使用源码默认版本"
        return 0
    fi

    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$LATEST_VER/" "$GO_MAKEFILE"
    sed -i "s/^PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/" "$GO_MAKEFILE"
    echo "✓ Go 工具链已更新到 $LATEST_VER"
}

patch_openwrt_go || echo "⚠ Go 补丁跳过，不影响编译"

# =======================================================
# 7. 创建初始化脚本 (首次启动执行)
# =======================================================

mkdir -p package/base-files/files/etc/uci-defaults/
cat <<'INIT_EOF' > package/base-files/files/etc/uci-defaults/99-init-config
#!/bin/sh

# ===== WiFi 优化 =====
# 2.4G (radio0)
uci set wireless.radio0.country='US'
uci set wireless.radio0.channel='11'
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.mu_beamformer='1'
uci set wireless.radio0.doth='0'
uci commit wireless

# 5G (radio1)
uci set wireless.radio1.country='US'
uci set wireless.radio1.channel='149'
uci set wireless.radio1.htmode='HE160'
uci set wireless.radio1.mu_beamformer='1'
uci set wireless.radio1.vht_mu_mimo='1'
uci set wireless.radio1.he_mu_edca='1'
uci set wireless.radio1.doth='0'
uci commit wireless

# ===== opkg 软件源配置 =====
[ -f /etc/opkg.conf ] && sed -i '/^\s*option check_signature/ s/^/#/' /etc/opkg.conf

cat <<'OPKG_EOF' >> /etc/opkg/customfeeds.conf
src/gz openwrt_base https://mirrors.vsean.net/openwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/base/
src/gz openwrt_luci https://mirrors.vsean.net/openwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/luci/
src/gz openwrt_packages https://mirrors.vsean.net/openwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/packages
src/gz openwrt_routing https://mirrors.vsean.net/openwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/routing
src/gz openwrt_telephony https://mirrors.vsean.net/openwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/telephony
OPKG_EOF

[ -f /etc/opkg/distfeeds.conf ] && sed -i 's/^/#/' /etc/opkg/distfeeds.conf

# ===== IPSec 服务器初始化 =====
# 启用 IPSec 服务，不预设密码，由用户首次在 LuCI 界面设置
uci set luci-app-ipsec-server.ipsec.enabled='1'
uci commit luci-app-ipsec-server

# ===== 应用设置 =====
wifi
/etc/init.d/luci-app-ipsec-server restart

exit 0
INIT_EOF

chmod +x package/base-files/files/etc/uci-defaults/99-init-config

# =======================================================
# 8. 切换回工作目录
# =======================================================

cd "$GITHUB_WORKSPACE/wrt/"
echo "diy.sh 执行完成，当前目录: $(pwd)"
