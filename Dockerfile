# Creation of builder image
# *************************
FROM debian:bookworm as builder

ENV BUILDROOT_VERSION=2024.05

# install needed packages
RUN apt-get update && apt-get install -y \
          python3-pip git wget bzip2 make gcc file g++ patch cpio unzip rsync bc perl \
          libncurses-dev vim openssh-client libusb-dev libusbredirparser-dev libssl-dev \
          pkg-config zlib1g-dev libglib2.0-dev libpixman-1-dev python3-tomli python3-six

# download and prepare buildroot
# (about buildroot.config and kernel.config: see notes.txt)
WORKDIR /root
RUN wget https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.xz
RUN tar xf buildroot-${BUILDROOT_VERSION}.tar.xz
RUN mv /root/buildroot-${BUILDROOT_VERSION} /root/buildroot
WORKDIR /root/buildroot
ADD scanpylocal utils/
COPY walt*.tar.gz dl/
ADD update-buildroot.sh ./
RUN ./update-buildroot.sh
ADD buildroot.config .config
ADD overlay /root/overlay

# compile buildroot
ENV FORCE_UNSAFE_CONFIGURE=1
RUN make source
RUN make toolchain
ADD kernel.config kernel.config
RUN make

# chroot customization image
# **************************
FROM --platform=linux/arm64/v8 scratch as chroot_image
WORKDIR /
COPY --from=builder /root/buildroot/output/target .
ADD chroot-script.sh .
RUN /chroot-script.sh

# Continue with builder image
# ***************************
FROM builder as builder_continued
WORKDIR /root/buildroot/output
RUN rm -rf target
COPY --from=chroot_image / target
# cleanup things we needed during the customization step only
RUN rm -rf target/chroot-script.sh
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
