# Creation of builder image
# *************************

# install needed packages
FROM debian:buster as builder
RUN apt-get update && apt-get install -y \
          python3-pip git wget bzip2 make gcc file g++ patch cpio python unzip rsync bc perl \
          libncurses-dev vim openssh-client libusb-dev libusbredirparser-dev libssl-dev \
          pkg-config zlib1g-dev libglib2.0-dev libpixman-1-dev

# download and prepare buildroot
# (about buildroot.config and kernel.config: see notes.txt)
WORKDIR /root
RUN wget https://buildroot.org/downloads/buildroot-2019.08.tar.bz2
RUN tar xf buildroot-2019.08.tar.bz2
WORKDIR /root/buildroot-2019.08
ADD update-buildroot.sh .
RUN ./update-buildroot.sh
ADD buildroot.config .config
ADD kernel.config kernel.config
ADD qemu.mk package/qemu/qemu.mk
ADD overlay /root/overlay

# compile buildroot
ENV FORCE_UNSAFE_CONFIGURE=1
RUN make source
RUN make toolchain
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

# get walt-python-package repo ready at [rootfs]/root/walt-python-packages
WORKDIR /root/buildroot-2019.08/output/target/root
RUN git clone https://github.com/drakkar-lig/walt-python-packages
RUN cd walt-python-packages && git fetch origin walt-vpn && git checkout 0e7f7dc46d5a37102055f1a1aba637ef1dfaadba

# chroot customization image
# **************************
FROM scratch as chroot_image
WORKDIR /
COPY --from=builder /root/buildroot-2019.08/output/target .
COPY --from=builder /root/qemu-execve/aarch64-linux-user/qemu-aarch64 .
SHELL ["/qemu-aarch64", "-execve", "/bin/sh", "-c"]
ADD chroot-script.sh .
RUN /chroot-script.sh

# Continue with builder image
# ***************************
FROM builder as builder_continued
# restore standard dockerfile RUN command interpreter
SHELL ["/bin/sh", "-c"]
WORKDIR /root/buildroot-2019.08/output
RUN rm -rf target
COPY --from=chroot_image / target
# cleanup things we needed during the customization step only
RUN rm -rf target/chroot-script.sh target/qemu-aarch64 target/root/walt-python-packages
# run 'make' in buildroot dir again to update final SD card image
WORKDIR /root/buildroot-2019.08
RUN make

# Creation of final image
# ***********************
# this image will be used to adapt the previously generated SD card image
# (by dynamically adding a conf file on the fat partition), and then dump
# the resulting SD card image on its output.
FROM alpine
RUN apk add mtools util-linux
WORKDIR /root
COPY --from=builder_continued /root/buildroot-2019.08/output/images/sdcard.img .
ADD dump-image.sh .
ENTRYPOINT ["/root/dump-image.sh"]
