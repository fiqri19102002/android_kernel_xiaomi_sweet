#! /bin/bash

#
# Script for building Android arm64 Kernel
#
# Copyright (c) 2021 Fiqri Ardyansyah <fiqri15072019@gmail.com>
# Based on Panchajanya1999 script.
#

# Set environment for directory
KERNEL_DIR=$PWD
IMG_DIR="$KERNEL_DIR"/out/arch/arm64/boot

# Get defconfig file
DEFCONFIG=vendor/sweet_defconfig

# Set common environment
export KBUILD_BUILD_USER="FiqriArdyansyah"

#
# Set if do you use GCC or clang compiler
# Default is clang compiler
#
COMPILER=clang

# Get distro name
DISTRO=$(source /etc/os-release && echo ${NAME})

# Get all cores of CPU
PROCS=$(nproc --all)
export PROCS

# Set date and time
DATE=$(TZ=Asia/Jakarta date)

# Set date and time for zip name
ZIP_DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M")

# Get branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
export BRANCH

# Check kernel version
KERVER=$(make kernelversion)

# Get last commit
COMMIT_HEAD=$(git log --oneline -1)

# Check directory path
if [ -d "/root/project" ]; then
	echo -e "Detected Continous Integration dir"
	export LOCALBUILD=0
	export KBUILD_BUILD_VERSION="1"
	# Clone telegram script first
	git clone --depth=1 https://github.com/fabianonline/telegram.sh.git telegram
	# Set environment for telegram
	export TELEGRAM_DIR="$KERNEL_DIR/telegram/telegram"
	export TELEGRAM_CHAT="-1001428085807"
	# Get CPU name
	export CPU_NAME="$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) */\1/p')"
else
	echo -e "Detected local dir"
	export LOCALBUILD=1
fi

# Export build host name
if [ $LOCALBUILD == "0" ]; then
	export KBUILD_BUILD_HOST="CircleCI"
elif [ $LOCALBUILD == "1" ]; then
	export KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
fi

# Cleanup KernelSU first on local build
if [[ -d "$KERNEL_DIR"/KernelSU && $LOCALBUILD == "1" ]]; then
	rm -rf KernelSU drivers/kernelsu
fi

# Set function for telegram
tg_post_msg() {
	"${TELEGRAM_DIR}" -H -D \
        "$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )"
}

tg_post_build() {
	"${TELEGRAM_DIR}" -H \
        -f "$1" \
        "$2"
}

# Set funcrtion for setup KernelSU
setup_ksu() {
	curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
	git apply KernelSU-hook.patch
}

# Set function for defconfig changes
cfg_changes() {
	if [ $COMPILER == "clang" ]; then
		sed -i 's/CONFIG_LTO_GCC=y/# CONFIG_LTO_GCC is not set/g' arch/arm64/configs/vendor/sweet_defconfig
		sed -i 's/CONFIG_GCC_GRAPHITE=y/# CONFIG_GCC_GRAPHITE is not set/g' arch/arm64/configs/vendor/sweet_defconfig
	elif [ $COMPILER == "gcc" ]; then
		sed -i 's/CONFIG_LTO=y/# CONFIG_LTO is not set/g' arch/arm64/configs/vendor/sweet_defconfig
		sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/g' arch/arm64/configs/vendor/sweet_defconfig
		sed -i 's/# CONFIG_LTO_NONE is not set/CONFIG_LTO_NONE=y/g' arch/arm64/configs/vendor/sweet_defconfig
	fi

	if [ $LOCALBUILD == "1" ]; then
		if [ $COMPILER == "clang" ]; then
			sed -i 's/# CONFIG_THINLTO is not set/CONFIG_THINLTO=y/g' arch/arm64/configs/vendor/sweet_defconfig
		elif [ $COMPILER == "gcc" ]; then
			sed -i 's/CONFIG_LTO_GCC=y/# CONFIG_LTO_GCC is not set/g' arch/arm64/configs/vendor/sweet_defconfig
		fi
		if [ -d "$KERNEL_DIR"/KernelSU ]; then
			sed -i 's/CONFIG_CC_STACKPROTECTOR_STRONG=y/# CONFIG_CC_STACKPROTECTOR_STRONG is not set/g' arch/arm64/configs/vendor/sweet_defconfig
		fi
	fi
}

