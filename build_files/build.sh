#!/bin/bash

set -ouex pipefail

# use CoreOS' generator for emergency/rescue boot
# see detail: https://github.com/ublue-os/main/issues/653
CSFG=/usr/lib/systemd/system-generators/coreos-sulogin-force-generator
curl -sSLo ${CSFG} https://raw.githubusercontent.com/coreos/fedora-coreos-config/refs/heads/stable/overlay.d/05core/usr/lib/systemd/system-generators/coreos-sulogin-force-generator
chmod +x ${CSFG}

# Install dnf5 if not installed
if ! rpm -q dnf5 >/dev/null; then
    rpm-ostree install dnf5 dnf5-plugins
fi


#add normal flathub
dnf5 remove -y fedora-flathub-remote
mkdir -p /etc/flatpak/remotes.d/
curl --retry 3 -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo


#yum repos
dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
# use negativo17 for 3rd party packages with higher priority than default
dnf5 config-manager addrepo --from-repofile="https://negativo17.org/repos/fedora-multimedia.repo"
dnf5 config-manager setopt fedora-multimedia.priority=90

dnf5 -y update --exclude=proj-data-*

# use override to replace mesa and others with less crippled versions
OVERRIDES=(
    "intel-gmmlib"
    "intel-mediasdk"
    "intel-vpl-gpu-rt"
    "libheif"
    "libva"
    "libva-intel-media-driver"
    "mesa-dri-drivers"
    "mesa-filesystem"
    "mesa-libEGL"
    "mesa-libGL"
    "mesa-libgbm"
    "mesa-va-drivers"
    "mesa-vulkan-drivers"
)

dnf5 distro-sync --skip-unavailable -y --repo='fedora-multimedia' "${OVERRIDES[@]}"
dnf5 versionlock add "${OVERRIDES[@]}"



#add packages/coprs/flatpacks

# Add COPRs
dnf5 -y copr enable ublue-os/packages


# Install packages
PACKAGES=(
    alsa-firmware
    apr
    apr-util
    bash-color-prompt
    bcache-tools
    bootc
    borgbackup
    cryfs
    davfs2
    ddcutil
    distrobox
    fastfetch
    fdk-aac
    fedora-repos-archive
    ffmpeg
    ffmpeg-libs
    ffmpegthumbnailer
    firewall-config
    flatpak-spawn
    foo2zjs
    fuse
    fuse-encfs
    fzf
    gcc
    git-credential-libsecret
    google-noto-sans-balinese-fonts
    google-noto-sans-cjk-fonts
    google-noto-sans-javanese-fonts
    google-noto-sans-sundanese-fonts
    grub2-tools-extra
    heif-pixbuf-loader
    htop
    ibus-mozc
    ifuse
    igt-gpu-tools
    input-remapper
    intel-vaapi-driver
    iwd
    jetbrains-mono-fonts-all
    just
    krb5-workstation
    libavcodec
    libcamera
    libcamera-gstreamer
    libcamera-ipa
    libcamera-tools
    libfdk-aac
    libgda
    libgda-sqlite
    libheif
    libimobiledevice
    libimobiledevice-utils
    libratbag-ratbagd
    libratbag-ratbagd
    libsss_autofs
    libva-utils
    libxcrypt-compat
    lm_sensors
    lshw
    make
    mesa-libGLU
    mozc
    net-tools
    nvme-cli
    nvtop
    oddjob-mkhomedir
    opendyslexic-fonts
    openrgb-udev-rules
    openssh-askpass
    openssl
    oversteer-udev
    pam-u2f
    pam_yubico
    pamu2fcfg
    pipewire-plugin-libcamera
    powerstat
    powertop
    printer-driver-brlaser
    pulseaudio-utils
    python3-pip
    python3-pygit2
    rclone
    restic
    samba
    samba-dcerpc
    samba-ldb-ldap-modules
    samba-winbind-clients
    samba-winbind-modules
    setools-console
    smartmontools
    solaar-udev
    squashfs-tools
    sssd-ad
    sssd-krb5
    sssd-nfs-idmap
    symlinks
    tcpdump
    tmux
    traceroute
    ublue-os-just
    ublue-os-luks
    ublue-os-udev-rules
    usbip
    usbmuxd
    vim
    waypipe
    wireguard-tools
    wl-clipboard
    xhost
    xorg-x11-xauth
    xprop
    yubikey-manager
    zsh
    zstd
    android-tools
    bcc
    bpftop
    bpftrace
    cascadia-code-fonts
    dbus-x11
    edk2-ovmf
    flatpak-builder
    genisoimage
    git-subtree
    git-svn
    iotop
    libvirt
    libvirt-nss
    nicstat
    numactl
    osbuild-selinux
    p7zip
    p7zip-plugins
    podman-compose
    podman-machine
    podman-tui
    qemu
    qemu-char-spice
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-vga
    qemu-device-usb-redirect
    qemu-img
    qemu-system-x86-core
    qemu-user-binfmt
    qemu-user-static
    sysprof
    incus
    incus-agent
    lxc
    tiptop
    trace-cmd
    udica
    util-linux-script
    virt-manager
    virt-v2v
    virt-viewer
    ydotool
    containerd.io
    docker-buildx-plugin
    docker-ce
    docker-ce-cli
    docker-compose-plugin
    docker-model-plugin
    tailscale
    chezmoi
)
dnf5 -y install --exclude=proj-data-* "${PACKAGES[@]}"


#install flatpaks
FLATPAKS=(
    io.github.pwr_solaar.solaar
    com.github.tchx84.Flatseal
)
flatpak install --system -y flathub ${FLATPAKS[@]}


#### systemd stuff
systemctl enable docker.socket
systemctl enable podman.socket
systemctl enable tailscaled.service




# Cleanup

# Remove tmp files and everything in dirs that make bootc unhappy
dnf clean all
rm -rf /tmp/* || true
rm -rf /usr/etc
rm -rf /boot && mkdir /boot
# Preserve cache mounts
find /var/* -maxdepth 0 -type d \! -name cache \! -name log -exec rm -rf {} \;
find /var/cache/* -maxdepth 0 -type d \! -name libdnf5 -exec rm -rf {} \;

# Make sure /var/tmp is properly created
mkdir -p /var/tmp
chmod -R 1777 /var/tmp
