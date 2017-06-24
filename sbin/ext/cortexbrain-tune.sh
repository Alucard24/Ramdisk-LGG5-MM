#!/sbin/busybox sh

#Credits:
# Zacharias.maladroit
# Voku1987
# Collin_ph@xda
# Dorimanx@xda
# Gokhanmoral@xda
# Johnbeetee
# Alucard_24@xda

# TAKE NOTE THAT LINES PRECEDED BY A "#" IS COMMENTED OUT.
#
# This script must be activated after init start =< 25sec or parameters from /sys/* will not be loaded.

BB=/sbin/busybox

# change mode for /tmp/
ROOTFS_MOUNT=$(mount | grep rootfs | cut -c26-27 | grep -c rw)
if [ "$ROOTFS_MOUNT" -eq "0" ]; then
	mount -o remount,rw /;
fi;
chmod -R 777 /tmp/;

# ==============================================================
# GLOBAL VARIABLES || without "local" also a variable in a function is global
# ==============================================================

FILE_NAME=$0;
# (since we don't have the recovery source code I can't change the ".alucard" dir, so just leave it there for history)
DATA_DIR=/data/.alucard;
USB_POWER=0;

# ==============================================================
# INITIATE
# ==============================================================

# For CHARGER CHECK.
echo "1" > /data/alu_cortex_sleep;

# get values from profile
PROFILE=$(cat $DATA_DIR/.active.profile);
. "$DATA_DIR"/"$PROFILE".profile;

# ==============================================================
# I/O-TWEAKS
# ==============================================================
IO_TWEAKS()
{
	if [ "$cortexbrain_io" == "on" ]; then

		local i="";

		local MMC=$(find /sys/block/mmcblk0*);
		for i in $MMC; do
			echo "$internal_iosched" > "$i"/queue/scheduler;
			echo "0" > "$i"/queue/rotational; # default: 0
			echo "0" > "$i"/queue/iostats; # default: 1
			echo "2" > "$i"/queue/nomerges; # default: 0
		done;

		# This controls how many requests may be allocated
		# in the block layer for read or write requests.
		# Note that the total allocated number may be twice
		# this amount, since it applies only to reads or writes
		# (not the accumulated sum).
		echo "128" > /sys/block/mmcblk0/queue/nr_requests; # default: 128

		# our storage is 16/32GB, best is 1024KB readahead
		# see https://github.com/Keff/samsung-kernel-msm7x30/commit/a53f8445ff8d947bd11a214ab42340cc6d998600#L1R627
		echo "$intsd_read_ahead_kb" > /sys/block/mmcblk0/queue/read_ahead_kb; # default: 512
		echo "$intsd_read_ahead_kb" > /sys/block/mmcblk0/bdi/read_ahead_kb; # default: 512

		echo "45" > /proc/sys/fs/lease-break-time; # default: 45

		log -p i -t "$FILE_NAME" "*** IO_TWEAKS ***: enabled";
	else
		return 0;
	fi;
}
IO_TWEAKS;

# ==============================================================
# KERNEL-TWEAKS
# ==============================================================
KERNEL_TWEAKS()
{
	if [ "$cortexbrain_kernel_tweaks" == "on" ]; then
		echo "0" > /proc/sys/vm/oom_kill_allocating_task; # default: 0
		echo "0" > /proc/sys/vm/panic_on_oom; # default: 0
		echo "5" > /proc/sys/kernel/panic; # default: 5
		echo "0" > /proc/sys/kernel/panic_on_oops; # default: 1

		log -p i -t "$FILE_NAME" "*** KERNEL_TWEAKS ***: enabled";
	else
		echo "kernel_tweaks disabled";
	fi;
}
KERNEL_TWEAKS;

