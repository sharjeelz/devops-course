# Your machine, as far as Ansible is concerned (module 9): Python, ansible-core, ansible-lint and
# an SSH client. Ansible's control node runs on Linux and macOS (on Windows: WSL, or this image).
FROM python:3.13-slim
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends openssh-client curl \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir -q ansible-core==2.21.5 ansible-lint==26.10.1
# The lab's key and known hosts live on the keys volume, so they survive rebuilding this image.
COPY ssh_config /etc/ssh/ssh_config.d/lab.conf
ENV ANSIBLE_CONFIG=/linkly/ansible/ansible.cfg
WORKDIR /linkly/ansible
CMD ["sleep", "infinity"]
