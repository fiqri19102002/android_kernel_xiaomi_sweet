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
	echo -e "Detected Continuous Integration dir"
	export LOCALBUILD=0
	export KBUILD_BUILD_VERSION="1"
	# Clone telegram script first
	git clone --depth=1 https://github.com/fabianonline/telegram.sh.git telegram
	# Set environment for telegram
	export TELEGRAM_DIR="$KERNEL_DIR/telegram/telegram"
	export TELEGRAM_CHAT="-1002143823461"
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
		git clone https://github.com/arter97/arm64-gcc.git --depth=1 gcc64
		git clone https://github.com/arter97/arm32-gcc.git --depth=1 gcc32
		# Set environment for GCC ARM64 and ARM32
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
		# Get path and compiler string
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-none-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	fi

	export PATH KBUILD_COMPILER_STRING
}

# Set function for naming zip file
set_naming() {
	KERNEL_NAME="STRIX-sweet-personal-$ZIP_DATE"
	export ZIP_NAME="$KERNEL_NAME.zip"
}

# Set function for starting compile
compile() {
	echo -e "Kernel compilation starting"
	if [ $LOCALBUILD == "0" ]; then
		tg_post_msg "<b>Docker OS: </b><code>$DISTRO</code>" \
		            "<b>Kernel Version : </b><code>$KERVER</code>" \
		            "<b>Date : </b><code>$DATE</code>" \
		            "<b>Device : </b><code>Redmi Note 10 Pro (sweet)</code>" \
		            "<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>" \
		            "<b>Host CPU Name : </b><code>$CPU_NAME</code>" \
		            "<b>Host Core Count : </b><code>$PROCS core(s)</code>" \
		            "<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>" \
		            "<b>Branch : </b><code>$BRANCH</code>" \
		            "<b>Last Commit : </b><code>$COMMIT_HEAD</code>"
	fi
	make O=out "$DEFCONFIG"
	BUILD_START=$(date +"%s")
	if [ $COMPILER == "clang" ]; then
		make -j"$PROCS" O=out \
				CROSS_COMPILE=aarch64-linux-gnu- \
				CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
				CC=clang \
				AR=llvm-ar \
				NM=llvm-nm \
				LD=ld.lld \
				OBJDUMP=llvm-objdump \
				STRIP=llvm-strip
	elif [ $COMPILER == "gcc" ]; then
		export CROSS_COMPILE_ARM32=$GCC32_DIR/bin/arm-none-eabi-
		make -j"$PROCS" O=out CROSS_COMPILE=aarch64-none-elf-
	fi
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	if [ -f "$IMG_DIR"/Image.gz-dtb ]; then
		echo -e "Kernel successfully compiled"
	elif ! [ -f "$IMG_DIR"/Image.gz-dtb ]; then
		echo -e "Kernel compilation failed"
		if [ $LOCALBUILD == "0" ]; then
			tg_post_msg "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
		fi
		exit 1
	fi
}

# Set function for zipping into a flashable zip
gen_zip() {
	if [ $LOCALBUILD == "1" ]; then
		cd AnyKernel3 || exit
		rm -rf dtb.img dtbo.img Image.gz-dtb *.zip
		cd ..
	fi

	# Move kernel image to AnyKernel3
	mv "$IMG_DIR"/dtb.img AnyKernel3/dtb.img
	mv "$IMG_DIR"/dtbo.img AnyKernel3/dtbo.img
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
compile
set_naming
gen_zip