# Set function for cloning repository
clone() {
	# Clone AnyKernel3
	git clone --depth=1 https://github.com/fiqri19102002/AnyKernel3.git -b sweet

	if [ $COMPILER == "clang" ]; then
		# Clone Proton clang
		git clone --depth=1 https://gitlab.com/fiqri19102002/proton_clang-mirror.git clang
		# Set environment for clang
		TC_DIR=$KERNEL_DIR/clang
		# Get path and compiler string
		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$PATH
	elif [ $COMPILER == "gcc" ]; then
		# Clone GCC ARM64 and ARM32
		git clone https://github.com/fiqri19102002/aarch64-gcc.git -b release/elf-12 --depth=1 gcc64
		git clone https://github.com/fiqri19102002/arm-gcc.git -b release/elf-12 --depth=1 gcc32
		# Set environment for GCC ARM64 and ARM32
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
		# Get path and compiler string
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	fi

	export PATH KBUILD_COMPILER_STRING
}

# Set function for naming zip file
set_naming() {
	if [ -d "$KERNEL_DIR"/KernelSU ]; then
		KERNEL_NAME="STRIX-sweet-ksu-personal-$ZIP_DATE"
		export ZIP_NAME="$KERNEL_NAME.zip"
	else
		KERNEL_NAME="STRIX-sweet-personal-$ZIP_DATE"
		export ZIP_NAME="$KERNEL_NAME.zip"
	fi
}

# Set function for send messages to Telegram
send_tg_msg() {
	tg_post_msg "<b>Docker OS: </b><code>$DISTRO</code>" \
	            "<b>Kernel Version : </b><code>$KERVER</code>" \
	            "<b>Date : </b><code>$DATE</code>" \
	            "<b>Device : </b><code>Redmi Note 10 Pro (sweet)</code>" \
	            "<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>" \
	            "<b>Host CPU Name : </b><code>$CPU_NAME</code>" \
	            "<b>Host Core Count : </b><code>$PROCS</code>" \
	            "<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>" \
	            "<b>Branch : </b><code>$BRANCH</code>" \
	            "<b>Last Commit : </b><code>$COMMIT_HEAD</code>"
}

# Set function for starting compile
compile() {
	echo -e "Kernel compilation starting"
	make O=out "$DEFCONFIG"
	BUILD_START=$(date +"%s")
	if [ $COMPILER == "clang" ]; then
		make -j"$PROCS" O=out \
				CROSS_COMPILE=aarch64-linux-gnu- \
				LLVM=1
	elif [ $COMPILER == "gcc" ]; then
		export CROSS_COMPILE_COMPAT=$GCC32_DIR/bin/arm-eabi-
		make -j"$PROCS" O=out CROSS_COMPILE=aarch64-elf-
	fi
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	if [ -f "$IMG_DIR"/Image.gz-dtb ]; then
		echo -e "Kernel successfully compiled"
		if [ $LOCALBUILD == "1" ]; then
			git restore arch/arm64/configs/vendor/sweet_defconfig
			if [ -d "$KERNEL_DIR"/KernelSU ]; then
				git restore drivers/Makefile drivers/input/input.c fs/exec.c fs/open.c fs/read_write.c fs/stat.c
			fi
		fi
	elif ! [ -f "$IMG_DIR"/Image.gz-dtb ]; then
		echo -e "Kernel compilation failed"
		if [ $LOCALBUILD == "0" ]; then
			tg_post_msg "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
		fi
		if [ $LOCALBUILD == "1" ]; then
			git restore arch/arm64/configs/vendor/sweet_defconfig
			if [ -d "$KERNEL_DIR"/KernelSU ]; then
				git restore drivers/Makefile drivers/input/input.c fs/exec.c fs/open.c fs/read_write.c fs/stat.c
			fi
		fi
		exit 1
	fi
}

# Set function for zipping into a flashable zip
gen_zip() {
	if [[ $LOCALBUILD == "1" || -d "$KERNEL_DIR"/KernelSU ]]; then
		cd AnyKernel3 || exit
		rm -rf dtbo/oss/dtbo.img dtb.img Image.gz-dtb *.zip
		cd ..
	fi

	# Move kernel image to AnyKernel3
	mv "$IMG_DIR"/dtb.img AnyKernel3/dtb.img
	mv "$IMG_DIR"/dtbo.img AnyKernel3/dtbo/oss/dtbo.img
	mv "$IMG_DIR"/Image AnyKernel3/Image.gz-dtb
	cd AnyKernel3 || exit

	# Archive to flashable zip
	zip -r9 "$ZIP_NAME" * -x .git README.md *.zip

	# Prepare a final zip variable
	ZIP_FINAL="$ZIP_NAME"

	if [ $LOCALBUILD == "0" ]; then
		tg_post_build "$ZIP_FINAL" "<b>Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</b>"
	fi

	if ! [[ -d "/home/fiqri" || -d "/root/project" ]]; then
		curl -i -T *.zip https://oshi.at
		curl bashupload.com -T *.zip
	fi
	cd ..
}

clone
cfg_changes
if [ $LOCALBUILD == "0" ]; then
	send_tg_msg
fi
compile
set_naming
gen_zip
setup_ksu
cfg_changes
compile
set_naming
gen_zip
