FROM ubuntu:trusty

# Set locale to fix character encoding
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and utilities
RUN apt-get update && apt-get install -y \
  apt-src \
  devscripts \
  debian-keyring \
  debhelper \
  software-properties-common \
  aptitude \
  sudo \
  wget \
  less \
  vim \
  quilt

WORKDIR /build

# Avoid warnings and occasional bugs with building packages as root
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN useradd --user-group builder
RUN adduser builder sudo
RUN mkdir -p /home/builder
RUN chown -R builder:builder \
  /home/builder \
  /build
USER builder
RUN mkdir -p ~/.apt-src

# Set name and email that will appear in changelog entries
ARG name="Backport Builder"
ARG email="nowhere@example.com"
ARG version="backport"
ARG distribution="trusty"
ENV NAME=${name}
ENV EMAIL=${email}
ENV VERSION=${version}
ENV DISTRIBUTION=${distribution}
ENV QUILT_PATCHES=debian/patches

COPY build_backport.sh /scripts/

##### Forward-port ZFS/SPL 0.7.1 package from PPA to newer ZFS version
# See https://www.debian.org/doc/manuals/maint-guide/update.en.html#newupstream
ARG new_zfs_version="0.7.8"

# Get source packages from PPA
RUN sudo add-apt-repository -y ppa:zfs-native/staging
RUN sudo \
  sed -i "s/# deb-src /deb-src /g" \
  /etc/apt/sources.list.d/zfs-native-staging-trusty.list
RUN sudo apt-get update \
  && apt-src install \
    zfs-linux \
    spl-linux
RUN sudo rm /etc/apt/sources.list.d/zfs-native-staging-trusty.list


# get newer sources
ARG spl_dir="spl-linux-${new_zfs_version}"

RUN wget \
  https://github.com/zfsonlinux/zfs/releases/download/zfs-${new_zfs_version}/spl-${new_zfs_version}.tar.gz
RUN tar -xvzf spl-${new_zfs_version}.tar.gz
RUN mv spl-${new_zfs_version} ${spl_dir}
RUN mv spl-${new_zfs_version}.tar.gz spl-linux_${new_zfs_version}.orig.tar.gz
RUN mv spl-linux-0.7.1/debian ${spl_dir}/
# Add changelog entry for new version
RUN debchange \
  --changelog ${spl_dir}/debian/changelog \
  --newversion ${new_zfs_version}-1~0${VERSION} \
  --distribution ${DISTRIBUTION} \
  --force-distribution \
  "Forward-port to ${new_zfs_version}."
# Delete quilt patch from backporter that looks wrong
RUN cd ${spl_dir} \
  && quilt delete -r debian-changes-0.7.1-1~trusty
RUN cd ${spl_dir} \
  && while quilt push; do quilt refresh; done

# Apply retpoline pach from David Hollister
ARG spl_patch="spl-retpoline.patch"
ARG spl_to_patch="config/spl-build.m4"
COPY ${spl_patch} /patches/
RUN cd ${spl_dir} \
  && quilt new ${spl_patch} \
  && quilt add ${spl_to_patch} \
  && patch ${spl_to_patch} /patches/${spl_patch} \
  && quilt refresh \
  && quilt pop -a

RUN cd ${spl_dir} \
  && debuild -i -uc -us
RUN rm -rf ${spl_dir}


# get newer sources
ARG zfs_dir="zfs-linux-${new_zfs_version}"

RUN wget \
  https://github.com/zfsonlinux/zfs/releases/download/zfs-${new_zfs_version}/zfs-${new_zfs_version}.tar.gz
RUN tar -xvzf zfs-${new_zfs_version}.tar.gz
RUN mv zfs-${new_zfs_version} ${zfs_dir}
RUN mv zfs-${new_zfs_version}.tar.gz zfs-linux_${new_zfs_version}.orig.tar.gz
RUN mv zfs-linux-0.7.1/debian ${zfs_dir}/
# Add changelog entry for new version
RUN debchange \
  --changelog ${zfs_dir}/debian/changelog \
  --newversion ${new_zfs_version}-1~0${VERSION} \
  --distribution ${DISTRIBUTION} \
  --force-distribution \
  "Forward-port to ${new_zfs_version}."
# Refresh quilt patches
RUN cd ${zfs_dir} \
  && while quilt push; do quilt refresh; done

# Apply retpoline pach from David Hollister
ARG zfs_patch="zfs-retpoline.patch"
ARG zfs_to_patch="config/kernel.m4"
COPY ${zfs_patch} /patches/
RUN cd ${zfs_dir} \
  && quilt new ${zfs_patch} \
  && quilt add ${zfs_to_patch} \
  && patch ${zfs_to_patch} /patches/${zfs_patch} \
  && quilt refresh \
  && quilt pop -a

