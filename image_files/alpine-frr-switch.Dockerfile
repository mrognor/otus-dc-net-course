FROM alpine:3.23

ENV ENV=/root/.rc

RUN echo "root:root" | chpasswd

RUN apk update; \
    apk add \
    frr \
    vim \
    openssh \
    tcpdump \
    supervisor

RUN ssh-keygen -A

COPY image_files/init.sh /
COPY image_files/motd /etc/
COPY image_files/.rc /root/
COPY image_files/frr.ini /etc/supervisor.d/
COPY image_files/sshd.ini /etc/supervisor.d/
COPY image_files/sshd.conf /etc/ssh/sshd_config.d/

ENTRYPOINT ["/bin/ash", "-c", "/init.sh; /bin/ash"]
