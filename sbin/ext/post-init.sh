#!/sbin/busybox sh

# Kernel Tuning by Alucard. Thanks to dorimanx.

BB=/sbin/busybox

# protect init from oom
if [ -f /system/xbin/su ]; then
	su -c echo "-1000" > /proc/1/oom_score_adj;
fi;

OPEN_RW()
{
	if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -eq "1" ]; then
		$BB mount -o remount,rw /;
	fi;
	if [ "$($BB mount | grep system | grep -c ro)" -eq "1" ]; then
		$BB mount -o remount,rw /system;
	fi;
}
OPEN_RW;

# disable selinux enforcing
echo "0" > /sys/fs/selinux/enforce;

# run ROM scripts
# $BB sh /system/etc/init.qcom.post_boot.sh;
$BB sh /init.qcom.post_boot.sh;

OPEN_RW;
# clean old modules from /system and add new from ramdisk
if [ ! -d /system/lib/modules ]; then
        $BB mkdir /system/lib/modules;
fi;

#$BB chmod 644 /lib/modules/*.ko;
#cd /lib/modules/;
#for i in *.ko; do
#        $BB rm -f /system/lib/modules/"$i";
#done;
#$BB cp -avr * /system/lib/modules/;
#cd /;

# create init.d folder if missing
if [ ! -d /system/etc/init.d ]; then
	mkdir -p /system/etc/init.d/
	$BB chmod -R 755 /system/etc/init.d/;
fi;

OPEN_RW;

# Tune entropy parameters.
echo "512" > /proc/sys/kernel/random/read_wakeup_threshold;
echo "256" > /proc/sys/kernel/random/write_wakeup_threshold;

# some nice thing for dev
if [ ! -e /cpufreq ]; then
	$BB ln -s /sys/devices/system/cpu/cpu0/cpufreq/ /cpufreq0-1;
	$BB ln -s /sys/devices/system/cpu/cpu2/cpufreq/ /cpufreq2-3;
	$BB ln -s /sys/module/msm_performance/parameters/ /hotplugs/msm_performance;
	$BB ln -s /sys/module/msm_thermal/parameters/ /cputemp;
	$BB ln -s /sys/module/msm_thermal/core_control/ /cputempcc;
fi;

CRITICAL_PERM_FIX()
{
	# critical Permissions fix
	$BB chown -R root:root /tmp;
	$BB chown -R root:root /res;
	$BB chown -R root:root /sbin;
	# $BB chown -R root:root /lib;
	$BB chmod -R 777 /tmp/;
	$BB chmod -R 775 /res/;
	$BB chmod -R 06755 /sbin/ext/;
	$BB chmod 06755 /sbin/busybox;
	#$BB chmod 06755 /system/xbin/busybox;
	$BB chmod 0555 /system/xbin/busybox;
}
CRITICAL_PERM_FIX;

# oom and mem perm fix
$BB chmod 666 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/adj;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/minfree

