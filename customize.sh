#!/system/bin/sh
# 脚本编写感谢 酷安@阿巴酱
SKIPUNZIP=0

# 获取基础环境信息
device=`getprop ro.product.device`
version=`getprop ro.build.version.incremental`
android=`getprop ro.build.version.release`

# 模块元信息直接从 module.prop 读取（SKIPUNZIP=0 时已解压到 MODPATH），
# 兼容 Magisk/KSU/APatch/MMRL 各安装器环境变量注入差异。
modname=`grep '^name=' "$MODPATH/module.prop" | cut -d= -f2`
modver=`grep '^version=' "$MODPATH/module.prop" | cut -d= -f2`
modauth=`grep '^author=' "$MODPATH/module.prop" | cut -d= -f2`

# 获取音量键状态；应用内安装无实体按键事件时，最多等 30s 后按取消处理
get_choose()
{
	local choose
	local n=0
	while [ "$n" -lt 10 ]; do
		choose="$(timeout 3 getevent -qlc 1 2>/dev/null | awk '{ print $3 }')"
		case "$choose" in
		KEY_VOLUMEUP)   echo 0; return 0 ;;
		KEY_VOLUMEDOWN) echo 1; return 0 ;;
		esac
		n=$((n + 1))
	done
	echo 1
}

# 安装时打印的信息
UiPrint()
{
	echo "$@"
	sleep 0.03
}
UiPrint "****************************"
UiPrint "- 模块: $modname"
UiPrint "- 版本: $modver"
UiPrint "- 作者: $modauth"
UiPrint "****************************"
UiPrint "- 设备代号: $device"
UiPrint "- 安卓版本: Android $android"
UiPrint "- 系统版本: $version"
UiPrint "****************************"
UiPrint "* 电池健康数据来自系统数据"
UiPrint "* 厂商或系统不同，估算准确度不同"
UiPrint "* 音量+ 安装 | 音量- 取消 | 超时自动取消"
UiPrint "? 确定安装此模块吗？"

if [ "$(get_choose)" = "0" ]; then
	UiPrint "- 已选择安装 $modname"
	UiPrint " "
	unzip -o "$ZIPFILE" '/*' -d "$MODPATH" >&2
	# 保留旧学习数据
	oldmod="/data/adb/modules/`basename "$MODPATH"`"
	if [ -n "$MODPATH" ] && [ "$oldmod" != "$MODPATH" ] && [ -d "$oldmod/data" ]; then
		mkdir -p "$MODPATH/data"
		cp -a "$oldmod"/data/. "$MODPATH"/data/ 2>/dev/null
	fi
	mkdir -p "$MODPATH/data"

	# ---- 电流倍率 ----
	UiPrint "****************************"
	UiPrint "? 电流 current_now 是否需要 ×2？"
	UiPrint "* 大多数手机选 音量-（不加倍）"
	UiPrint "* 双电芯且内核报单电芯电流选 音量+（×2）"
	UiPrint "* 超时默认不加倍"
	UiPrint "****************************"
	cur_sel="$(get_choose)"
	if [ "$cur_sel" = "0" ]; then
		UiPrint "- 电流 ×2"
		echo 2 > "$MODPATH/data/current_scale"
	else
		UiPrint "- 电流 ×1（不加倍）"
		echo 1 > "$MODPATH/data/current_scale"
	fi
	UiPrint " "

	# ---- 容量倍率 ----
	UiPrint "****************************"
	UiPrint "? 容量 charge_full / charge_full_design 是否需要 ×2？"
	UiPrint "* 大多数手机选 音量-（不加倍）"
	UiPrint "* 双电芯且内核报单电芯容量选 音量+（×2）"
	UiPrint "* 超时默认不加倍"
	UiPrint "****************************"
	cap_sel="$(get_choose)"
	if [ "$cap_sel" = "0" ]; then
		UiPrint "- 容量 ×2"
		echo 2 > "$MODPATH/data/capacity_scale"
	else
		UiPrint "- 容量 ×1（不加倍）"
		echo 1 > "$MODPATH/data/capacity_scale"
	fi
	UiPrint " "

	set_perm "$MODPATH/bin/batteryd" 0 0 0755
else
	abort "* 已取消安装"
fi
