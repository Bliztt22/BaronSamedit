#!/bin/bash
set -e
cd "$(dirname "$0")"
make clean
make
echo "[*] Running exploit …"
./exploit
