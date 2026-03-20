#!/bin/sh /etc/rc.common

START=99
STOP=15

CONFIG="luci-app-ipsec-server"
IPSEC_SECRETS_FILE=/etc/ipsec.secrets
IPSEC_CONN_FILE=/etc/ipsec.conf
CHAP_SECRETS=/etc/ppp/chap-secrets
L2TP_PATH=/var/etc/xl2tpd
L2TP_CONTROL_FILE=${L2TP_PATH}/control
L2TP_CONFIG_FILE=${L2TP_PATH}/xl2tpd.conf
L2TP_OPTIONS_FILE=${L2TP_PATH}/options.xl2tpd
L2TP_LOG_FILE=${L2TP_PATH}/xl2tpd.log

# 核心配置变量
vt_clientip=$(uci -q get ${CONFIG}.@service[0].clientip)
l2tp_enabled=$(uci -q get ${CONFIG}.@service[0].l2tp_enable)
l2tp_localip=$(uci -q get ${CONFIG}.@service[0].l2tp_localip)
ipt_flag="IPSec VPN Server"

# ===== 替换原有ipt_rule：改用FW4/UCI配置 =====
fw4_rule() {
	if [ "$1" = "add" ]; then
		echo "[INFO] 添加FW4 IPSec/L2TP规则..."
		# 1. 删除旧规则（避免重复）
		uci -q delete firewall.ipsec_vpn_input
		uci -q delete firewall.ipsec_vpn_esp
		uci -q delete firewall.ipsec_vpn_nat
		uci -q delete firewall.ipsec_vpn_forward
		uci -q delete firewall.l2tp_vpn_input
		uci -q delete firewall.l2tp_vpn_nat
		uci -q delete firewall.l2tp_vpn_forward

		# 2. IPSec基础规则（500/4500端口 + ESP协议）
		# - 允许500/4500端口
		uci set firewall.ipsec_vpn_input="rule"
		uci set firewall.ipsec_vpn_input.name="${ipt_flag}-Input"
		uci set firewall.ipsec_vpn_input.src="wan"
		uci set firewall.ipsec_vpn_input.proto="udp"
		uci add_list firewall.ipsec_vpn_input.dest_port="500"
		uci add_list firewall.ipsec_vpn_input.dest_port="4500"
		uci set firewall.ipsec_vpn_input.target="ACCEPT"
		uci set firewall.ipsec_vpn_input.family="ipv4"

		# - 允许ESP协议
		uci set firewall.ipsec_vpn_esp="rule"
		uci set firewall.ipsec_vpn_esp.name="${ipt_flag}-ESP"
		uci set firewall.ipsec_vpn_esp.src="wan"
		uci set firewall.ipsec_vpn_esp.proto="esp"
		uci set firewall.ipsec_vpn_esp.target="ACCEPT"
		uci set firewall.ipsec_vpn_esp.family="ipv4"

		# - IPSec NAT规则（MASQUERADE）
		uci set firewall.ipsec_vpn_nat="nat"
		uci set firewall.ipsec_vpn_nat.name="${ipt_flag}-NAT"
		uci set firewall.ipsec_vpn_nat.src="ipsecserver"
		#uci set firewall.ipsec_vpn_nat.src_ip="${vt_clientip}"
		uci set firewall.ipsec_vpn_nat.target="MASQUERADE"
		uci set firewall.ipsec_vpn_nat.srcnat="1"
		uci set firewall.ipsec_vpn_nat.family="ipv4"
		uci set firewall.ipsec_vpn_nat.dest='wan'

		# - IPSec转发规则
		uci set firewall.ipsec_vpn_forward="rule"
		uci set firewall.ipsec_vpn_forward.name="${ipt_flag}-Forward"
		uci set firewall.ipsec_vpn_forward.src="ipsecserver"
		uci set firewall.ipsec_vpn_forward.dest="wan"
		uci set firewall.ipsec_vpn_forward.target="ACCEPT"
		uci set firewall.ipsec_vpn_forward.family="ipv4"

		# 3. L2TP规则（如果启用）
		[ "${l2tp_enabled}" = 1 ] && {
			# - 允许1701端口
			uci set firewall.l2tp_vpn_input="rule"
			uci set firewall.l2tp_vpn_input.name="${ipt_flag}-L2TP-Input"
			uci set firewall.l2tp_vpn_input.src="wan"
			uci set firewall.l2tp_vpn_input.proto="udp"
			uci set firewall.l2tp_vpn_input.dest_port="1701"
			uci set firewall.l2tp_vpn_input.target="ACCEPT"
			uci set firewall.l2tp_vpn_input.family="ipv4"

			# - L2TP NAT规则
			uci set firewall.l2tp_vpn_nat="redirect"
			uci set firewall.l2tp_vpn_nat.name="${ipt_flag}-L2TP-NAT"
			uci set firewall.l2tp_vpn_nat.src="ipsecserver"
			uci set firewall.l2tp_vpn_nat.src_ip="${l2tp_localip%.*}.0/24"
			uci set firewall.l2tp_vpn_nat.target="MASQUERADE"
			uci set firewall.l2tp_vpn_nat.srcnat="1"
			uci set firewall.l2tp_vpn_nat.family="ipv4"

			# - L2TP转发规则
			uci set firewall.l2tp_vpn_forward="rule"
			uci set firewall.l2tp_vpn_forward.name="${ipt_flag}-L2TP-Forward"
			uci set firewall.l2tp_vpn_forward.src="ipsecserver"
			uci set firewall.l2tp_vpn_forward.dest="wan"
			uci set firewall.l2tp_vpn_forward.target="ACCEPT"
			uci set firewall.l2tp_vpn_forward.family="ipv4"
		}

		# 保存并应用规则
		uci commit firewall
		fw4 reload 2>/dev/null
		echo "[INFO] FW4规则添加完成"
	else
		echo "[INFO] 删除FW4 IPSec/L2TP规则..."
		# 删除所有相关规则
		uci -q delete firewall.ipsec_vpn_input
		uci -q delete firewall.ipsec_vpn_esp
		uci -q delete firewall.ipsec_vpn_nat
		uci -q delete firewall.ipsec_vpn_forward
		uci -q delete firewall.l2tp_vpn_input
		uci -q delete firewall.l2tp_vpn_nat
		uci -q delete firewall.l2tp_vpn_forward
		uci commit firewall
		fw4 reload 2>/dev/null
		echo "[INFO] FW4规则删除完成"
	fi
}

