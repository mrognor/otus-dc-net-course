FROM alpine:3.23

ENV ENV=/root/.rc

RUN echo "root:root" | chpasswd

RUN apk update; \
    apk add \
    vim \
    openssh \
    tcpdump \
    iproute2 \
    supervisor

RUN ssh-keygen -A

COPY images/motd /etc/
COPY images/sshd.ini /etc/supervisor.d/
COPY images/sshd.conf /etc/ssh/sshd_config.d/
