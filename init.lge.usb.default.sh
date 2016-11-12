#!/system/bin/sh

target_operator=`getprop ro.build.target_operator`
ui_version=`getprop ro.lge.lguiversion`
case "$target_operator" in
    "ATT")
        default="charge_only"
        ;;
    "TRF")
        default="mtp"
        ;;
    "VZW")
        if [ -f "/system/usbautorun.iso" ];
        then
            if [ -f "/sys/class/android_usb/android0/f_cdrom_storage/lun/cdrom_usbmode" ]; then
                echo 0 > /sys/class/android_usb/android0/f_cdrom_storage/lun/cdrom_usbmode
            fi
            default="charge_only"
        else
            default="mtp"
        fi
        ;;
    *)
        if [ "${ui_version//./}" -ge "50" ];
        then
            default="charge_only"
        else
            default="mtp"
        fi
    ;;
esac

usb_config=`getprop persist.sys.usb.config`
case "$usb_config" in
    "boot") #factory status, select default
        setprop persist.sys.usb.config $default
    ;;
    "boot,adb") #factory status, select default
        setprop persist.sys.usb.config ${default},adb
    ;;
    *) ;; #USB persist config exists, do nothing
esac
