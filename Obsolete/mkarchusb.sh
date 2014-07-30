#!/bin/sh -ex
iso=$1
root=/run/media/grawity/IMIQ
mountpoint -q "$root"
dev=$(findmnt -n -o SOURCE --target "$root")
uuid=$(lsblk -n -o UUID "$dev")
if [ -f "$iso" ]; then
	rm -rf "$root/arch"
	bsdtar -C "$root" -xf "$iso" arch/
fi
rdev=$(echo "$dev" | sed 's/[[:digit:]]\+$//')
sudo extlinux --install "$root/arch/boot/syslinux"
#dd if=/usr/lib/syslinux/mbr.bin bs=440 conv=notrunc count=1 of="$dev"
sed -i "/APPEND/ s|isolabel=ARCH_[0-9]\+|isodevice=/dev/disk/by-uuid/$uuid|" \
	"$root/arch/boot/syslinux"/archiso_sys{32,64}.cfg
sed -i "/APPEND/ s|\.\./\.\./|/arch|" \
	"$root/arch/boot/syslinux/syslinux.cfg"
sudo umount "$root"
echo done.
