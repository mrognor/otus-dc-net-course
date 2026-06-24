FROM alpine:3.23 AS builder

RUN apk update; \
    apk add \
    git \
    zsh \
    curl

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions; \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting


FROM alpine:3.23

RUN echo "root:root" | chpasswd
RUN sed -i "s/root:x:0:0:root:\/root:\/bin\/sh/root:x:0:0:root:\/root:\/bin\/zsh/" /etc/passwd

RUN apk update; \
    apk add \
    vim \
    zsh \
    lldpd \
    openssh \
    tcpdump \
    iproute2 \
    supervisor

RUN ssh-keygen -A

COPY images/motd /etc/
COPY images/sshd.ini /etc/supervisor.d/
COPY images/sshd.conf /etc/ssh/sshd_config.d/
COPY images/lldpd.ini /etc/supervisor.d.configs/

COPY --from=builder root/.oh-my-zsh /root/.oh-my-zsh
COPY images/.zshrc /root/.zshrc

ENTRYPOINT [ "/bin/zsh" ]