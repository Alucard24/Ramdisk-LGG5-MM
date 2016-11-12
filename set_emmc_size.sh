#!/system/bin/sh

if test -a "/dev/block/platform/soc/624000.ufshc"; then
    #for ufs
    emmc_size="`cat /sys/block/sda/size`"
else
    #for emmc
    emmc_size="`cat /sys/block/mmcblk0/size`"
fi

echo $emmc_size

TARGET_8GB_MODEL=16777216   #(8*1024*1024*1024)/512
TARGET_16GB_MODEL=33554432  #(16*1024*1024*1024)/512
TARGET_32GB_MODEL=67108864  #(32*1024*1024*1024)/512
TARGET_64GB_MODEL=134217728 #(64*1024*1024*1024)/512


if [ $emmc_size -lt $TARGET_8GB_MODEL ]; then
    setprop persist.sys.emmc_size 8GB
    echo 8G model
elif [ $emmc_size -lt $TARGET_16GB_MODEL ]; then
    setprop persist.sys.emmc_size 16GB
    echo 16G model
elif [ $emmc_size -lt $TARGET_32GB_MODEL ]; then
    setprop persist.sys.emmc_size 32GB
    echo 32G model
elif [ $emmc_size -lt $TARGET_64GB_MODEL ]; then
    setprop persist.sys.emmc_size 64GB
    echo 64G model
else
    setprop persist.sys.emmc_size 128GB
    echo 128G model
fi
