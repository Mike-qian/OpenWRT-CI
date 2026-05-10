#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ Date Compiled-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	#其他调整
	#echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y" >> ./.config

	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi


# 1. 禁用核心硬件支持
sed -i 's/CONFIG_USB_SUPPORT=y/# CONFIG_USB_SUPPORT is not set/' .config
sed -i 's/CONFIG_EMMC_SUPPORT=y/# CONFIG_EMMC_SUPPORT is not set/' .config

# 2. 禁用默认包含的 USB 控制器 + 自动挂载
sed -i 's/CONFIG_DEFAULT_automount=y/# CONFIG_DEFAULT_automount is not set/' .config
sed -i 's/CONFIG_DEFAULT_kmod-usb3=y/# CONFIG_DEFAULT_kmod-usb3 is not set/' .config
sed -i 's/CONFIG_DEFAULT_kmod-usb-dwc3=y/# CONFIG_DEFAULT_kmod-usb-dwc3 is not set/' .config
sed -i 's/CONFIG_DEFAULT_kmod-usb-dwc3-qcom=y/# CONFIG_DEFAULT_kmod-usb-dwc3-qcom is not set/' .config

# 3. 禁用 USB 物理层 + 控制器
sed -i 's/CONFIG_PACKAGE_kmod-usb-dwc3=y/# CONFIG_PACKAGE_kmod-usb-dwc3 is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-dwc3-qcom=y/# CONFIG_PACKAGE_kmod-usb-dwc3-qcom is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-phy-qcom-qusb2=y/# CONFIG_PACKAGE_kmod-usb-phy-qcom-qusb2 is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-phy-qcom-ss=y/# CONFIG_PACKAGE_kmod-usb-phy-qcom-ss is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-roles=y/# CONFIG_PACKAGE_kmod-usb-roles is not set/' .config

# 4. 禁用 USB 核心内核模块
sed -i 's/CONFIG_PACKAGE_kmod-usb-common=y/# CONFIG_PACKAGE_kmod-usb-common is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-core=y/# CONFIG_PACKAGE_kmod-usb-core is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-core=m/# CONFIG_PACKAGE_kmod-usb-core is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-storage=y/# CONFIG_PACKAGE_kmod-usb-storage is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-storage-extras=y/# CONFIG_PACKAGE_kmod-usb-storage-extras is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-storage-uas=y/# CONFIG_PACKAGE_kmod-usb-storage-uas is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb2=y/# CONFIG_PACKAGE_kmod-usb2 is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-ohci=y/# CONFIG_PACKAGE_kmod-usb-ohci is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-uhci=y/# CONFIG_PACKAGE_kmod-usb-uhci is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-ledtrig-usbport=y/# CONFIG_PACKAGE_kmod-usb-ledtrig-usbport is not set/' .config

# 5. 禁用 USB 扩展功能（modem/打印机/网络/串口）
sed -i 's/CONFIG_PACKAGE_usb-modeswitch=y/# CONFIG_PACKAGE_usb-modeswitch is not set/' .config
sed -i 's/CONFIG_PACKAGE_usb-printer=y/# CONFIG_PACKAGE_usb-printer is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-acm=y/# CONFIG_PACKAGE_kmod-usb-acm is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-serial=y/# CONFIG_PACKAGE_kmod-usb-serial is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-usb-net=y/# CONFIG_PACKAGE_kmod-usb-net is not set/' .config

# 6. 禁用分区与磁盘管理工具
sed -i 's/CONFIG_PACKAGE_blkid=y/# CONFIG_PACKAGE_blkid is not set/' .config
sed -i 's/CONFIG_PACKAGE_fdisk=y/# CONFIG_PACKAGE_fdisk is not set/' .config
sed -i 's/CONFIG_PACKAGE_parted=y/# CONFIG_PACKAGE_parted is not set/' .config
sed -i 's/CONFIG_PACKAGE_sfdisk=y/# CONFIG_PACKAGE_sfdisk is not set/' .config
sed -i 's/CONFIG_PACKAGE_cgdisk=y/# CONFIG_PACKAGE_cgdisk is not set/' .config
sed -i 's/CONFIG_PACKAGE_gdisk=y/# CONFIG_PACKAGE_gdisk is not set/' .config
sed -i 's/CONFIG_PACKAGE_cfdisk=y/# CONFIG_PACKAGE_cfdisk is not set/' .config
sed -i 's/CONFIG_PACKAGE_lsblk=y/# CONFIG_PACKAGE_lsblk is not set/' .config
sed -i 's/CONFIG_PACKAGE_hdparm=y/# CONFIG_PACKAGE_hdparm is not set/' .config

# 7. 禁用文件系统工具与挂载服务
sed -i 's/CONFIG_DEFAULT_e2fsprogs=y/# CONFIG_DEFAULT_e2fsprogs is not set/' .config
sed -i 's/CONFIG_DEFAULT_f2fs-tools=y/# CONFIG_DEFAULT_f2fs-tools is not set/' .config
sed -i 's/CONFIG_PACKAGE_block-mount=y/# CONFIG_PACKAGE_block-mount is not set/' .config
sed -i 's/CONFIG_PACKAGE_dosfstools=y/# CONFIG_PACKAGE_dosfstools is not set/' .config
sed -i 's/CONFIG_PACKAGE_e2fsprogs=y/# CONFIG_PACKAGE_e2fsprogs is not set/' .config
sed -i 's/CONFIG_PACKAGE_f2fs-tools=y/# CONFIG_PACKAGE_f2fs-tools is not set/' .config
sed -i 's/CONFIG_PACKAGE_mkf2fs=y/# CONFIG_PACKAGE_mkf2fs is not set/' .config
sed -i 's/CONFIG_PACKAGE_ntfs-3g=y/# CONFIG_PACKAGE_ntfs-3g is not set/' .config

