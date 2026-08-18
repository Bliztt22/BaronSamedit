# Baron Samedit (CVE-2021-3156) — How It Works and How to Reproduce It

## 1. Overview

**Baron Samedit** is a **heap-based buffer overflow** in the `sudo` / `sudoedit`
utility. It was discovered by the Qualys Research Team and disclosed in
January 2021 as **CVE-2021-3156**.

Key properties:

- Any **local unprivileged user** can obtain **root**, even if they are **not**
  listed in `/etc/sudoers` and do **not** know a password.
- Affects sudo **1.8.2 through 1.8.31p2** and **1.9.0 through 1.9.5p1**
  (default configurations).
- Introduced in July 2011; remained exploitable for about ten years.
- Pure **userspace** bug — no special kernel version required (unlike PwnKit
  on modern hosts).

Name origin: “Baron Samedit” is a play on *Baron Samedi* and `sudoedit`.

---

## 2. Background Concepts

### 2.1 sudo and sudoedit

`sudo` runs commands as another user (usually root) according to policy.
`sudoedit` is a mode that edits files as root safely.

Both are typically **SUID-root**:

```text
-rwsr-xr-x 1 root root ... /usr/bin/sudo
```

### 2.2 Heap buffer overflow

A **heap overflow** writes past the end of a buffer allocated on the heap
(dynamic memory via `malloc`). Adjacent heap metadata or objects can be
corrupted. If an attacker controls what is overwritten, they can hijack
control flow or force the process to load a malicious library **while still
running as root**.

### 2.3 NSS (Name Service Switch)

glibc resolves users, hosts, etc. via **NSS**. Configuration in
`/etc/nsswitch.conf` lists services such as `files`, `dns`. Each service can
be backed by a shared library, e.g. `libnss_files.so.2`.

sudo uses NSS while processing arguments. If an attacker can corrupt an
internal NSS structure so that sudo loads **`libnss_x/x.so.2`** from a
path they control, that library’s constructor runs **as root**.

---

## 3. Root Cause

Vulnerable code path (simplified):

When `sudoedit` is invoked in “shell” mode (`-s`) with an argument that
**ends with a single backslash** `\`, sudo fails to properly escape that
backslash while parsing.

Internally it builds a buffer `user_args` on the **heap**. Because of a
logic error in how backslashes are handled:

1. The size calculation undercounts the space needed.
2. The subsequent copy **writes one (or more) bytes past** the allocated
   buffer — a classic heap overflow.

Critical detail from Qualys:

- The bug is reachable **without authentication**.
- It is reachable even for users **not** in sudoers, because the overflow
  happens during early argument processing, before the final policy
  decision rejects the user.

Vulnerability check (no exploit):

```bash
sudoedit -s '\' $(python3 -c 'print("A"*100)')
```

- **Vulnerable**: crash (`malloc(): ...`) or password prompt / hang.
- **Patched**: usage / help text for `sudoedit`.

---

## 4. Exploitation Chain (High Level)

Public reliable exploits (e.g. blasty, CptGibbon) use this strategy:

### Step A — Trigger the overflow with a controlled size

Call:

```text
sudoedit -s <buffer ending with \>
```

Choose the length of the overflowing argument so the heap chunk has a
predictable size (e.g. related to `0xf0` in the educational PoC).

### Step B — Heap Feng-Shui with environment variables

Environment variables such as:

```text
LC_MESSAGES=...
LC_TELEPHONE=...
LC_MEASUREMENT=...
```

are processed by sudo and cause additional heap allocations. By tuning
their lengths, the attacker arranges that a critical object — a
**`service_user`** structure used by NSS — is allocated **just after**
the buffer that will overflow.

### Step C — Overflow into service_user

The overflow overwrites fields of `service_user`, in particular the
**name** of the NSS service to load.

Instead of a legitimate name like `files`, the attacker plants a name
that makes glibc load:

```text
libnss_x/x.so.2
```

from a relative path under the current directory (e.g. `./libnss_x/x.so.2`).

### Step D — Malicious shared library as root

The attacker places a small shared object:

```text
libnss_x/x.so.2
```

with a **constructor** (`__attribute__((constructor))`) that:

1. Calls `setuid(0)` / `setgid(0)`.
2. Executes `/bin/sh`.

When sudo (still euid 0) loads the library, the constructor runs → **root shell**.

### Step E — Result

```text
# id
uid=0(root) gid=0(root) groups=0(root)
```

No password, no sudoers entry required.

---

## 5. Why the Educational PoC Layout Looks Like This

Typical files:

```text
exploit.c          → builds argv/envp and calls sudoedit
shellcode.c        → tiny .so with constructor → setuid + execve /bin/sh
Makefile           → builds libnss_x/x.so.2 and ./exploit
```

Directory after `make`:

```text
.
├── exploit
└── libnss_x/
    └── x.so.2
```

The string `x/x\` in the environment is crafted so that after overflow and
NSS resolution, sudo loads **`libnss_x/x.so.2`**.

---

## 6. Lab Steps (Reproduction)

### 6.1 Start the lab

```bash
cd baron-samedit-lab
sudo docker compose build
sudo docker compose run --rm target
```

You should be user `lab` inside Ubuntu 20.04.

### 6.2 Verify vulnerability

```bash
sudo --version
# Expect: Sudo version 1.8.31

sudoedit -s Y
# Vulnerable: password prompt or error other than clean usage text
# Patched: prints sudoedit usage and exits
```

### 6.3 Build and run the exploit

```bash
cd /opt/baron-lab
make clean && make
./exploit
id
```

Expected:

```text
[*] CVE-2021-3156 Baron Samedit — triggering sudoedit …
# id
uid=0(root) gid=0(root) groups=0(root)
```

### 6.4 Cleanup

```bash
exit
sudo docker compose down
```

---

## 7. Comparison with PwnKit (CVE-2021-4034)

| Aspect | Baron Samedit (CVE-2021-3156) | PwnKit (CVE-2021-4034) |
|--------|-------------------------------|-------------------------|
| Component | `sudo` / `sudoedit` | `pkexec` (polkit) |
| Bug type | Heap buffer overflow | Out-of-bounds argv/envp + GCONV |
| Privilege needed | Local user only | Local user only |
| Auth required | No | No |
| Kernel dependent | No | Yes (`argc==0` blocked since 5.18) |
| Lab style | Simple Docker | QEMU/VM on modern hosts |
| Disclosure | Jan 2021 | Jan 2022 |

Both are flagship **local privilege escalation** cases from the same era and
are excellent for understanding SUID helpers, memory corruption, and
library loading as root.

---

## 8. Remediation

1. **Update sudo** to a fixed version (e.g. ≥ 1.9.5p2, or the distro
   backports such as Ubuntu `1.8.31-1ubuntu1.2` on 20.04).
2. Confirm with:

   ```bash
   sudoedit -s Y
   # Should print usage, not prompt/crash in the vulnerable way
   ```

3. Temporary hardening is limited; patching is the real fix. Reducing
   SUID surface helps in general but does not replace updating sudo.

---

## 9. Summary of the Attack Flow

```text
1. Attacker runs sudoedit -s with an argument ending in '\'
2. sudo undercounts buffer size → heap overflow in user_args
3. LC_* environment variables place service_user after that buffer
4. Overflow corrupts service_user name → points at attacker NSS module
5. sudo (euid 0) loads ./libnss_x/x.so.2
6. Constructor: setuid(0) + execve("/bin/sh")
7. Root shell
```

That is the full path from an unprivileged shell to root via a decade-old
heap overflow in one of the most common privilege-switching tools on Linux.