RUN cd ${zfs_dir} \
  && debuild -i -uc -us
RUN rm -rf ${zfs_dir}

# Remove leftovers from zfs and spl builds
RUN rm -rf *0.7.1*

##### Backports from Vivid before installing any Utopic packages necessary for libvirt
COPY vivid-source-packages.list /etc/apt/sources.list.d/

RUN sudo apt-get update && apt-src install seabios
RUN /scripts/build_backport.sh seabios-1.7.5

RUN sudo rm /etc/apt/sources.list.d/vivid-source-packages.list


##### Backports from Xenial before installing any Utopic packages necessary for libvirt
COPY xenial-source-packages.list /etc/apt/sources.list.d/

## Backport necessary qemu build deps from Xenial

# Shortcut to get libtool-bin which has circular deps with
# automake/autoconf when attempting backport
COPY xenial-binary-packages.list /etc/apt/sources.list.d/
RUN sudo apt-get update && sudo apt-get install -y libtool-bin
RUN sudo rm /etc/apt/sources.list.d/xenial-binary-packages.list

RUN sudo apt-get update && apt-src install libcacard-dev
RUN /scripts/build_backport.sh libcacard-2.5.0
RUN sudo dpkg -i \
  libcacard-dev_2.5.0-2~efs1404+01_amd64.deb \
  libcacard0_2.5.0-2~efs1404+01_amd64.deb

# qemu depends on new libiscsi-dev
RUN sudo apt-get update && apt-src install libiscsi-dev
RUN /scripts/build_backport.sh libiscsi-1.12.0
RUN sudo dpkg -i \
  libiscsi-dev_1.12.0-2~efs1404+01_amd64.deb \
  libiscsi2_1.12.0-2~efs1404+01_amd64.deb

# Install build deps that can be found in Trusty
RUN sudo apt-get update && apt-src install qemu
RUN /scripts/build_backport.sh qemu-2.5+dfsg

# Done backporting qemu from Xenial; remove sources.list so the environment
# stays clean for Utopic backport
RUN sudo rm /etc/apt/sources.list.d/xenial-source-packages.list

COPY utopic-source-packages.list /etc/apt/sources.list.d/
RUN sudo apt-get update && apt-src install libvirt-bin
RUN sudo rm /etc/apt/sources.list.d/utopic-source-packages.list
ARG libvirt="libvirt-1.2.8"

# Apply security updates that never made it into non-LTS Utopic release
ARG libvirt_patch="CVE-2015-5313.patch"
ARG libvirt_to_patch="src/storage/storage_backend_fs.c"
COPY ${libvirt_patch} /patches/
RUN cd ${libvirt} \
  && quilt new ${libvirt_patch} \
  && quilt add ${libvirt_to_patch} \
  && patch ${libvirt_to_patch} /patches/${libvirt_patch} \
  && quilt refresh \
  && quilt pop -a

RUN /scripts/build_backport.sh ${libvirt}


##### Backports from Xenial
COPY xenial-source-packages.list /etc/apt/sources.list.d/

### python-urllib3 1.13.1
RUN sudo apt-get update && sudo aptitude build-depends -y python-urllib3

# urllib3 build deps: python-nose, python3-nose >= 1.3.3
COPY utopic-binary-packages.list /etc/apt/sources.list.d/
RUN sudo apt-get update && sudo aptitude build-depends -y python-urllib3
RUN sudo rm /etc/apt/sources.list.d/utopic-binary-packages.list

RUN sudo apt-get update && apt-src install python-urllib3
RUN /scripts/build_backport.sh python-urllib3-1.13.1

### Python 2.7.12
RUN sudo apt-get update && sudo aptitude build-depends -y python2.7

# python build dep: GCC 5
RUN sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
RUN sudo apt-get update && sudo aptitude build-depends -y python2.7
COPY switch-gcc.sh /script/
RUN sudo /script/switch-gcc.sh 5
RUN sudo rm /etc/apt/sources.list.d/ubuntu-toolchain-r-test-trusty.list

# python build dep: dpkg-dev >= 1.17.11 (cheat by getting binary packages)
COPY utopic-binary-packages.list /etc/apt/sources.list.d/
RUN sudo apt-get update && sudo aptitude build-depends -y python2.7
RUN sudo rm /etc/apt/sources.list.d/utopic-binary-packages.list
########################################################################
# We should avoid building any more packages after this cheat to be safe
########################################################################

RUN sudo apt-get update && apt-src install python2.7
RUN /scripts/build_backport.sh python2.7-2.7.12

VOLUME /out

# Copy build packages to volume
CMD cp -a /build/* /out/
