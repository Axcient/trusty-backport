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

COPY build_backport.sh /scripts/

COPY utopic-source-packages.list /etc/apt/sources.list.d/
RUN sudo apt-get update && apt-src install libvirt-bin
RUN rm /etc/apt/sources.list.d/utopic-source-packages.list
ARG libvirt="libvirt-1.2.8"

# Apply security updates that never made it into non-LTS Utopic release
ARG patch="CVE-2015-5313.patch"
ARG to_patch="src/storage/storage_backend_fs.c"
COPY ${patch} /patches/
RUN cd ${libvirt} \
  && quilt new ${patch} \
  && quilt add ${to_patch} \
  && patch ${to_patch} /patches/${patch} \
  && quilt refresh \
  && quilt pop -a

RUN /scripts/build_backport.sh ${libvirt}

COPY xenial-source-packages.list /etc/apt/sources.list.d/
RUN sudo apt-get update && sudo aptitude build-depends -y python2.7

# GCC 5
RUN sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
RUN sudo apt-get update && sudo aptitude build-depends -y python2.7
COPY switch-gcc.sh /script/
RUN sudo /script/switch-gcc.sh 5
RUN rm /etc/apt/sources.list.d/ubuntu-toolchain-r-test-trusty.list

# dpkg-dev >= 1.17.11
COPY utopic-binary-packages.list /etc/apt/sources.list.d/
RUN sudo apt-get update && sudo aptitude build-depends -y python2.7
RUN rm /etc/apt/sources.list.d/utopic-binary-packages.list

RUN sudo apt-get update && apt-src install python2.7
RUN /scripts/build_backport.sh python2.7-2.7.12

VOLUME /out

# Copy build packages to volume
CMD cp -a /build/* /out/