# make sure we own the device nodes
$BB chown system /sys/devices/system/cpu/cpufreq/interactive/*
$BB chown system /sys/devices/system/cpu/cpu0/cpufreq/*
$BB chown system /sys/devices/system/cpu/cpu2/cpufreq/*
$BB chown system /sys/devices/system/cpu/cpu1/online
$BB chown system /sys/devices/system/cpu/cpu2/online
$BB chown system /sys/devices/system/cpu/cpu3/online
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
$BB chmod 666 /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
$BB chmod 666 /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq
$BB chmod 666 /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq
$BB chmod 666 /sys/devices/system/cpu/cpu1/online
$BB chmod 666 /sys/devices/system/cpu/cpu2/online
$BB chmod 666 /sys/devices/system/cpu/cpu3/online
$BB chmod 666 /sys/module/msm_thermal/parameters/*

if [ ! -d /data/.alucard ]; then
	$BB mkdir /data/.alucard/;
fi;

$BB chmod -R 0777 /data/.alucard/;

# reset profiles auto trigger to be used by kernel ADMIN, in case of need, if new value added in default profiles
# just set numer $RESET_MAGIC + 1 and profiles will be reset one time on next boot with new kernel.
# incase that ADMIN feel that something wrong with global STweaks config and profiles, then ADMIN can add +1 to CLEAN_ALU_DIR
# to clean all files on first boot from /data/.alucard/ folder.
RESET_MAGIC=2;
CLEAN_ALU_DIR=1;

if [ ! -e /data/.alucard/reset_profiles ]; then
	echo "$RESET_MAGIC" > /data/.alucard/reset_profiles;
fi;
if [ ! -e /data/reset_alu_dir ]; then
	echo "$CLEAN_ALU_DIR" > /data/reset_alu_dir;
fi;
if [ -e /data/.alucard/.active.profile ]; then
	PROFILE=$(cat /data/.alucard/.active.profile);
else
	echo "default" > /data/.alucard/.active.profile;
	PROFILE=$(cat /data/.alucard/.active.profile);
fi;
if [ "$(cat /data/reset_alu_dir)" -eq "$CLEAN_ALU_DIR" ]; then
	if [ "$(cat /data/.alucard/reset_profiles)" != "$RESET_MAGIC" ]; then
		if [ ! -e /data/.alucard_old ]; then
			mkdir /data/.alucard_old;
		fi;
		cp -a /data/.alucard/*.profile /data/.alucard_old/;
		$BB rm -f /data/.alucard/*.profile;
		if [ -e /data/data/com.af.synapse/databases ]; then
			$BB rm -R /data/data/com.af.synapse/databases;
		fi;
		echo "$RESET_MAGIC" > /data/.alucard/reset_profiles;
	else
		echo "no need to reset profiles or delete .alucard folder";
	fi;
else
	# Clean /data/.alucard/ folder from all files to fix any mess but do it in smart way.
	if [ -e /data/.alucard/"$PROFILE".profile ]; then
		cp /data/.alucard/"$PROFILE".profile /sdcard/"$PROFILE".profile_backup;
	fi;
	if [ ! -e /data/.alucard_old ]; then
		mkdir /data/.alucard_old;
	fi;
	cp -a /data/.alucard/* /data/.alucard_old/;
	$BB rm -f /data/.alucard/*
	if [ -e /data/data/com.af.synapse/databases ]; then
		$BB rm -R /data/data/com.af.synapse/databases;
	fi;
	echo "$CLEAN_ALU_DIR" > /data/reset_alu_dir;
	echo "$RESET_MAGIC" > /data/.alucard/reset_profiles;
	echo "$PROFILE" > /data/.alucard/.active.profile;
fi;

[ ! -f /data/.alucard/default.profile ] && cp -a /res/customconfig/default.profile /data/.alucard/default.profile;
[ ! -f /data/.alucard/battery.profile ] && cp -a /res/customconfig/battery.profile /data/.alucard/battery.profile;
[ ! -f /data/.alucard/performance.profile ] && cp -a /res/customconfig/performance.profile /data/.alucard/performance.profile;
[ ! -f /data/.alucard/extreme_performance.profile ] && cp -a /res/customconfig/extreme_performance.profile /data/.alucard/extreme_performance.profile;
[ ! -f /data/.alucard/extreme_battery.profile ] && cp -a /res/customconfig/extreme_battery.profile /data/.alucard/extreme_battery.profile;

$BB chmod -R 0777 /data/.alucard/;

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

# Load parameters....
DEBUG=/data/.alucard/;
BUSYBOX_VER=$(busybox | grep "BusyBox v" | cut -c0-15);
echo "$BUSYBOX_VER" > $DEBUG/busybox_ver;
#$BB dmesg > $DEBUG/kernel_debug.log;
#$BB mount > $DEBUG/partition_mount.log;

# start CORTEX by tree root, so it's will not be terminated.
sed -i "s/cortexbrain_background_process=[0-1]*/cortexbrain_background_process=1/g" /sbin/ext/cortexbrain-tune.sh;
if [ "$(pgrep -f "cortexbrain-tune.sh" | wc -l)" -eq "0" ]; then
	$BB nohup $BB sh /sbin/ext/cortexbrain-tune.sh > /data/.alucard/cortex.txt &
fi;

OPEN_RW;

# get values from profile
PROFILE=$(cat /data/.alucard/.active.profile);
. /data/.alucard/"$PROFILE".profile;

if [ "$stweaks_boot_control" == "yes" ]; then
	# apply STweaks settings
	$BB sh /res/uci_boot.sh apply;
	$BB mv /res/uci_boot.sh /res/uci.sh;
else
	$BB mv /res/uci_boot.sh /res/uci.sh;
fi;

######################################
# Loading Modules
######################################
MODULES_LOAD()
{
	# order of modules load is important
	if [ -e /system/lib/modules/textfat.ko ]; then
		$BB insmod /system/lib/modules/textfat.ko;
	else
		$BB insmod /lib/modules/textfat.ko;
	fi;
}

