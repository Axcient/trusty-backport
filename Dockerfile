FROM ubuntu:trusty

# Set locale to fix character encoding
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192

ENV DEBIAN_FRONTEND=noninteractive

# Copy Xenial sources to Trusty system
COPY xenial-source-packages.list /etc/apt/sources.list.d/xenial-sources.list

# Install dependencies and utilities
RUN apt-get update && apt-get install -y \
  apt-src \
  devscripts \
  debian-keyring \
  less \
  vim 
#  software-properties-common

WORKDIR /build

######################################################
# Pre-dep round 1: gettext (dpkg-dev dependency)
######################################################

RUN apt-src --build install gettext
RUN apt-get install -y emacs
RUN dpkg --purge --force-depends libasprintf0c2
RUN dpkg -i *.deb && rm -rf *

######################################################
# Pre-dep round 2: devscripts (dpkg-dev dependency)
######################################################

RUN apt-src install devscripts

# Remove some tests whose failures appear to be safe
ARG dsdir="devscripts-2.16.2ubuntu3"
RUN rm \
  ${dsdir}/test/test_package_lifecycle \
  ${dsdir}/test/test_mk-origtargz
ARG dstest="${dsdir}/test/Makefile"
RUN grep -v "mk-origtargz" ${dstest} > ${dstest}.new
RUN grep -v "package_lifecycle" ${dstest}.new > ${dstest}

# Remove attempt to check python scripts with flake8 which fails for unknown reasons
ARG dsmake="${dsdir}/scripts/Makefile"
RUN grep -v "python3 -m flake8" ${dsmake} > ${dsmake}.new
RUN mv ${dsmake}.new ${dsmake}

RUN cd ${dsdir} && debuild -i -uc -us -b
RUN dpkg -i devscripts_2.16.2ubuntu3_amd64.deb

RUN rm -rf *

######################################################
# Pre-dep round 3: dpkg-dev
######################################################

# manually install build deps
RUN apt-get update && apt-get install -y \
  debhelper \
  pkg-config \
  flex \
  po4a \
  zlib1g-dev \
  libbz2-dev \
  liblzma-dev \
  libselinux1-dev \
  libncursesw5-dev \
  wget

RUN wget https://launchpad.net/ubuntu/+archive/primary/+files/dpkg_1.18.1ubuntu1.tar.xz
RUN wget https://launchpad.net/ubuntu/+archive/primary/+files/dpkg_1.18.1ubuntu1.dsc
RUN dpkg-source -x dpkg_1.18.1ubuntu1.dsc
RUN cd dpkg-1.18.1ubuntu1 && debuild -i -uc -us -b
RUN dpkg -i \
  dpkg-dev_1.18.1ubuntu1_all.deb \
  libdpkg-perl_1.18.1ubuntu1_all.deb \
  && rm -rf *
# dpkg_*.deb

######################################################
# Pre-dep round 4: libgmp (nettle dependency)
######################################################

# Install GCC 4.9 and switch to it (this could go above)
RUN apt-get update && apt-get install -y \
  software-properties-common
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test
RUN apt-get update && apt-get install -y \
  gcc-4.9 \
  g++-4.9
RUN add-apt-repository -y --remove ppa:ubuntu-toolchain-r/test
COPY switch-gcc.sh /script/
RUN /script/switch-gcc.sh 4.9

# `apt-src --installdebs` doesn't work here because of weirdness in the
# real vs. expected naming of .changes files with an epoch in the version
RUN apt-src --build install libgmp-dev
RUN dpkg -i \
  libgmp-dev_6.1.0+dfsg-2_amd64.deb \
  libgmp10_6.1.0+dfsg-2_amd64.deb \
  libgmpxx4ldbl_6.1.0+dfsg-2_amd64.deb \
  && rm -rf *

######################################################
# Pre-dep round 5: debhelper and dpkg (interdependent)
######################################################

## Override dependencies of new debhelper package:
## It depends on newer dpkg-dev for building ddebs, which we'll never do,
## but in any case we're about to install the newer dpkg-dev next
RUN apt-src install debhelper
ARG dhdir="debhelper-9.20160115ubuntu3"
RUN sed -i "s/dpkg-dev (>= 1.18.2~)/dpkg-dev (>= 1.17.0)/" ${dhdir}/debian/control
RUN cd ${dhdir} && debuild -i -uc -us -b
RUN apt-get update && apt-get install -y \
  autotools-dev
RUN apt-src --installdebs install dh-strip-nondeterminism
RUN dpkg -i \
  debhelper_9.20160115ubuntu3_all.deb \
  && rm -rf *

######################################################
# Pre-dep round 6
######################################################

RUN apt-src --build install nettle-dev
RUN dpkg -i \
  nettle-dev_*.deb \
  libnettle6_*.deb \
  libhogweed4_*.deb \
  && rm -rf *
RUN apt-src --build install libtasn1-6-dev
RUN dpkg -i \
  libtasn1-6-dev_*.deb \
  libtasn1-6_*.deb \
  && rm -rf *
RUN apt-src --build install libidn11-dev
RUN dpkg -i \
  libidn11-dev_*.deb \
  libidn11_*.deb \
  && rm -rf *
RUN apt-src --build install librtmp-dev
RUN dpkg -i \
  librtmp-dev_*.deb \
  librtmp1_*.deb \
  && rm -rf *

