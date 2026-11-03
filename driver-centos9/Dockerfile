# NVIDIA driver container for CentOS Stream 9 nodes.
# NVIDIA publishes no "-centos9" driver image, and the CentOS Stream mirror only keeps the
# newest kernels, so the driver container can't find kernel-devel for the running kernel.
# This takes the Rocky 9 image (same EL9 userland) and adds a local dnf repo with the
# Stream kernel packages from koji for each kernel running on the GPU nodes.
#
#   docker build -t <registry>/nvidia/driver:595.91.07-centos9 driver-centos9
#   docker push <registry>/nvidia/driver:595.91.07-centos9
#
# Add a kernel to KERNELS whenever a GPU node is upgraded to a new one (uname -r).
ARG DRIVER_VERSION=595.91.07
FROM nvcr.io/nvidia/driver:${DRIVER_VERSION}-rocky9

ARG KERNELS="741.el9 754.el9"
ARG KOJI=https://kojihub.stream.centos.org/kojifiles/packages/kernel/5.14.0

RUN dnf install -y createrepo_c \
 && mkdir -p /opt/stream-kernels && cd /opt/stream-kernels \
 && for r in ${KERNELS}; do \
      for p in kernel kernel-core kernel-modules kernel-modules-core kernel-devel kernel-headers; do \
        curl -fsSLO ${KOJI}/${r}/x86_64/${p}-5.14.0-${r}.x86_64.rpm; \
      done; \
    done \
 && createrepo_c . \
 && printf '[stream-kernels]\nname=CentOS Stream 9 kernels\nbaseurl=file:///opt/stream-kernels\nenabled=1\ngpgcheck=0\npriority=1\n' \
      > /etc/yum.repos.d/stream-kernels.repo \
 && dnf clean all
