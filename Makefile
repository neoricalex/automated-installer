#
# Build an installer image to boot a bare-metal server and install a ZFS root
# disk
#

all:
	@echo not yet
	false

SUBDIRS := debian kernel

CLEAN_FILES := nothing

CONFIGDIRS := .
CONFIGDIRS += $(abspath zfs-config)
export CONFIGDIRS

# The minimal install system is built as this arch, not the installed server
CONFIG_DEBIAN_ARCH := i386
export CONFIG_DEBIAN_ARCH

CONFIG_DEBIAN_VER := stretch

ISODIR := iso
DISK_IMAGE := $(ISODIR)/boot.img
ISO_IMAGE := boot.iso
PART_SIZE_MEGS = 200

build-depends: debian/Makefile
	$(foreach dir,$(SUBDIRS),$(MAKE) -C $(dir) $@ &&) true
	sudo apt install ovmf isolinux xorriso

# Calculate the basename of the debian build file
DEBIAN_BASENAME = debian.$(CONFIG_DEBIAN_VER).$(CONFIG_DEBIAN_ARCH)
DEBIAN = debian/build/$(DEBIAN_BASENAME)

# Rules to go and make the debian installed root
# Note: this has no dependancy checking, and will simply use what ever
# file is there
.PHONY: $(DEBIAN).cpio
$(DEBIAN).cpio: debian/Makefile
	$(MAKE) -C debian build/$(DEBIAN_BASENAME).cpio

# Ensure that the submodule is actually present
debian/Makefile:
	git submodule update --init --remote

kernel/ubuntu.amd64.kernel kernel/ubuntu.amd64.modules.cpio:
	$(MAKE) -C kernel all

combined.initrd: $(DEBIAN).cpio kernel/ubuntu.amd64.modules.cpio
	cat $^ >$@

$(DISK_IMAGE): startup.nsh combined.initrd kernel/ubuntu.amd64.kernel
	mkdir -p $(dir $@)
	truncate --size=$(PART_SIZE_MEGS)M $@.tmp
	mformat -i $@.tmp -v EFS -N 2 -t $(PART_SIZE_MEGS) -h 64 -s 32 ::
	mmd -i $@.tmp ::efi
	mmd -i $@.tmp ::efi/boot
	mcopy -i $@.tmp kernel/ubuntu.amd64.kernel ::linux.efi
	mcopy -i $@.tmp combined.initrd ::initrd
	mcopy -i $@.tmp startup.nsh ::
	mv $@.tmp $@

$(ISO_IMAGE): $(DISK_IMAGE)
	xorrisofs \
	    -o $@ \
	    --efi-boot $(notdir $(DISK_IMAGE)) \
	    $(ISODIR)

QEMU_CMD := qemu-system-x86_64 -enable-kvm \
    -m 1024 \
    -netdev type=user,id=e0 -device virtio-net-pci,netdev=e0

QEMU_ISO_CMD := $(QEMU_CMD) \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -cdrom $(ISO_IMAGE)

# Just build the initramfs and boot it directly
test_quick: combined.initrd kernel/ubuntu.amd64.kernel
	$(QEMU_CMD) \
	    -append console=ttyS0 \
	    -kernel kernel/ubuntu.amd64.kernel \
	    -initrd combined.initrd \
	    -nographic

# Test the EFI boot
test_efi: $(ISO_IMAGE)
	$(QEMU_ISO_CMD) \
	    -nographic

# Test EFI booting, with an actual graphics console visible
test_efigui: $(ISO_IMAGE)
	$(QEMU_ISO_CMD) \
	    -serial vc -serial stdio

persistant.storage:
	truncate $@ --size=2G
REALLYCLEAN_FILES += persistant.storage

test_efigui_persist: $(ISO_IMAGE) persistant.storage
	$(QEMU_ISO_CMD) \
	    -serial vc -serial stdio \
	    -drive if=virtio,format=raw,file=persistant.storage

clean:
	$(foreach dir,$(SUBDIRS),$(MAKE) -C $(dir) $@ &&) true
	rm -f $(CLEAN_FILES)

reallyclean:
	$(foreach dir,$(SUBDIRS),$(MAKE) -C $(dir) $@ &&) true
	rm -f $(REALLYCLEAN_FILES)