# 8. 禁用所有磁盘文件系统内核模块
sed -i 's/CONFIG_PACKAGE_kmod-fs-ext4=y/# CONFIG_PACKAGE_kmod-fs-ext4 is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-fs-f2fs=y/# CONFIG_PACKAGE_kmod-fs-f2fs is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-fs-vfat=y/# CONFIG_PACKAGE_kmod-fs-vfat is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-fs-ntfs3=y/# CONFIG_PACKAGE_kmod-fs-ntfs3 is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-fs-exfat=y/# CONFIG_PACKAGE_kmod-fs-exfat is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-fs-hfs=y/# CONFIG_PACKAGE_kmod-fs-hfs is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-fs-hfsplus=y/# CONFIG_PACKAGE_kmod-fs-hfsplus is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-fs-nfs=y/# CONFIG_PACKAGE_kmod-fs-nfs is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-fs-nfsd=y/# CONFIG_PACKAGE_kmod-fs-nfsd is not set/' .config

# 9. 禁用 SD卡 / MMC / 读卡器支持
sed -i 's/CONFIG_PACKAGE_kmod-mmc=y/# CONFIG_PACKAGE_kmod-mmc is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-sdhci=y/# CONFIG_PACKAGE_kmod-sdhci is not set/' .config
sed -i 's/CONFIG_PACKAGE_kmod-sdhci-arasan=y/# CONFIG_PACKAGE_kmod-sdhci-arasan is not set/' .config

# 10. 禁用 LuCI 磁盘管理插件
sed -i 's/CONFIG_PACKAGE_luci-app-block=y/# CONFIG_PACKAGE_luci-app-block is not set/' .config
sed -i 's/CONFIG_PACKAGE_luci-app-diskman=y/# CONFIG_PACKAGE_luci-app-diskman is not set/' .config
sed -i 's/CONFIG_PACKAGE_luci-app-diskman-ui=y/# CONFIG_PACKAGE_luci-app-diskman-ui is not set/' .config


# 打入频率补丁
PATCH_DIR=$(ls -d target/linux/qualcommax/patches-6.* 2>/dev/null | tail -n 1)
if [ -n "$PATCH_DIR" ]; then
    echo "检测到内核补丁目录: $PATCH_DIR"
    PATCH_FILE="$PATCH_DIR/0130-arm64-dts-qcom-ipq8074-add-CPU-OPP-table.patch"
    curl -fsSL "https://raw.githubusercontent.com/Mike-qian/OpenWRT-CI/refs/heads/main/0130-arm64-dts-qcom-ipq8074-add-CPU-OPP-table.patch" -o "$PATCH_FILE"
    if [ $? -eq 0 ]; then
        echo "补丁已成功下载并替换到: $PATCH_FILE"
    else
        echo "错误：补丁下载失败，请检查网络或 URL 是否正确。"
        exit 1
    fi
else
    echo "错误：未找到 target/linux/qualcommax/patches-6.* 目录，请检查源码结构。"
    exit 1
fi


cat >> target/linux/qualcommax/config-6.18 << 'EOF'
CONFIG_CRYPTO=y
CONFIG_CRYPTO_MANAGER=y
CONFIG_CRYPTO_HASH=y
CONFIG_CRYPTO_SIMD=y
CONFIG_ARM64_CRYPTO=y
CONFIG_KERNEL_MODE_NEON=y
CONFIG_ARM64_CRC32=y
CONFIG_BITREVERSE=y
CONFIG_CRC32=y
CONFIG_LIBCRC32C=y
CONFIG_CRYPTO_CRC32_ARM64_CE=y
CONFIG_CRYPTO_CRC32C_ARM64_CE=y
CONFIG_CRYPTO_AES_ARM64_CE=y
CONFIG_CRYPTO_AES_ARM64_CE_BLK=y
CONFIG_CRYPTO_AES_ARM64_CE_CCM=y
CONFIG_CRYPTO_AES_ARM64_BS=y
CONFIG_CRYPTO_SHA1_ARM64_CE=y
CONFIG_CRYPTO_SHA2_ARM64_CE=y
CONFIG_CRYPTO_SHA256_ARM64=y
CONFIG_CRYPTO_SHA512_ARM64_CE=y
CONFIG_CRYPTO_GHASH_ARM64_CE=y
CONFIG_CRYPTO_CHACHA20_NEON=y
CONFIG_CRYPTO_POLY1305_ARM64=y
CONFIG_CRYPTO_SM3_ARM64_CE=y
CONFIG_CRYPTO_SM4_ARM64_CE=y
CONFIG_CRYPTO_USER_API_HASH=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_DEFAULT_ON=y
EOF
echo "Done! 所有加密加速和 BPF 优化项已注入。"
cat build_dir/target-aarch64_cortex-a53_musl/linux-qualcommax/linux-6.18/.config | grep -E "CRYPTO|BPF"
# 确保 OpenWrt 层的模块也开启
#sed -i '/CONFIG_PACKAGE_kmod-crypto-crc32/d' .config && echo "CONFIG_PACKAGE_kmod-crypto-crc32=y" >> .config
#sed -i '/CONFIG_PACKAGE_kmod-crypto-crc32c/d' .config && echo "CONFIG_PACKAGE_kmod-crypto-crc32c=y" >> .config
#sed -i '/CONFIG_PACKAGE_kmod-crypto-aes/d' .config && echo "CONFIG_PACKAGE_kmod-crypto-aes=y" >> .config

