# Creation of builder image
# *************************
FROM debian:buster as builder

ENV BUILDROOT_VERSION=2021.08.1

# install needed packages
RUN apt-get update && apt-get install -y \
          python3-pip git wget bzip2 make gcc file g++ patch cpio python unzip rsync bc perl \
          libncurses-dev vim openssh-client libusb-dev libusbredirparser-dev libssl-dev \
          pkg-config zlib1g-dev libglib2.0-dev libpixman-1-dev

# download and prepare buildroot
# (about buildroot.config and kernel.config: see notes.txt)
WORKDIR /root
RUN wget https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.bz2
RUN tar xf buildroot-${BUILDROOT_VERSION}.tar.bz2
RUN mv /root/buildroot-${BUILDROOT_VERSION} /root/buildroot
WORKDIR /root/buildroot
ADD scanpylocal scanpypi utils/
COPY walt-*.tar.gz dl/
ADD update-buildroot.sh .
RUN ./update-buildroot.sh
ADD buildroot.config .config
#ADD qemu.mk package/qemu/qemu.mk
ADD overlay /root/overlay

# compile buildroot
ENV FORCE_UNSAFE_CONFIGURE=1
RUN make source
RUN make toolchain
ADD fix-plumbum-install.sh .
RUN ./fix-plumbum-install.sh
ADD kernel.config kernel.config
RUN make

# download and compile patched qemu
# (we have to install walt software within the target filesystem
#  binfmt_misc may not be available here, so we need a specific qemu-aarch64
#  patched for added option '-execve')
WORKDIR /root
RUN git clone https://github.com/drakkar-lig/qemu-execve.git && \
    cd qemu-execve && \
    git checkout fa9ecbd5523ab967e5d8a2d99afc2b5ee9f538e8 && \
    ./configure --target-list=aarch64-linux-user --static && \
    make -j

# chroot customization image
# **************************
FROM scratch as chroot_image
WORKDIR /
COPY --from=builder /root/buildroot/output/target .
COPY --from=builder /root/qemu-execve/aarch64-linux-user/qemu-aarch64 .
SHELL ["/qemu-aarch64", "-execve", "/bin/sh", "-c"]
ADD chroot-script.sh .
RUN /chroot-script.sh

# Continue with builder image
# ***************************
FROM builder as builder_continued
# restore standard dockerfile RUN command interpreter
SHELL ["/bin/sh", "-c"]
WORKDIR /root/buildroot/output
RUN rm -rf target
COPY --from=chroot_image / target
# cleanup things we needed during the customization step only
RUN rm -rf target/chroot-script.sh target/qemu-aarch64
# run 'make' in buildroot dir again to update final SD card image
WORKDIR /root/buildroot
RUN make

# Creation of final image
# ***********************
# this image will be used to adapt the previously generated SD card image
# (by dynamically adding a conf file on the fat partition), and then dump
# the resulting SD card image on its output.
FROM alpine
RUN apk add mtools util-linux
WORKDIR /root
COPY --from=builder_continued /root/buildroot/output/images/sdcard.img .
ADD dump-image.sh .
ENTRYPOINT ["/root/dump-image.sh"]
