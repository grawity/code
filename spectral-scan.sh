#!/bin/sh -x
# http://blog.altermundi.net/article/playing-with-ath9k-spectral-scan/
# https://github.com/simonwunderlich/FFT_eval

phy=phy0
nif=wlan0

dbg=/sys/kernel/debug/ieee80211/$phy/ath9k
tmp=/tmp/fft_$$

if [ $(id -u) -eq 0 ]; then
	if ! [ -d "$dbg" ]; then
		echo "Missing $dbg" >&2
		exit 1
	fi
	ctl $dbg/spectral_scan_ctl=chanscan
	iw $nif scan
	cat $dbg/spectral_scan0 > "$1"
	ctl $dbg/spectral_scan_ctl=disable
else
	touch "$tmp"
	if sudo "$0" "$tmp" > /dev/null; then
		fft_eval "$tmp"
	fi
fi
