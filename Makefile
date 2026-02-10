THREADS := $(shell nproc)
HALF_THREADS := $(shell expr $(THREADS) / 2)
ifeq ($(HALF_THREADS), 0)
    HALF_THREADS := 1
endif

all: build boot kernel glibc gcc-libs busybox mkboot mkroot

build:
	mkdir -p $(shell pwd)/../out/build/boot
	mkdir -p $(shell pwd)/../out/build/root

	mkdir -p $(shell pwd)/../out/boot/limine

	mkdir -p $(shell pwd)/../out/external/gcc/_build_
	mkdir -p $(shell pwd)/../out/external/glibc/_build_
	mkdir -p $(shell pwd)/../out/external/busybox/_build_

	mkdir -p $(shell pwd)/../out/kernel/linux/_modules_
	mkdir -p $(shell pwd)/../out/kernel/linux/_include_

boot:
	cd $(shell pwd)/../boot/limine/ && ./bootstrap
	cd $(shell pwd)/../out/boot/limine && $(shell pwd)/../boot/limine/configure --enable-uefi-riscv64
	$(MAKE) -C $(shell pwd)/../out/boot/limine -j$(HALF_THREADS)

kernel:
	$(MAKE) -C $(shell pwd)/../kernel/linux/ O=$(shell pwd)/../out/kernel/linux starfive_visionfive2_defconfig
	$(MAKE) -C $(shell pwd)/../kernel/linux/ O=$(shell pwd)/../out/kernel/linux -j$(HALF_THREADS)
	$(MAKE) -C $(shell pwd)/../kernel/linux/ O=$(shell pwd)/../out/kernel/linux modules_install INSTALL_MOD_PATH=$(shell pwd)/../out/kernel/linux/_modules_
	$(MAKE) -C $(shell pwd)/../kernel/linux/ O=$(shell pwd)/../out/kernel/linux headers_install INSTALL_HDR_PATH=$(shell pwd)/../out/kernel/linux/_include_

