FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Intentionally vulnerable Baron Samedit (CVE-2021-3156) lab.
# DO NOT expose this container outside an isolated training environment.

RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        make \
        libc6-dev \
        ca-certificates \
        sudo=1.8.31-1ubuntu1 \
    && rm -rf /var/lib/apt/lists/* \
    && dpkg -l sudo | grep -q 1.8.31

# Lab user (no sudo privileges required for the exploit)
RUN useradd -m -s /bin/bash lab \
    && echo 'lab:lab' | chpasswd

COPY lab-poc/ /opt/baron-lab/
RUN chown -R lab:lab /opt/baron-lab \
    && chmod 0755 /opt/baron-lab/*.sh 2>/dev/null || true

WORKDIR /home/lab
USER lab

CMD ["/bin/bash"]
