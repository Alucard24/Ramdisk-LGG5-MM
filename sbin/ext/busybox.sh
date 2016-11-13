#!/sbin/busybox sh

BB=/sbin/busybox

if [ "$($BB mount | $BB grep rootfs | $BB cut -c 26-27 | $BB grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /;
fi;
if [ "$($BB mount | $BB grep system | $BB grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /system;
fi;

CLEAN_BUSYBOX()
{
	for f in *; do
		case "$($BB readlink "$f")" in *usybox*)
			$BB rm "$f"
		;;
		esac
	done;
}

# Cleanup the old busybox symlinks
cd /system/xbin/;
CLEAN_BUSYBOX;

cd /system/bin/;
CLEAN_BUSYBOX;

cd /;

# execute launch_demonsu script
#chmod 06755 /sbin/launch_daemonsu.sh;
#$BB sh /sbin/launch_daemonsu.sh;

# Install latest busybox to ROM
if [ -d /su/xbin ]; then
	$BB cp /sbin/busybox /su/xbin/;
	/su/xbin/busybox --install -s /su/xbin/;
	chmod 06755 /su/xbin/busybox;
	INSTALLDIR=/su/xbin
else
	#mkdir /system/xbin;
	#chown 0.0 /system/xbin;
	#chown 0:0 /system/xbin;
	#chmod 0755 /system/xbin;
	$BB cp /sbin/busybox /system/xbin/;
	/system/xbin/busybox --install -s /system/xbin/
	chmod 06755 /system/xbin/busybox;
	INSTALLDIR=/system/xbin
fi;

# update passwd and group files for busybox.
_passwd=/system/etc/passwd
_group=/system/etc/group

addu()
{
	if [ ! -z $4 ];	then
		_shell=$4
	else 
		_shell=$INSTALLDIR/false
	fi;

	echo "${2}:x:${1}:${1}::${3}:$_shell" >> $_passwd;
}

addg()
{
	echo "${2}:x:${1}:${2}" >> $_group;
}

addug()
{
    grep ^$2: $_group || addg $1 $2 >/dev/null 2>&1;
    grep ^$2: $_passwd || addu $* >/dev/null 2>&1;
}

[ ! -f $_passwd ] && touch $_passwd
[ ! -f $_group ] && touch $_group

user_name_id_list="
1000-system
1001-radio
1002-bluetooth
1003-graphics
1004-input
1005-audio
1006-camera
1007-log
1008-compass
1009-mount
1010-wifi
1011-adb
1012-install
1013-media
1014-dhcp
1015-sdcard_rw
1016-vpn
1017-keystore
1018-usb
1019-drm
1020-mdnsr
1021-gps
1023-media_rw
1024-mtp
1026-drmrpc
1027-nfc
1028-sdcard_r
1029-clat
1030-loop_radio
1031-mediadrm
1032-package_info
1033-sdcard_pics
1034-sdcard_av
1035-sdcard_all
1036-logd
1037-shared_relro
1038-dbus
1039-tlsdate
1040-mediaex
1041-audioserver
1042-metrics_coll
1043-metricsd
1044-webserv
1045-debuggerd
1046-mediacodec
1047-cameraserver
1048-firewall
1049-trunks
1050-nvram
1051-dns
1052-dns_tether
1053-webview_zygote
2000-shell
2001-cache
2002-diag
3001-net_bt_admin
3002-net_bt
3003-inet
3004-net_raw
3005-net_admin
3006-net_bw_stats
3007-net_bw_acct
3008-net_bt_stack
3009-readproc
3010-wakelock
9997-everybody
9998-misc
9999-nobody
"

addug 0 root /data/local/cron /system/bin/sh;

for i in $user_name_id_list; do
	addug ${i%-*} ${i#*-} /system;
done;

if [ -e /su/xbin/su ]; then
	$BB chmod 06755 /su/xbin/su;
else
	$BB chmod 06755 /system/xbin/su;
fi;
if [ -e /su/xbin/daemonsu ]; then
	$BB chmod 06755 /su/xbin/daemonsu;
else
	$BB chmod 06755 /system/xbin/daemonsu;
fi;

$BB sh /sbin/ext/post-init.sh;