# ===== 移除原有gen_include（FW4不需要）=====
gen_include() {
	return 0
}

# ===== 保留原有get_enabled_anonymous_secs函数 =====
get_enabled_anonymous_secs() {
	uci -q show "${CONFIG}" | grep "${1}\[.*\.enabled='1'" | cut -d '.' -sf2
}

# ===== 修复start函数（保留核心功能，替换ipt_rule为fw4_rule）=====
start() {
	local vt_enabled=$(uci -q get ${CONFIG}.@service[0].enabled)
	[ "$vt_enabled" = 0 ] && return 1

	local vt_gateway="${vt_clientip%.*}.1"
	local vt_secret=$(uci -q get ${CONFIG}.@service[0].secret)

	local l2tp_enabled=$(uci -q get ${CONFIG}.@service[0].l2tp_enable)
	[ "${l2tp_enabled}" = 1 ] && {
		touch ${CHAP_SECRETS}
		local vt_remoteip=$(uci -q get ${CONFIG}.@service[0].l2tp_remoteip)
		local ipsec_l2tp_config=$(cat <<-EOF
		#######################################
		# L2TP Connections
		#######################################

		conn L2TP-IKEv1-PSK
		  type=transport
		  keyexchange=ikev1
		  authby=secret
		  leftprotoport=udp/l2tp
		  left=%any
		  right=%any
		  rekey=no
		  forceencaps=yes
		  ike=aes128-sha1-modp2048,aes128-sha1-modp1024,3des-sha1-modp1024,3des-sha1-modp1536
		  esp=aes128-sha1,3des-sha1
		EOF
		)

		mkdir -p ${L2TP_PATH}
		cat > ${L2TP_OPTIONS_FILE} <<-EOF
			name "l2tp-server"
			ipcp-accept-local
			ipcp-accept-remote
			ms-dns ${l2tp_localip}
			noccp
			auth
			idle 1800
			mtu 1400
			mru 1400
			lcp-echo-failure 10
			lcp-echo-interval 60
			connect-delay 5000
		EOF
		cat > ${L2TP_CONFIG_FILE} <<-EOF
			[global]
			port = 1701
			;debug avp = yes
			;debug network = yes
			;debug state = yes
			;debug tunnel = yes
			[lns default]
			ip range = ${vt_remoteip}
			local ip = ${l2tp_localip}
			require chap = yes
			refuse pap = yes
			require authentication = no
			name = l2tp-server
			;ppp debug = yes
			pppoptfile = ${L2TP_OPTIONS_FILE}
			length bit = yes
		EOF

		local l2tp_users=$(get_enabled_anonymous_secs "@l2tp_users")
		[ -n "${l2tp_users}" ] && {
			for _user in ${l2tp_users}; do
				local u_enabled=$(uci -q get ${CONFIG}.${_user}.enabled)
				[ "${u_enabled}" -eq 1 ] || continue

				local u_username=$(uci -q get ${CONFIG}.${_user}.username)
				[ -n "${u_username}" ] || continue

				local u_password=$(uci -q get ${CONFIG}.${_user}.password)
				[ -n "${u_password}" ] || continue

				local u_ipaddress=$(uci -q get ${CONFIG}.${_user}.ipaddress)
				[ -n "${u_ipaddress}" ] || u_ipaddress="*"

				echo "${u_username} l2tp-server ${u_password} ${u_ipaddress}" >> ${CHAP_SECRETS}
			done
		}
		unset user

		echo "ip-up-script /usr/share/xl2tpd/ip-up" >> ${L2TP_OPTIONS_FILE}
		echo "ip-down-script /usr/share/xl2tpd/ip-down" >> ${L2TP_OPTIONS_FILE}

		# 修复L2TP启动命令（后台运行）
		xl2tpd -c ${L2TP_CONFIG_FILE} -C ${L2TP_CONTROL_FILE} -D >${L2TP_LOG_FILE} 2>&1 &
	}

	# 生成IPSec配置文件（保留原有逻辑）
	cat > ${IPSEC_CONN_FILE} <<-EOF
		# ipsec.conf - strongSwan IPsec configuration file

		config setup
		  uniqueids=no
		  charondebug="cfg 2, dmn 2, ike 2, net 0"

		conn %default
		  dpdaction=clear
		  dpddelay=300s
		  rekey=no
		  left=%defaultroute
		  leftfirewall=yes
		  right=%any
		  ikelifetime=60m
		  keylife=20m
		  rekeymargin=3m
		  keyingtries=1
		  auto=add

		#######################################
		# Default non L2TP Connections
		#######################################

		conn Non-L2TP
		  leftsubnet=0.0.0.0/0
		  rightsubnet=${vt_clientip}
		  rightsourceip=${vt_clientip}
		  rightdns=${vt_gateway}
		  ike=aes128-sha1-modp2048,aes128-sha1-modp1024,3des-sha1-modp1024,3des-sha1-modp1536
		  esp=aes128-sha1,3des-sha1

		# Cisco IPSec
		conn IKEv1-PSK-XAuth
		  also=Non-L2TP
		  keyexchange=ikev1
		  leftauth=psk
		  rightauth=psk
		  rightauth2=xauth

		$ipsec_l2tp_config
	EOF

	# 生成IPSec密钥文件
	cat > /etc/ipsec.secrets <<-EOF
	# /etc/ipsec.secrets - strongSwan IPsec secrets file
	: PSK "$vt_secret"
	EOF

	# 添加IPSec用户
	local ipsec_users=$(get_enabled_anonymous_secs "@ipsec_users")
	[ -n "${ipsec_users}" ] && {
		for _user in ${ipsec_users}; do
			local u_enabled=$(uci -q get ${CONFIG}.${_user}.enabled)
			[ "${u_enabled}" -eq 1 ] || continue

			local u_username=$(uci -q get ${CONFIG}.${_user}.username)
			[ -n "${u_username}" ] || continue

			local u_password=$(uci -q get ${CONFIG}.${_user}.password)
			[ -n "${u_password}" ] || continue

			echo "${u_username} : XAUTH '${u_password}'" >> ${IPSEC_SECRETS_FILE}
		done
	}
	unset user

	# 替换ipt_rule为fw4_rule
	fw4_rule add

	# 修复IPSec启动命令（用ipsec start加载完整配置）
	ipsec stop >/dev/null 2>&1
	sleep 1
	/usr/lib/ipsec/starter --daemon charon --nofork > /dev/null 2>&1 &
	sleep 2

	# 配置ipsec_server接口
	uci -q batch <<-EOF >/dev/null
		set network.ipsec_server.ipaddr="${vt_clientip%.*}.1"
		commit network
	EOF
	ifup ipsec_server > /dev/null 2>&1

	echo "[INFO] IPSec/L2TP服务启动成功！"
}

