# A stand-in for an EC2 instance (module 9): Amazon Linux 2023, the AMI Module 7's server uses,
# booting systemd with sshd and an ec2-user who may sudo, as cloud-init sets it up on EC2.
# Only for the lab: it runs privileged so systemd and Docker can run inside it.
FROM amazonlinux:2023
RUN dnf install -y -q systemd openssh-server sudo python3 procps-ng iproute hostname \
 && dnf clean all \
 && useradd -m ec2-user \
 && echo 'ec2-user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-ec2-user \
 && chmod 0440 /etc/sudoers.d/90-ec2-user \
 && systemctl enable sshd \
 && systemctl mask systemd-firstboot.service systemd-resolved.service getty@tty1.service
# On EC2, cloud-init puts your key pair's public key in ~/.ssh/authorized_keys. Here the lab's key
# comes from a shared volume (lab-keys), written by the control container.
RUN printf 'AuthorizedKeysFile .ssh/authorized_keys /lab-keys/authorized_keys\n' > /etc/ssh/sshd_config.d/00-lab.conf
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/sbin/init"]
