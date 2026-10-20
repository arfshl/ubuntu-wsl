#!/bin/sh

# export the env
export RELEASE=$(curl -s https://changelogs.ubuntu.com/meta-release | grep "Dist:" | tail -n 1 | cut -d' ' -f2)
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) 
        ARCH=amd64
        MIRROR="http://archive.ubuntu.com/ubuntu"
        ;;
    aarch64|arm64) 
        ARCH=arm64
        MIRROR="http://ports.ubuntu.com/ubuntu-ports"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "RELEASE=$RELEASE" >> "$GITHUB_OUTPUT"
echo "ARCH=$ARCH" >> "$GITHUB_OUTPUT"

# install depedencies
sudo apt install -yq mmdebstrap

# start build with mmdebstrap and sprays some WD-40 to get rid of rust on coreutils
sudo mmdebstrap \
--arch=$ARCH \
--variant="debootstrap" \
--components="main,universe,multiverse" \
--format=directory \
${RELEASE} \
ubuntu \
${MIRROR} \
--include=\
locales,\
passwd,\
software-properties-common,\
ca-certificates,\
sudo,\
libpam-systemd,\
dbus,\
systemd,\
mesa-utils,\
systemd-sysv,\
adduser,\
dbus-user-session,\
xauth,\
libgl1,\
libglx-mesa0,\
update-manager-core,\
wget,\
curl,\
nano,\

cat <<-EOF | sudo unshare -mpf bash -e -
sudo mount --bind /dev ./ubuntu/dev
sudo mount --bind /proc ./ubuntu/proc
sudo mount --bind /sys ./ubuntu/sys
sudo rm -f ./ubuntu/etc/resolv.conf
sudo echo "nameserver 1.1.1.1" >> ./ubuntu/etc/resolv.conf

#De-rustification (disabled)
#sudo chroot ./ubuntu apt update
#sudo chroot ./ubuntu apt purge -yq --allow-remove-essential coreutils-from-uutils
#sudo chroot ./ubuntu apt purge -yq --allow-remove-essential rust-coreutils
#sudo chroot ./ubuntu apt install -yq coreutils-from-gnu
#sudo chroot ./ubuntu apt install -yq gnu-coreutils
#sudo chroot ./ubuntu apt clean

sudo chroot ./ubuntu sed -i 's/^# \(en_US.UTF-8\)/\1/' /etc/locale.gen
sudo chroot ./ubuntu /bin/bash -c 'DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales'

sudo rm -rf ./ubuntu/var/lib/apt/lists/*
sudo rm -rf ./ubuntu/var/tmp*
sudo rm -rf ./ubuntu/tmp*
EOF

sudo cp ./wslconf/oobe.sh ./ubuntu/etc/oobe.sh
sudo chmod 644 ./ubuntu/etc/oobe.sh
sudo chmod +x ./ubuntu/etc/oobe.sh
sudo cp ./wslconf/wsl.conf ./ubuntu/etc/wsl.conf
sudo chmod 644 ./ubuntu/etc/wsl.conf
sudo cp ./wslconf/wsl-distribution.conf ./ubuntu/etc/wsl-distribution.conf
sudo chmod 644 ./ubuntu/etc/wsl-distribution.conf
sudo mkdir -p ./ubuntu/usr/lib/wsl/
sudo cp ./wslconf/icon.ico ./ubuntu/usr/lib/wsl/icon.ico

cd ./ubuntu
sudo tar --numeric-owner --absolute-names -c  * | gzip --best > ../install.tar.gz
mv ../install.tar.gz ../ubuntu-latest-$ARCH.wsl