glibc:
	cd $(shell pwd)/../out/external/glibc && $(shell pwd)/../external/glibc/configure --host=riscv64-linux-gnu --prefix=/usr \
            --with-headers=$(shell pwd)/../out/kernel/linux/_include_/include --disable-werror libc_cv_slibdir=/lib --disable-test-werror CXX="riscv64-linux-gnu-gcc -nostdlib"
	$(MAKE) -C $(shell pwd)/../out/external/glibc -j$(HALF_THREADS)
	$(MAKE) -C $(shell pwd)/../out/external/glibc install install_root=$(shell pwd)/../out/external/glibc/_build_
	cp -r $(shell pwd)/../out/kernel/linux/_include_/include/* $(shell pwd)/../out/external/glibc/_build_/usr/include/

gcc-libs:
	cd $(shell pwd)/../out/external/gcc && $(shell pwd)/../external/gcc/configure --target=riscv64-linux-gnu --with-sysroot=$(shell pwd)/../out/external/glibc/_build_ --with-arch=rv64gc --disable-bootstrap \
            --with-abi=lp64d --enable-languages=c,c++ --enable-shared --enable-threads=posix --with-system-zlib --enable-tls --disable-libmudflap --disable-libssp --disable-libquadmath --disable-nls --disable-multilib
	$(MAKE) -C $(shell pwd)/../out/external/gcc all-target-libgcc all-target-libstdc++-v3 -j$(HALF_THREADS)
	$(MAKE) -C $(shell pwd)/../out/external/gcc install-target-libgcc install-target-libstdc++-v3 DESTDIR=$(shell pwd)/../out/external/gcc/_build_

busybox:
	$(MAKE) -C $(shell pwd)/../external/busybox ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- O=$(shell pwd)/../out/external/busybox defconfig
	sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' $(shell pwd)/../out/external/busybox/.config
	$(MAKE) -C $(shell pwd)/../external/busybox ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- O=$(shell pwd)/../out/external/busybox -j$(HALF_THREADS)
	$(MAKE) -C $(shell pwd)/../external/busybox ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- O=$(shell pwd)/../out/external/busybox install CONFIG_PREFIX=$(shell pwd)/../out/external/busybox/_build_

mkboot:
	mkdir -p $(shell pwd)/../out/build/boot/EFI/Boot $(shell pwd)/../out/build/boot/EFI/Linux
	mkdir -p $(shell pwd)/../out/build/boot/Limine/dtbs

	cp -r $(shell pwd)/../out/boot/limine/bin/BOOTRISCV64.EFI $(shell pwd)/../out/build/boot/EFI/Boot/BOOTRISCV64.EFI
	cp -r $(shell pwd)/../out/kernel/linux/arch/riscv/boot/Image $(shell pwd)/../out/build/boot/EFI/Linux/vmlinuz-6.12.5-starfive
	cp -r $(shell pwd)/../out/kernel/linux/.config $(shell pwd)/../out/build/boot/EFI/Linux/config-6.12.5-starfive
	cp -r $(shell pwd)/../out/kernel/linux/System.map $(shell pwd)/../out/build/boot/EFI/Linux/System.map-6.12.5-starfive

	cp -r $(shell pwd)/../assets/dtbs/* $(shell pwd)/../out/build/boot/Limine/dtbs
	cp -r $(shell pwd)/../assets/background.jpg $(shell pwd)/../out/build/boot/Limine/background.jpg
	cp -r $(shell pwd)/../assets/limine.conf $(shell pwd)/../out/build/boot/Limine/limine.conf
	cp -r $(shell pwd)/../assets/boot.scr $(shell pwd)/../out/build/boot/boot.scr

mkroot:
	mkdir -p $(shell pwd)/../out/build/root/dev $(shell pwd)/../out/build/root/etc $(shell pwd)/../out/build/root/proc
	mkdir -p $(shell pwd)/../out/build/root/sys $(shell pwd)/../out/build/root/tmp $(shell pwd)/../out/build/root/usr
	mkdir -p $(shell pwd)/../out/build/root/usr/bin $(shell pwd)/../out/build/root/usr/sbin
	mkdir -p $(shell pwd)/../out/build/root/usr/lib $(shell pwd)/../out/build/root/usr/lib64
	mkdir -p $(shell pwd)/../out/build/root/usr/lib/modules

	cp -r $(shell pwd)/../out/external/busybox/_build_/bin/* $(shell pwd)/../out/build/root/usr/bin
	cp -r $(shell pwd)/../out/external/busybox/_build_/usr/bin/* $(shell pwd)/../out/build/root/usr/bin
	cp -r $(shell pwd)/../out/external/busybox/_build_/sbin/* $(shell pwd)/../out/build/root/usr/sbin
	cp -r $(shell pwd)/../out/external/busybox/_build_/usr/sbin/* $(shell pwd)/../out/build/root/usr/sbin
	cp -r $(shell pwd)/../out/external/glibc/_build_/lib/* $(shell pwd)/../out/build/root/usr/lib/
	cp -r $(shell pwd)/../out/external/gcc/_build_/usr/local/riscv64-linux-gnu/lib/libgcc_s.so.1 $(shell pwd)/../out/build/root/usr/lib/libgcc_s.so.1
	cp -r $(shell pwd)/../out/external/gcc/_build_/usr/local/riscv64-linux-gnu/lib/libstdc++.so.6.0.33 $(shell pwd)/../out/build/root/usr/lib/libstdc++.so.6
	cp -r $(shell pwd)/../out/kernel/linux/_modules_/lib/modules/* $(shell pwd)/../out/build/root/usr/lib/modules
	cp -r $(shell pwd)/../assets/config/* $(shell pwd)/../out/build/root/etc

	rm -r $(shell pwd)/../out/build/root/usr/lib/modules/6.12.5+/build
	chmod 755 $(shell pwd)/../out/build/root/usr/lib/*
	chmod 755 $(shell pwd)/../out/build/root/etc/init.d/rcS

	cd $(shell pwd)/../out/build/root && ln -sf usr/bin bin
	cd $(shell pwd)/../out/build/root && ln -sf usr/sbin sbin
	cd $(shell pwd)/../out/build/root && ln -sf usr/lib lib
	cd $(shell pwd)/../out/build/root && ln -sf usr/lib64 lib64
	cd $(shell pwd)/../out/build/root/usr/lib64 && ln -sf ../lib/ld-linux-riscv64-lp64d.so.1 ld-linux-riscv64-lp64d.so.1
	cd $(shell pwd)/../out/build/root && ln -sf bin/busybox linuxrc

	@printf "\n\033[32mBuild complete. Boot partition: out/build/boot, root partition: out/build/root\033[0m\n"