# ==============================================================
# MEMORY-TWEAKS
# ==============================================================
MEMORY_TWEAKS()
{
	if [ "$cortexbrain_memory" == "on" ]; then
		echo "$dirty_background_ratio" > /proc/sys/vm/dirty_background_ratio; # default: 5
		echo "$dirty_ratio" > /proc/sys/vm/dirty_ratio; # default: 20
		echo "4" > /proc/sys/vm/min_free_order_shift; # default: 4
		echo "1" > /proc/sys/vm/overcommit_memory; # default: 1
		echo "50" > /proc/sys/vm/overcommit_ratio; # default: 50
		echo "3" > /proc/sys/vm/page-cluster; # default: 3
		# mem calc here in pages. so 16384 x 4 = 64MB reserved for fast access by kernel and VM
		echo "32768" > /proc/sys/vm/mmap_min_addr; #default: 32768

		log -p i -t "$FILE_NAME" "*** MEMORY_TWEAKS ***: enabled";
	else
		return 0;
	fi;
}
MEMORY_TWEAKS;

# ==============================================================
# CPU-TWEAKS
# ==============================================================

CPU_GOV_TWEAKS()
{
	local state="$1";

	if [ "$cortexbrain_cpu" == "on" ]; then		
		# tune-settings
		if [ "$state" == "tune" ]; then
			SYSTEM_GOVERNOR_01=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor);
			SYSTEM_GOVERNOR_23=$(cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor);

			# Force unmask hotplugged cpus
			echo 1 > /sys/module/msm_thermal/core_control/force_unmask;
			# disable thermal bcl hotplug to switch governor;
			echo 0 > /sys/module/msm_thermal/core_control/enabled;
			echo -n disable > /sys/devices/soc/soc:qcom,bcl/mode;
			bcl_hotplug_mask=`cat /sys/devices/soc/soc:qcom,bcl/hotplug_mask`;
			echo 0 > /sys/devices/soc/soc:qcom,bcl/hotplug_mask;
			bcl_soc_hotplug_mask=`cat /sys/devices/soc/soc:qcom,bcl/hotplug_soc_mask`;
			echo 0 > /sys/devices/soc/soc:qcom,bcl/hotplug_soc_mask;
			echo -n enable > /sys/devices/soc/soc:qcom,bcl/mode;

			sampling_rate_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/sampling_rate";
			if [ ! -e $sampling_rate_tmp_01 ]; then
				sampling_rate_tmp_01="/dev/null";
			fi;
			sampling_rate_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/sampling_rate";
			if [ ! -e $sampling_rate_tmp_23 ]; then
				sampling_rate_tmp_23="/dev/null";
			fi;

			timer_rate_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/timer_rate";
			if [ ! -e $timer_rate_tmp_01 ]; then
				timer_rate_tmp_01="/dev/null";
			fi;
			timer_rate_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/timer_rate";
			if [ ! -e $timer_rate_tmp_23 ]; then
				timer_rate_tmp_23="/dev/null";
			fi;

			up_rate_limit_us_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/up_rate_limit_us";
			if [ ! -e $up_rate_limit_us_tmp_01 ]; then
				up_rate_limit_us_tmp_01="/dev/null";
			fi;
			up_rate_limit_us_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/up_rate_limit_us";
			if [ ! -e $up_rate_limit_us_tmp_23 ]; then
				up_rate_limit_us_tmp_23="/dev/null";
			fi;

			down_rate_limit_us_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/down_rate_limit_us";
			if [ ! -e $down_rate_limit_us_tmp_01 ]; then
				down_rate_limit_us_tmp_01="/dev/null";
			fi;
			down_rate_limit_us_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/down_rate_limit_us";
			if [ ! -e $down_rate_limit_us_tmp_23 ]; then
				down_rate_limit_us_tmp_23="/dev/null";
			fi;

			up_threshold_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/up_threshold";
			if [ ! -e $up_threshold_tmp_01 ]; then
				up_threshold_tmp_01="/dev/null";
			fi;
			up_threshold_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/up_threshold";
			if [ ! -e $up_threshold_tmp_23 ]; then
				up_threshold_tmp_23="/dev/null";
			fi;

			down_threshold_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/down_threshold";
			if [ ! -e $down_threshold_tmp_01 ]; then
				down_threshold_tmp_01="/dev/null";
			fi;
			down_threshold_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/down_threshold";
			if [ ! -e $down_threshold_tmp_23 ]; then
				down_threshold_tmp_23="/dev/null";
			fi;

			sampling_down_factor_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/sampling_down_factor";
			if [ ! -e $sampling_down_factor_tmp_01 ]; then
				sampling_down_factor_tmp_01="/dev/null";
			fi;
			sampling_down_factor_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/sampling_down_factor";
			if [ ! -e $sampling_down_factor_tmp_23 ]; then
				sampling_down_factor_tmp_23="/dev/null";
			fi;

			freq_for_responsiveness_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_for_responsiveness";
			if [ ! -e $freq_for_responsiveness_tmp_01 ]; then
				freq_for_responsiveness_tmp_01="/dev/null";
			fi;
			freq_for_responsiveness_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_for_responsiveness";
			if [ ! -e $freq_for_responsiveness_tmp_23 ]; then
				freq_for_responsiveness_tmp_23="/dev/null";
			fi;

			freq_responsiveness_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_responsiveness";
			if [ ! -e $freq_responsiveness_tmp_01 ]; then
				freq_responsiveness_tmp_01="/dev/null";
			fi;
			freq_responsiveness_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_responsiveness";
			if [ ! -e $freq_responsiveness_tmp_23 ]; then
				freq_responsiveness_tmp_23="/dev/null";
			fi;

			freq_for_responsiveness_max_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_for_responsiveness_max";
			if [ ! -e $freq_for_responsiveness_max_tmp_01 ]; then
				freq_for_responsiveness_max_tmp_01="/dev/null";
			fi;
			freq_for_responsiveness_max_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_for_responsiveness_max";
			if [ ! -e $freq_for_responsiveness_max_tmp_23 ]; then
				freq_for_responsiveness_max_tmp_23="/dev/null";
			fi;

			freq_responsiveness_max_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_responsiveness_max";
			if [ ! -e $freq_responsiveness_max_tmp_01 ]; then
				freq_responsiveness_max_tmp_01="/dev/null";
			fi;
			freq_responsiveness_max_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_responsiveness_max";
			if [ ! -e $freq_responsiveness_max_tmp_23 ]; then
				freq_responsiveness_max_tmp_23="/dev/null";
			fi;

			freq_responsiveness_jump_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_responsiveness_jump";
			if [ ! -e $freq_responsiveness_jump_tmp_01 ]; then
				freq_responsiveness_jump_tmp_01="/dev/null";
			fi;
			freq_responsiveness_jump_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_responsiveness_jump";
			if [ ! -e $freq_responsiveness_jump_tmp_23 ]; then
				freq_responsiveness_jump_tmp_23="/dev/null";
			fi;

			eval_busy_for_freq_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/eval_busy_for_freq";
			if [ ! -e $eval_busy_for_freq_tmp_01 ]; then
				eval_busy_for_freq_tmp_01="/dev/null";
			fi;
			eval_busy_for_freq_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/eval_busy_for_freq";
			if [ ! -e $eval_busy_for_freq_tmp_23 ]; then
				eval_busy_for_freq_tmp_23="/dev/null";
			fi;

			iowait_boost_enable_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/iowait_boost_enable";
			if [ ! -e $iowait_boost_enable_tmp_01 ]; then
				iowait_boost_enable_tmp_01="/dev/null";
			fi;
			iowait_boost_enable_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/iowait_boost_enable";
			if [ ! -e $iowait_boost_enable_tmp_23 ]; then
				iowait_boost_enable_tmp_23="/dev/null";
			fi;

			freq_step_at_min_freq_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_step_at_min_freq";
			if [ ! -e $freq_step_at_min_freq_tmp_01 ]; then
				freq_step_at_min_freq_tmp_01="/dev/null";
			fi;
			freq_step_at_min_freq_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_step_at_min_freq";
			if [ ! -e $freq_step_at_min_freq_tmp_23 ]; then
				freq_step_at_min_freq_tmp_23="/dev/null";
			fi;

			freq_step_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_step";
			if [ ! -e $freq_step_tmp_01 ]; then
				freq_step_tmp_01="/dev/null";
			fi;
			freq_step_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_step";
			if [ ! -e $freq_step_tmp_23 ]; then
				freq_step_tmp_23="/dev/null";
			fi;

			freq_step_dec_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_step_dec";
			if [ ! -e $freq_step_dec_tmp_01 ]; then
				freq_step_dec_tmp_01="/dev/null";
			fi;
			freq_step_dec_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_step_dec";
			if [ ! -e $freq_step_dec_tmp_23 ]; then
				freq_step_dec_tmp_23="/dev/null";
			fi;

			freq_step_dec_at_max_freq_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_step_dec_at_max_freq";
			if [ ! -e $freq_step_dec_at_max_freq_tmp_01 ]; then
				freq_step_dec_at_max_freq_tmp_01="/dev/null";
			fi;
			freq_step_dec_at_max_freq_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_step_dec_at_max_freq";
			if [ ! -e $freq_step_dec_at_max_freq_tmp_23 ]; then
				freq_step_dec_at_max_freq_tmp_23="/dev/null";
			fi;

			freq_up_brake_at_min_freq_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_up_brake_at_min_freq";
			if [ ! -e $freq_up_brake_at_min_freq_tmp_01 ]; then
				freq_up_brake_at_min_freq_tmp_01="/dev/null";
			fi;
			freq_up_brake_at_min_freq_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_up_brake_at_min_freq";
			if [ ! -e $freq_up_brake_at_min_freq_tmp_23 ]; then
				freq_up_brake_at_min_freq_tmp_23="/dev/null";
			fi;

			freq_up_brake_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/freq_up_brake";
			if [ ! -e $freq_up_brake_tmp_01 ]; then
				freq_up_brake_tmp_01="/dev/null";
			fi;
			freq_up_brake_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/freq_up_brake";
			if [ ! -e $freq_up_brake_tmp_23 ]; then
				freq_up_brake_tmp_23="/dev/null";
			fi;

			pump_inc_step_at_min_freq_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/pump_inc_step_at_min_freq";
			if [ ! -e $pump_inc_step_at_min_freq_tmp_01 ]; then
				pump_inc_step_at_min_freq_tmp_01="/dev/null";
			fi;
			pump_inc_step_at_min_freq_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/pump_inc_step_at_min_freq";
			if [ ! -e $pump_inc_step_at_min_freq_tmp_23 ]; then
				pump_inc_step_at_min_freq_tmp_23="/dev/null";
			fi;

			pump_inc_step_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/pump_inc_step";
			if [ ! -e $pump_inc_step_tmp_01 ]; then
				pump_inc_step_1_tmp_01="/dev/null";
			fi;
			pump_inc_step_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/pump_inc_step";
			if [ ! -e $pump_inc_step_tmp_23 ]; then
				pump_inc_step_tmp_23="/dev/null";
			fi;

			pump_dec_step_at_min_freq_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/pump_dec_step_at_min_freq";
			if [ ! -e $pump_dec_step_at_min_freq_tmp_01 ]; then
				pump_dec_step_at_min_freq_tmp_01="/dev/null";
			fi;
			pump_dec_step_at_min_freq_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/pump_dec_step_at_min_freq";
			if [ ! -e $pump_dec_step_at_min_freq_tmp_23 ]; then
				pump_dec_step_at_min_freq_tmp_23="/dev/null";
			fi;

			pump_dec_step_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/pump_dec_step";
			if [ ! -e $pump_dec_step_tmp_01 ]; then
				pump_dec_step_tmp_01="/dev/null";
			fi;
			pump_dec_step_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/pump_dec_step";
			if [ ! -e $pump_dec_step_tmp_23 ]; then
				pump_dec_step_tmp_23="/dev/null";
			fi;

			cpus_up_rate_at_max_freq_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/cpus_up_rate_at_max_freq";
			if [ ! -e $cpus_up_rate_at_max_freq_tmp_01 ]; then
				cpus_up_rate_at_max_freq_tmp_01="/dev/null";
			fi;
			cpus_up_rate_at_max_freq_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/cpus_up_rate_at_max_freq";
			if [ ! -e $cpus_up_rate_at_max_freq_tmp_23 ]; then
				cpus_up_rate_at_max_freq_tmp_23="/dev/null";
			fi;

			cpus_up_rate_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/cpus_up_rate";
			if [ ! -e $cpus_up_rate_tmp_01 ]; then
				cpus_up_rate_tmp_01="/dev/null";
			fi;
			cpus_up_rate_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/cpus_up_rate";
			if [ ! -e $cpus_up_rate_tmp_23 ]; then
				cpus_up_rate_tmp_23="/dev/null";
			fi;

			cpus_down_rate_at_max_freq_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/cpus_down_rate_at_max_freq";
			if [ ! -e $cpus_down_rate_at_max_freq_tmp_01 ]; then
				cpus_down_rate_at_max_freq_tmp_01="/dev/null";
			fi;
			cpus_down_rate_at_max_freq_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/cpus_down_rate_at_max_freq";
			if [ ! -e $cpus_down_rate_at_max_freq_tmp_23 ]; then
				cpus_down_rate_at_max_freq_tmp_23="/dev/null";
			fi;

			cpus_down_rate_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/cpus_down_rate";
			if [ ! -e $cpus_down_rate_tmp_01 ]; then
				cpus_down_rate_tmp_01="/dev/null";
			fi;
			cpus_down_rate_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/cpus_down_rate";
			if [ ! -e $cpus_down_rate_tmp_23 ]; then
				cpus_down_rate_tmp_23="/dev/null";
			fi;

			load_mode_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/load_mode";
			if [ ! -e $load_mode_tmp_01 ]; then
				load_mode_tmp_01="/dev/null";
			fi;
			load_mode_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/load_mode";
			if [ ! -e $load_mode_tmp_23 ]; then
				load_mode_tmp_23="/dev/null";
			fi;

			echo "$sampling_rate_01" > $sampling_rate_tmp_01;
			echo "$sampling_rate_23" > $sampling_rate_tmp_23;
			echo "$timer_rate_01" > $timer_rate_tmp_01;
			echo "$timer_rate_23" > $timer_rate_tmp_23;
			echo "$up_rate_limit_us_01" > $up_rate_limit_us_tmp_01;
			echo "$up_rate_limit_us_23" > $up_rate_limit_us_tmp_23;
			echo "$down_rate_limit_us_01" > $down_rate_limit_us_tmp_01;
			echo "$down_rate_limit_us_23" > $down_rate_limit_us_tmp_23;
			echo "$up_threshold_01" > $up_threshold_tmp_01;
			echo "$up_threshold_23" > $up_threshold_tmp_23;
			echo "$down_threshold_01" > $down_threshold_tmp_01;
			echo "$down_threshold_23" > $down_threshold_tmp_23;
			echo "$sampling_down_factor_01" > $sampling_down_factor_tmp_01;
			echo "$sampling_down_factor_23" > $sampling_down_factor_tmp_23;
			echo "$freq_step_at_min_freq_01" > $freq_step_at_min_freq_tmp_01;
			echo "$freq_step_at_min_freq_23" > $freq_step_at_min_freq_tmp_23;
			echo "$freq_step_01" > $freq_step_tmp_01;
			echo "$freq_step_23" > $freq_step_tmp_23;
			echo "$freq_step_dec_01" > $freq_step_dec_tmp_01;
			echo "$freq_step_dec_23" > $freq_step_dec_tmp_23;
			echo "$freq_step_dec_at_max_freq_01" > $freq_step_dec_at_max_freq_tmp_01;
			echo "$freq_step_dec_at_max_freq_23" > $freq_step_dec_at_max_freq_tmp_23;
			echo "$freq_for_responsiveness_01" > $freq_for_responsiveness_tmp_01;
			echo "$freq_for_responsiveness_23" > $freq_for_responsiveness_tmp_23;
			echo "$freq_responsiveness_01" > $freq_responsiveness_tmp_01;
			echo "$freq_responsiveness_23" > $freq_responsiveness_tmp_23;
			echo "$freq_for_responsiveness_max_01" > $freq_for_responsiveness_max_tmp_01;
			echo "$freq_for_responsiveness_max_23" > $freq_for_responsiveness_max_tmp_23;
			echo "$freq_responsiveness_max_01" > $freq_responsiveness_max_tmp_01;
			echo "$freq_responsiveness_max_23" > $freq_responsiveness_max_tmp_23;
			echo "$freq_responsiveness_jump_01" > $freq_responsiveness_jump_tmp_01;
			echo "$freq_responsiveness_jump_23" > $freq_responsiveness_jump_tmp_23;
			echo "$eval_busy_for_freq_01" > $eval_busy_for_freq_tmp_01;
			echo "$eval_busy_for_freq_23" > $eval_busy_for_freq_tmp_23;
			echo "$iowait_boost_enable_01" > $iowait_boost_enable_tmp_01;
			echo "$iowait_boost_enable_23" > $iowait_boost_enable_tmp_23;
			echo "$freq_up_brake_at_min_freq_01" > $freq_up_brake_at_min_freq_tmp_01;
			echo "$freq_up_brake_at_min_freq_23" > $freq_up_brake_at_min_freq_tmp_23;
			echo "$freq_up_brake_01" > $freq_up_brake_tmp_01;
			echo "$freq_up_brake_23" > $freq_up_brake_tmp_23;
			echo "$pump_inc_step_at_min_freq_01" > $pump_inc_step_at_min_freq_tmp_01;
			echo "$pump_inc_step_at_min_freq_23" > $pump_inc_step_at_min_freq_tmp_23;
			echo "$pump_inc_step_01" > $pump_inc_step_tmp_01;
			echo "$pump_inc_step_23" > $pump_inc_step_tmp_23;
			echo "$pump_dec_step_at_min_freq_01" > $pump_dec_step_at_min_freq_tmp_01;
			echo "$pump_dec_step_at_min_freq_23" > $pump_dec_step_at_min_freq_tmp_23;
			echo "$pump_dec_step_01" > $pump_dec_step_tmp_01;
			echo "$pump_dec_step_23" > $pump_dec_step_tmp_23;
			echo "$cpus_up_rate_at_max_freq_01" > $cpus_up_rate_at_max_freq_tmp_01;
			echo "$cpus_up_rate_at_max_freq_23" > $cpus_up_rate_at_max_freq_tmp_23;
			echo "$cpus_up_rate_01" > $cpus_up_rate_tmp_01;
			echo "$cpus_up_rate_23" > $cpus_up_rate_tmp_23;
			echo "$cpus_down_rate_at_max_freq_01" > $cpus_down_rate_at_max_freq_tmp_01;
			echo "$cpus_down_rate_at_max_freq_23" > $cpus_down_rate_at_max_freq_tmp_23;
			echo "$cpus_down_rate_01" > $cpus_down_rate_tmp_01;
			echo "$cpus_down_rate_23" > $cpus_down_rate_tmp_23;
			echo "$load_mode_01" > $load_mode_tmp_01;
			echo "$load_mode_23" > $load_mode_tmp_23;

			# Fix: set scaling_min_freq again
			echo "$scaling_min_freq_cpu01" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
			echo "$scaling_min_freq_cpu23" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq;

			# re-enable thermal and BCL hotplug;
			echo 1 > /sys/module/msm_thermal/core_control/enabled;
			echo -n disable > /sys/devices/soc/soc:qcom,bcl/mode;
			echo "$bcl_hotplug_mask" > /sys/devices/soc/soc:qcom,bcl/hotplug_mask;
			echo "$bcl_soc_hotplug_mask" > /sys/devices/soc/soc:qcom,bcl/hotplug_soc_mask;
			echo -n enable > /sys/devices/soc/soc:qcom,bcl/mode;
			# recover offlined_mask in thermal.
			echo 0 > /sys/module/msm_thermal/core_control/force_unmask;
		fi;

		log -p i -t "$FILE_NAME" "*** CPU_GOV_TWEAKS: $state ***: enabled";
	else
		return 0;
	fi;
}
# this needed for cpu tweaks apply from STweaks in real time
apply_cpu="$2";
if [ "$apply_cpu" == "update" ]; then
	CPU_GOV_TWEAKS "tune";