# disable debugging on some modules
  echo "N" > /sys/module/kernel/parameters/initcall_debug;
  echo "0" > /sys/module/smd/parameters/debug_mask
  echo "0" > /sys/module/smem/parameters/debug_mask
  echo "0" > /sys/module/event_timer/parameters/debug_mask
  echo "0" > /sys/module/smp2p/parameters/debug_mask
  echo "0" > /sys/module/msm_serial_hs_lge/parameters/debug_mask
  echo "0" > /sys/module/rpm_smd/parameters/debug_mask
  echo "0" > /sys/module/xt_qtaguid/parameters/debug_mask
  echo "0" > /sys/module/qpnp_regulator/parameters/debug_mask
  echo "0" > /sys/module/binder/parameters/debug_mask
  echo "0" > /sys/module/msm_show_resume_irq/parameters/debug_mask
  echo "0" > /sys/module/mpm_of/parameters/debug_mask
  echo "0" > /sys/module/msm_pm/parameters/debug_mask

OPEN_RW;

# Start any init.d scripts that may be present in the rom or added by the user
$BB chmod -R 755 /system/etc/init.d/;
if [ "$init_d" == "on" ]; then
	(
		$BB nohup $BB run-parts /system/etc/init.d/ > /data/.alucard/init.d.txt &
	)&
else
	if [ -e /system/etc/init.d/99SuperSUDaemon ]; then
		$BB nohup $BB sh /system/etc/init.d/99SuperSUDaemon > /data/.alucard/root.txt &
	else
		echo "no root script in init.d";
	fi;
fi;

OPEN_RW;

# Fix critical perms again after init.d mess
CRITICAL_PERM_FIX;