# ===== 修复stop函数（移除无效操作，替换ipt_rule为fw4_rule）=====
stop() {
	echo "[INFO] 停止IPSec/L2TP服务..."
	# 停止接口
	ifdown ipsec_server > /dev/null 2>&1

	# 清理CHAP_SECRETS
	sed -i '/l2tp-server/d' ${CHAP_SECRETS} 2>/dev/null

	# 停止L2TP进程
	pkill -9 xl2tpd >/dev/null 2>&1
	rm -rf ${L2TP_PATH}

	# 停止IPSec进程
	ipsec stop >/dev/null 2>&1
	pkill -9 charon >/dev/null 2>&1

	# 替换ipt_rule为fw4_rule
	fw4_rule del

	# 移除无效的libipsec.so.0链接操作（保留空行，避免语法错误）

	echo "[INFO] IPSec/L2TP服务已停止！"
}

# ===== 修复网络/防火墙区域创建（确保ipsecserver zone正确）=====
gen_iface_and_firewall() {
	uci -q batch <<-EOF >/dev/null
		delete network.ipsec_server
		set network.ipsec_server=interface
		set network.ipsec_server.device="ipsec0"
		set network.ipsec_server.proto="static"
		set network.ipsec_server.ipaddr="${vt_clientip%.*}.1"
		set network.ipsec_server.netmask="255.255.255.0"
		commit network

		delete firewall.ipsecserver
		set firewall.ipsecserver=zone
		set firewall.ipsecserver.name="ipsecserver"
		set firewall.ipsecserver.input="ACCEPT"
		set firewall.ipsecserver.forward="ACCEPT"
		set firewall.ipsecserver.output="ACCEPT"
		set firewall.ipsecserver.network="ipsec_server"
		# 增加lan转发（关键：允许ipsecserver访问lan）
		set firewall.ipsecserver_forward_lan=forwarding
		set firewall.ipsecserver_forward_lan.src="ipsecserver"
		set firewall.ipsecserver_forward_lan.dest="lan"
		# 增加wan转发
		set firewall.ipsecserver_forward_wan=forwarding
		set firewall.ipsecserver_forward_wan.src="ipsecserver"
		set firewall.ipsecserver_forward_wan.dest="wan"
		commit firewall
	EOF
}

# ===== 初始化检查（保留原有逻辑）=====
if [ -z "$(uci -q get network.ipsec_server)" ] || [ -z "$(uci -q get firewall.ipsecserver)" ]; then
	gen_iface_and_firewall
fi