fi;

CPUCAP_GOV_TWEAKS()
{
	local state="$1";

	if [ "$cortexbrain_cpu" == "on" ]; then		
		# tune-settings
		if [ "$state" == "tune" ]; then
			SYSTEM_GOVERNOR_01=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor);
			SYSTEM_GOVERNOR_23=$(cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor);
			sep=":";

			up_target_capacity_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/up_target_capacity";
			if [ ! -e $up_target_capacity_tmp_01 ]; then
				up_target_capacity_tmp_01="/dev/null";
			fi;
			down_target_capacity_tmp_01="/sys/devices/system/cpu/cpu0/cpufreq/$SYSTEM_GOVERNOR_01/down_target_capacity";
			if [ ! -e $down_target_capacity_tmp_01 ]; then
				down_target_capacity_tmp_01="/dev/null";
			fi;
			up_target_capacity_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/up_target_capacity";
			if [ ! -e $up_target_capacity_tmp_23 ]; then
				up_target_capacity_tmp_23="/dev/null";
			fi;
			down_target_capacity_tmp_23="/sys/devices/system/cpu/cpu2/cpufreq/$SYSTEM_GOVERNOR_23/down_target_capacity";
			if [ ! -e $down_target_capacity_tmp_23 ]; then
				down_target_capacity_tmp_23="/dev/null";
			fi;

			little_up_target_capacity="$little_up_target_capacity_01$sep$little_up_target_capacity_02$sep$little_up_target_capacity_03$sep$little_up_target_capacity_04$sep$little_up_target_capacity_05$sep$little_up_target_capacity_06$sep$little_up_target_capacity_07$sep$little_up_target_capacity_08$sep$little_up_target_capacity_09$sep$little_up_target_capacity_10$sep$little_up_target_capacity_11$sep$little_up_target_capacity_12$sep$little_up_target_capacity_13$sep$little_up_target_capacity_14$sep$little_up_target_capacity_15$sep$little_up_target_capacity_16";
			echo "$little_up_target_capacity" > $up_target_capacity_tmp_01;

			little_down_target_capacity="$little_down_target_capacity_01$sep$little_down_target_capacity_02$sep$little_down_target_capacity_03$sep$little_down_target_capacity_04$sep$little_down_target_capacity_05$sep$little_down_target_capacity_06$sep$little_down_target_capacity_07$sep$little_down_target_capacity_08$sep$little_down_target_capacity_09$sep$little_down_target_capacity_10$sep$little_down_target_capacity_11$sep$little_down_target_capacity_12$sep$little_down_target_capacity_13$sep$little_down_target_capacity_14$sep$little_down_target_capacity_15$sep$little_down_target_capacity_16";
			echo "$little_down_target_capacity" > $down_target_capacity_tmp_01;

			big_up_target_capacity="$big_up_target_capacity_01$sep$big_up_target_capacity_02$sep$big_up_target_capacity_03$sep$big_up_target_capacity_04$sep$big_up_target_capacity_05$sep$big_up_target_capacity_06$sep$big_up_target_capacity_07$sep$big_up_target_capacity_08$sep$big_up_target_capacity_09$sep$big_up_target_capacity_10$sep$big_up_target_capacity_11$sep$big_up_target_capacity_12$sep$big_up_target_capacity_13$sep$big_up_target_capacity_14$sep$big_up_target_capacity_15$sep$big_up_target_capacity_16$sep$big_up_target_capacity_17$sep$big_up_target_capacity_18$sep$big_up_target_capacity_19$sep$big_up_target_capacity_20$sep$big_up_target_capacity_21$sep$big_up_target_capacity_22$sep$big_up_target_capacity_23$sep$big_up_target_capacity_24$sep$big_up_target_capacity_25";
			echo "$big_up_target_capacity" > $up_target_capacity_tmp_23;

			big_down_target_capacity="$big_down_target_capacity_01$sep$big_down_target_capacity_02$sep$big_down_target_capacity_03$sep$big_down_target_capacity_04$sep$big_down_target_capacity_05$sep$big_down_target_capacity_06$sep$big_down_target_capacity_07$sep$big_down_target_capacity_08$sep$big_down_target_capacity_09$sep$big_down_target_capacity_10$sep$big_down_target_capacity_11$sep$big_down_target_capacity_12$sep$big_down_target_capacity_13$sep$big_down_target_capacity_14$sep$big_down_target_capacity_15$sep$big_down_target_capacity_16$sep$big_down_target_capacity_17$sep$big_down_target_capacity_18$sep$big_down_target_capacity_19$sep$big_down_target_capacity_20$sep$big_down_target_capacity_21$sep$big_down_target_capacity_22$sep$big_down_target_capacity_23$sep$big_down_target_capacity_24$sep$big_down_target_capacity_25";
			echo "$big_down_target_capacity" > $down_target_capacity_tmp_23;
		fi;

		log -p i -t "$FILE_NAME" "*** CPUCAP_GOV_TWEAKS: $state ***: enabled";
	else
		return 0;
	fi;
}
# this needed for cpu tweaks apply from STweaks in real time
apply_cpu_cap="$2";
if [ "$apply_cpu_cap" == "update" ]; then
	CPUCAP_GOV_TWEAKS "tune";