####################################################################################################
# Google Services battery drain fixer by BySezerSimsek
# http://forum.xda-developers.com/lg-g5/development/h850-genisys-rom-1-0-genisys-theme-1-0-t3421950
####################################################################################################
GOOGLE_SERVICE_BD_FIXER()
{
	if [ "$gpsfixer" == "on" ]; then
		pm disable com.google.android.gms/.ads.settings.AdsSettingsActivity
		pm disable com.google.android.gms/com.google.android.location.places.ui.aliaseditor.AliasEditorActivity
		pm disable com.google.android.gms/com.google.android.location.places.ui.aliaseditor.AliasEditorMapActivity
		pm disable com.google.android.gms/com.google.android.location.settings.ActivityRecognitionPermissionActivity
		pm disable com.google.android.gms/com.google.android.location.settings.GoogleLocationSettingsActivity
		pm disable com.google.android.gms/com.google.android.location.settings.LocationHistorySettingsActivity
		pm disable com.google.android.gms/com.google.android.location.settings.LocationSettingsCheckerActivity
		pm disable com.google.android.gms/.usagereporting.settings.UsageReportingActivity
		pm disable com.google.android.gms/.ads.adinfo.AdvertisingInfoContentProvider
		pm disable com.google.android.gms/com.google.android.location.reporting.service.ReportingContentProvider
		pm disable com.google.android.gms/com.google.android.location.internal.LocationContentProvider
		pm enable com.google.android.gms/.common.stats.net.contentprovider.NetworkUsageContentProvider
		pm disable com.google.android.gms/com.google.android.gms.ads.config.GServicesChangedReceiver
		pm disable com.google.android.gms/com.google.android.contextmanager.systemstate.SystemStateReceiver
		pm disable com.google.android.gms/.ads.jams.SystemEventReceiver
		pm disable com.google.android.gms/.ads.config.FlagsReceiver
		pm disable com.google.android.gms/.ads.social.DoritosReceiver
		pm disable com.google.android.gms/.analytics.AnalyticsReceiver
		pm disable com.google.android.gms/.analytics.internal.GServicesChangedReceiver
		pm disable com.google.android.gms/.common.analytics.CoreAnalyticsReceiver
		pm enable com.google.android.gms/.common.stats.GmsCoreStatsServiceLauncher
		pm disable com.google.android.gms/com.google.android.location.internal.AnalyticsSamplerReceiver
		pm disable com.google.android.gms/.checkin.CheckinService$ActiveReceiver
		pm disable com.google.android.gms/.checkin.CheckinService$ClockworkFallbackReceiver
		pm disable com.google.android.gms/.checkin.CheckinService$ImposeReceiver
		pm disable com.google.android.gms/.checkin.CheckinService$SecretCodeReceiver
		pm disable com.google.android.gms/.checkin.CheckinService$TriggerReceiver
		pm disable com.google.android.gms/.checkin.EventLogService$Receiver
		pm disable com.google.android.gms/com.google.android.location.reporting.service.ExternalChangeReceiver
		pm disable com.google.android.gms/com.google.android.location.reporting.service.GcmRegistrationReceiver
		pm disable com.google.android.gms/com.google.android.location.copresence.GcmRegistrationReceiver
		pm disable com.google.android.gms/com.google.android.location.copresence.GservicesBroadcastReceiver
		pm disable com.google.android.gms/com.google.android.location.internal.LocationProviderEnabler
		pm disable com.google.android.gms/com.google.android.location.internal.NlpNetworkProviderSettingsUpdateReceiver
		pm disable com.google.android.gms/com.google.android.location.network.ConfirmAlertActivity$LocationModeChangingReceiver
		pm disable com.google.android.gms/com.google.android.location.places.ImplicitSignalsReceiver
		pm disable com.google.android.gms/com.google.android.libraries.social.mediamonitor.MediaMonitor
		pm disable com.google.android.gms/.location.copresence.GcmBroadcastReceiver
		pm disable com.google.android.gms/.location.reporting.service.GcmBroadcastReceiver
		pm disable com.google.android.gms/.social.location.GservicesBroadcastReceiver
		pm disable com.google.android.gms/.update.SystemUpdateService$Receiver
		pm disable com.google.android.gms/.update.SystemUpdateService$OtaPolicyReceiver
		pm disable com.google.android.gms/.update.SystemUpdateService$SecretCodeReceiver
		pm disable com.google.android.gms/.update.SystemUpdateService$ActiveReceiver
		pm disable com.google.android.gms/com.google.android.contextmanager.service.ContextManagerService
		pm enable com.google.android.gms/.ads.AdRequestBrokerService
		pm disable com.google.android.gms/.ads.GservicesValueBrokerService
		pm disable com.google.android.gms/.ads.identifier.service.AdvertisingIdNotificationService
		pm enable com.google.android.gms/.ads.identifier.service.AdvertisingIdService
		pm disable com.google.android.gms/.ads.jams.NegotiationService
		pm disable com.google.android.gms/.ads.pan.PanService
		pm disable com.google.android.gms/.ads.social.GcmSchedulerWakeupService
		pm disable com.google.android.gms/.analytics.AnalyticsService
		pm disable com.google.android.gms/.analytics.internal.PlayLogReportingService
		pm disable com.google.android.gms/.analytics.service.AnalyticsService
		pm disable com.google.android.gms/.analytics.service.PlayLogMonitorIntervalService
		pm disable com.google.android.gms/.analytics.service.RefreshEnabledStateService
		pm disable com.google.android.gms/.auth.be.proximity.authorization.userpresence.UserPresenceService
		pm disable com.google.android.gms/.common.analytics.CoreAnalyticsIntentService
		pm enable com.google.android.gms/.common.stats.GmsCoreStatsService
		pm disable com.google.android.gms/.backup.BackupStatsService
		pm disable com.google.android.gms/.deviceconnection.service.DeviceConnectionAsyncService
		pm disable com.google.android.gms/.deviceconnection.service.DeviceConnectionServiceBroker
		pm disable com.google.android.gms/.wallet.service.analytics.AnalyticsIntentService
		pm enable com.google.android.gms/.checkin.CheckinService
		pm enable com.google.android.gms/.checkin.EventLogService
		pm disable com.google.android.gms/com.google.android.location.internal.AnalyticsUploadIntentService
		pm disable com.google.android.gms/com.google.android.location.reporting.service.DeleteHistoryService
		pm disable com.google.android.gms/com.google.android.location.reporting.service.DispatchingService
		pm disable com.google.android.gms/com.google.android.location.reporting.service.InternalPreferenceServiceDoNotUse
		pm disable com.google.android.gms/com.google.android.location.reporting.service.LocationHistoryInjectorService
		pm disable com.google.android.gms/com.google.android.location.reporting.service.ReportingAndroidService
		pm disable com.google.android.gms/com.google.android.location.reporting.service.ReportingSyncService
		pm disable com.google.android.gms/com.google.android.location.activity.HardwareArProviderService
		pm disable com.google.android.gms/com.google.android.location.fused.FusedLocationService
		pm disable com.google.android.gms/com.google.android.location.fused.service.FusedProviderService
		pm disable com.google.android.gms/com.google.android.location.geocode.GeocodeService
		pm disable com.google.android.gms/com.google.android.location.geofencer.service.GeofenceProviderService
		pm enable com.google.android.gms/com.google.android.location.internal.GoogleLocationManagerService
		pm disable com.google.android.gms/com.google.android.location.places.PlaylogService
		pm enable com.google.android.gms/com.google.android.location.places.service.GeoDataService
		pm enable com.google.android.gms/com.google.android.location.places.service.PlaceDetectionService
		pm disable com.google.android.gms/com.google.android.libraries.social.mediamonitor.MediaMonitorIntentService
		pm disable com.google.android.gms/.config.ConfigService
		pm enable com.google.android.gms/.stats.PlatformStatsCollectorService
		pm enable com.google.android.gms/.usagereporting.service.UsageReportingService
		pm enable com.google.android.gms/.update.SystemUpdateService
		pm enable com.google.android.gms/com.google.android.location.network.ConfirmAlertActivity
		pm enable com.google.android.gms/com.google.android.location.network.LocationProviderChangeReceiver
		pm enable com.google.android.gms/com.google.android.location.internal.server.GoogleLocationService
		pm enable com.google.android.gms/com.google.android.location.internal.PendingIntentCallbackService
		pm enable com.google.android.gms/com.google.android.location.network.NetworkLocationService
		pm enable com.google.android.gms/com.google.android.location.util.PreferenceService
		pm disable com.google.android.gsf/.update.SystemUpdateActivity
		pm disable com.google.android.gsf/.update.SystemUpdatePanoActivity
		pm disable com.google.android.gsf/com.google.android.gsf.checkin.CheckinService\$Receiver
		pm disable com.google.android.gsf/com.google.android.gsf.checkin.CheckinService\$SecretCodeReceiver
		pm disable com.google.android.gsf/com.google.android.gsf.checkin.CheckinService\$TriggerReceiver
		pm disable com.google.android.gsf/.checkin.EventLogService$Receiver
		pm disable com.google.android.gsf/.update.SystemUpdateService$Receiver
		pm disable com.google.android.gsf/.update.SystemUpdateService$SecretCodeReceiver
		pm disable com.google.android.gsf/.checkin.CheckinService
		pm disable com.google.android.gsf/.checkin.EventLogService
		pm disable com.google.android.gsf/.update.SystemUpdateService
	fi;
}

