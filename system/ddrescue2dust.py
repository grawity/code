#!/usr/bin/env python3
# Convert a ddrescue log to dm-dust badblock list
import sys

BS = 512
dev = "dust1"

# blockdev --getsz /dev/loop0
# dmsetup create dust1 --table '0 488397168 dust /dev/loop0 0 512'
# kpartx -u /dev/mapper/dust1

print(f"dmsetup message {dev} 0 clearbadblocks")

for line in sys.stdin:
    if line.startswith("0x"):
        start_byte, num_bytes, state = line.strip().split()
        if not num_bytes.startswith("0x"):
            # skip 'current' line
            continue
        if state != "-":
            continue
        start_byte = int(start_byte, 16)
        num_bytes = int(num_bytes, 16)
        if start_byte % BS:
            exit(f"start not mod {bs}: {line!r}")
        if num_bytes % BS:
            exit(f"count not mod {bs}: {line!r}")
        start_sector = start_byte // BS
        num_sectors = num_bytes // BS
        print(f"# {start_sector} +{num_sectors}")
        for i in range(num_sectors):
            print(f"dmsetup message {dev} 0 addbadblock {start_sector + i}")

print(f"# end")
print(f"dmsetup message {dev} 0 enable")
