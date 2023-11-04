{ lib, vmTools, udev, gptfdisk, util-linux, dosfstools, e2fsprogs, strace }:
vmTools.makeImageFromDebDist {
  inherit (vmTools.debDistros.ubuntu2004x86_64) name fullName urlPrefix packagesLists;

  packages = lib.filter (p: !lib.elem p [
    "g++" "make" "dpkg-dev" "pkg-config"
    "sysvinit"
  ]) vmTools.debDistros.ubuntu2004x86_64.packages ++ [
    "systemd" # init system
    "init-system-helpers" # ???
    "systemd-sysv" # ???
    "dbus" # ???
    "linux-image-generic" # kernel
    #"linux-image-5.4.0-26-generic"
    "initramfs-tools" # hooks for generating an initramfs
    "e2fsprogs" # for fsck
    "grub-efi"
  ];

  size = 8192;

  createRootFS = ''
    disk=/dev/vda
    ${gptfdisk}/bin/sgdisk $disk \
      -n1:0:+100M -t1:ef00 -c1:esp \
      -n2:0:0 -t2:8300 -c2:root

    ${util-linux}/bin/partx -u "$disk"
    ${dosfstools}/bin/mkfs.vfat -F32 -n ESP "$disk"1
    part="$disk"2
    ${e2fsprogs}/bin/mkfs.ext4 "$part" -L root
    mkdir /mnt
    ${util-linux}/bin/mount -t ext4 "$part" /mnt
    mkdir -p /mnt/{proc,dev,sys,boot/efi}
    ${util-linux}/bin/mount -t vfat "$disk"1 /mnt/boot/efi
    touch /mnt/.debug
  '';

  postInstall = ''
    # update-grub needs udev to detect the filesystem UUID -- without,
    # we'll get root=/dev/vda2 on the cmdline which will only work in
    # a limited set of scenarios.
    ${udev}/lib/systemd/systemd-udevd &
    ${udev}/bin/udevadm trigger
    ${udev}/bin/udevadm settle

    ${util-linux}/bin/mount -t sysfs sysfs /mnt/sys

    chroot /mnt /bin/bash -exuo pipefail <<CHROOT
    export PATH=/usr/sbin:/usr/bin:/sbin:/bin

    # update-initramfs needs to know where its root filesystem lives,
    # so that the initial userspace is capable of finding and mounting it.
    echo LABEL=root / ext4 defaults > /etc/fstab

    dpkg --configure -a

    # actually generate an initramfs
    update-initramfs -k all -c

    # Install the boot loader to the EFI System Partition
    cat >> /etc/default/grub <<EOF
    GRUB_TIMEOUT=5
    GRUB_CMDLINE_LINUX=""
    GRUB_CMDLINE_LINUX_DEFAULT=""
    EOF
    sed -i '/TIMEOUT_HIDDEN/d' /etc/default/grub
    update-grub
    grub-install --target x86_64-efi

    # Set a password so we can log into the booted system
    echo root:root | chpasswd

    CHROOT
    ${util-linux}/bin/umount /mnt/boot/efi
    ${util-linux}/bin/umount /mnt/sys
  '';
}