if [ "$stweaks_boot_control" == "yes" ]; then
	# Load Custom Modules
	# MODULES_LOAD;

	# Google Services battery drain fixer by BySezerSimsek
	GOOGLE_SERVICE_BD_FIXER;
fi;

(
	sleep 30;

	# get values from profile
	PROFILE=$(cat /data/.alucard/.active.profile);
	. /data/.alucard/"$PROFILE".profile;

	# apply selinux enforce setting
	if [ "$stweaks_boot_control" == "yes" ]; then
		if [ "$enforce" == "on" ]; then
			echo "1" > /sys/fs/selinux/enforce;
		else
			echo "0" > /sys/fs/selinux/enforce;
		fi;

		# Disable logcat by BySezerSimsek
		# http://forum.xda-developers.com/lg-g5/development/h850-genisys-rom-1-0-genisys-theme-1-0-t3421950
		if [ "$disablelogcat" == "on" ]; then
			setprop logcat.live disable
			$BB rm -f /dev/log/main
			setprop debugtool.anrhistory 0
			setprop profiler.debugmonitor false
			setprop profiler.launch false
			setprop profiler.hung.dumpdobugreport false
			setprop persist.android.strictmode 0
		fi;

		# Apply cpu governors and hotplugs settings
		$BB sh /sbin/ext/cortexbrain-tune.sh apply_cpu update > /dev/null;

		# Apply sched settings
		$BB sh /sbin/ext/cortexbrain-tune.sh apply_sched update > /dev/null;
	fi;

	# disable lge triton service
	if [ -e /system/bin/triton ]; then
		/system/bin/stop triton
	fi;

	# script finish here, so let me know when
	TIME_NOW=$(date)
	echo "$TIME_NOW" > /data/boot_log_alu

	$BB mount -o remount,ro /system;
)&

# Stop LG logging to /data/logger/$FILE we dont need that. draning power.
setprop persist.service.events.enable 0
setprop persist.service.main.enable 0
setprop persist.service.power.enable 0
setprop persist.service.radio.enable 0
setprop persist.service.system.enable 0
