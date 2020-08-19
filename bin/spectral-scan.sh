#!/bin/sh -x
# http://blog.altermundi.net/article/playing-with-ath9k-spectral-scan/
# https://github.com/simonwunderlich/FFT_eval

phy=phy0
dev=wlan0

dbg=/sys/kernel/debug/ieee80211/$phy/ath9k
tmp=/tmp/fft_$$

if [ $(id -u) -eq 0 ]; then
	if ! [ -d "$dbg" ]; then
		echo "Missing $dbg, you need CONFIG_ATH9K_DEBUGFS=y" >&2
		exit 1
	fi
	echo 'chanscan' > $dbg/spectral_scan_ctl
	iw $dev scan
	cat $dbg/spectral_scan0 > "$1"
	echo 'disable' > $dbg/spectral_scan_ctl
else
	touch "$tmp"
	if sudo "$0" "$tmp" > /dev/null; then
		(cd ~/src/misc/FFT_eval && ./fft_eval "$tmp")
		#(cd ~/src/misc/ath_spectral/UI &&
		# LD_LIBRARY_PATH=qwt/lib athScan/athScan "$tmp")
	fi
fi
