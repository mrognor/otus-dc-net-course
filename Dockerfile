FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes

COPY sshd.conf /etc/ssh/sshd_config.d/
COPY init.sh /

RUN echo "root:root" | chpasswd

RUN apt update; \
    apt upgrade -y; \
    apt install -y \
    inetutils-ping \
    iproute2 \
    ssh \
    vim \
    frr

ENTRYPOINT ["/bin/bash", "-c", "/init.sh; /bin/bash"]
