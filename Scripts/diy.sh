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
# 网络测试 speedtest-cli
UPDATE_PACKAGE "speedtest-cli" "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"
UPDATE_PACKAGE "luci-app-netspeedtest" "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"
# 带宽监控 bandix
UPDATE_PACKAGE "openwrt-bandix" "timsaya/openwrt-bandix" "main"
UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"

# 直接安装所需的应用
UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"
# 端口转发 socat
UPDATE_PACKAGE "luci-app-socat" "https://github.com/sbwml/luci-app-socat" "main"
# WOL Plus
UPDATE_PACKAGE "luci-app-wolplus" "VIKINGYFY/packages" "main"

# 配置项
provided_config_lines=(
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
    #########

    "CONFIG_PACKAGE_luci-app-ipsec-server=y"
    "CONFIG_PACKAGE_luci-app-socat=y"
    "CONFIG_PACKAGE_luci-app-openclash=y"
    "CONFIG_PACKAGE_luci-app-bandix=y"
    "CONFIG_PACKAGE_luci-app-wolplus=y"
    "CONFIG_PACKAGE_luci-app-autoreboot=y"
    "CONFIG_PACKAGE_luci-app-ttyd=y"
    "CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y"
    "CONFIG_PACKAGE_ttyd=y"
    "CONFIG_PACKAGE_kmod-wireguard=y"
    "CONFIG_PACKAGE_wireguard-tools=y"
    "CONFIG_PACKAGE_luci-proto-wireguard=y"
    #"CONFIG_PACKAGE_ddns-scripts=y"
    #"CONFIG_PACKAGE_ddns-scripts_cloudflare.com-v4=y"
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