# Some tests fail during build if you try to build as root.
# TODO: Go ahead and do it all as a user
RUN apt-get update && apt-get install -y sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN useradd --user-group builder
RUN adduser builder sudo
RUN mkdir -p /home/builder
RUN chown -R builder:builder /home/builder
RUN chown -R builder:builder /build
USER builder
RUN mkdir -p ~/.apt-src
RUN apt-src --build install libp11-kit-dev
RUN sudo dpkg -i \
  libp11-kit-dev_*.deb \
  libp11-kit0_*.deb \
  && rm -rf *

# Must build this before libcurl4 (and possibly before other stuff)
# to avoid stupid dependancy problems
RUN apt-src --build install gnutls28
RUN sudo apt-get remove -y \
  libhogweed2 \
  libnettle4
RUN sudo dpkg -i \
  libgnutls28-dev_*.deb \
  libgnutls-dev_*.deb \
  libgnutls30_*.deb \
  libgnutls-openssl27_*.deb \
  libgnutlsxx28_*.deb \
  && rm -rf *
RUN apt-src --build install librtmp-dev
RUN sudo dpkg -i \
  librtmp-dev_*.deb \
  librtmp1_*.deb \
  && rm -rf *
RUN apt-src --build install libcurl4-gnutls-dev
RUN sudo dpkg -i \
  libcurl4-gnutls-dev_*.deb \
  libcurl3-gnutls_*.deb \
  && rm -rf *
RUN apt-src --build install libxml2-dev
RUN sudo dpkg -i \
  libxml2-dev_*.deb \
  libxml2_*.deb \
  && rm -rf *

RUN apt-src install dh-systemd
# Fix build dep - perl:any is not a thing in Trusty
ARG initdir="init-system-helpers-1.29ubuntu4"
RUN sed -i "s/perl:any/perl/" ${initdir}/debian/control
RUN cd ${initdir} && debuild -i -uc -us -b
RUN sudo dpkg -i \
  dh-systemd_*.deb \
  && rm -rf *

RUN apt-src --build install libcap-dev
RUN sudo dpkg -i \
  libcap-dev_*.deb \
  libcap2_*.deb \
  && rm -rf *
RUN apt-src --build install bats
RUN sudo dpkg -i \
  bats_*.deb \
  && rm -rf *
RUN apt-src --build install dh-exec
RUN sudo dpkg -i \
  dh-exec_*.deb \
  && rm -rf *

# Temporarily copy Xenial binary sources to Trusty system
RUN sudo apt-get update && sudo apt-get install -y \
  aptitude
RUN sudo apt-get update && sudo aptitude build-dep -y \
  zfsutils-linux \
  libvirt-bin

COPY xenial-binary-packages.list /etc/apt/sources.list.d/xenial-binary-packages.list

RUN apt-src install --build zfsutils-linux
RUN sudo apt-get update && sudo apt-get install -y \
  init-system-helpers
RUN sudo dpkg -i \
  zfsutils-linux_*.deb \
  zfs-doc_*.deb \
  libnvpair1linux_0.6.5.6-0ubuntu18_amd64.deb \
  libuutil1linux_0.6.5.6-0ubuntu18_amd64.deb \
  libzfs2linux_0.6.5.6-0ubuntu18_amd64.deb \
  libzpool2linux_0.6.5.6-0ubuntu18_amd64.deb \
  && rm -rf *

RUN sudo rm -f /etc/apt/sources.list.d/xenial-binary-packages.list

# Fix broken apt
RUN wget http://security.ubuntu.com/ubuntu/pool/main/g/gcc-5/libstdc++6_5.4.0-6ubuntu1~16.04.4_amd64.deb
RUN wget http://security.ubuntu.com/ubuntu/pool/main/g/gcc-5/gcc-5-base_5.4.0-6ubuntu1~16.04.4_amd64.deb
RUN sudo dpkg -i \
  libstdc++6_5.4.0-6ubuntu1~16.04.4_amd64.deb \
  gcc-5-base_5.4.0-6ubuntu1~16.04.4_amd64.deb \
  && rm -rf *

RUN sudo apt-get update && sudo aptitude build-dep -y \
  libvirt-bin
COPY xenial-binary-packages.list /etc/apt/sources.list.d/xenial-binary-packages.list
RUN sudo apt-get update && sudo apt-get install -y \
  binutils
RUN sudo apt-get update && apt-src install libvirt-bin

# Set name and email that will appear in changelog entries
ARG name="Backport Builder"
ARG email="nowhere@example.com"
ARG version="backport"
ARG distribution="trusty"
ENV NAME=${name}
ENV EMAIL=${email}
ENV VERSION=${version}
ENV DISTRIBUTION=${distribution}

COPY build_backport.sh /build
# Skip tests for xml parsing of xen stuff...
# if it's really broken we shouldn't notice before switching to upstream
ARG lvtest="tests/xlconfigtest.c"
RUN cd libvirt-1.3.1 \
  && quilt new remove-borked-test.patch \
  && quilt add ${lvtest} \
  && grep -vE \
    'DO_TEST\("(new-disk|spice|spice-features|vif-rate|fullvirt-multiusb)"\)' \
    ${lvtest} \
  > ${lvtest}.new \
  && mv ${lvtest}.new ${lvtest} \
  && quilt refresh
RUN ./build_backport.sh libvirt-1.3.1
RUN sudo rm -f /etc/apt/sources.list.d/xenial-binary-packages.list && sudo apt-get update

VOLUME /out

# Copy build packages to volume
CMD cp -a /build/* /out/