fi;

# ==============================================================
# TWEAKS: if Screen-ON
# ==============================================================
AWAKE_MODE()
{
	# not on call, check if was powerd by USB on sleep, or didnt sleep at all
	if [ "$USB_POWER" -eq "0" ]; then
		echo "0" > /data/alu_cortex_sleep;
	else
		# Was powered by USB, and half sleep
		USB_POWER=0;

		log -p i -t "$FILE_NAME" "*** USB_POWER_WAKE: done ***";
	fi;
	# Didn't sleep, and was not powered by USB
	#if [ "$auto_oom" == "on" ]; then
	#	sleep 1;
	#	$BB sh /res/uci.sh oom_config_screen_on $oom_config_screen_on;
	#fi;
}

# ==============================================================
# TWEAKS: if Screen-OFF
# ==============================================================
SLEEP_MODE()
{
	# we only read the config when the screen turns off ...
	PROFILE=$(cat "$DATA_DIR"/.active.profile);
	. "$DATA_DIR"/"$PROFILE".profile;

	CHARGER_STATUS=$(cat /sys/class/power_supply/battery/status);

	# check if we powered by USB, if not sleep
	if [ "$CHARGER_STATUS" == "Discharging" ]; then
		echo "1" > /data/alu_cortex_sleep;
		log -p i -t "$FILE_NAME" "*** SLEEP mode ***";
	else
		# Powered by USB
		USB_POWER=1;
		echo "0" > /data/alu_cortex_sleep;
		log -p i -t "$FILE_NAME" "*** SLEEP mode: USB CABLE CONNECTED! No real sleep mode! ***";
	fi;
}

# ==============================================================
# Background process to check screen state
# ==============================================================

# Dynamic value do not change/delete
cortexbrain_background_process=1;

if [ "$cortexbrain_background_process" -eq "1" ] && [ "$(pgrep -f "/sbin/ext/cortexbrain-tune.sh" | wc -l)" -eq "2" ]; then
	(while true; do
		while [ "$(cat /sys/power/autosleep)" != "off" ]; do
			sleep "3";
		done;
		# AWAKE State. all system ON
		AWAKE_MODE;

		while [ "$(cat /sys/power/autosleep)" != "mem" ]; do
			sleep "3";
		done;
		# SLEEP state. All system to power save
		SLEEP_MODE;
	done &);
else
	if [ "$cortexbrain_background_process" -eq "0" ]; then
		echo "Cortex background disabled!"
	else
		echo "Cortex background process already running!";
	fi;
fi;
