#!/bin/bash
set -e

# https://gist.github.com/tianon/b7fce03f0d52f8103242421878fc6b5e

#
# usage:
#
#   $ apt-mark-minimum-manual.sh
#   inetutils-ping
#   iproute2
#
#   $ apt-mark showmanual | xargs -r sudo apt-mark auto
#   ...
#   $ apt-mark-minimum-manual.sh | xargs -r sudo apt-mark manual
#   ...
#   $ sudo apt-get purge --auto-remove
#   ...
#   0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
#   $ apt-mark showmanual
#   inetutils-ping
#   iproute2
#

IFS=$'\n'
packages=( $(
	{
		apt-mark showauto
		apt-mark showhold
		apt-mark showmanual
	} | sort -u
) )
unset IFS

declare -A revdeps=(
	# apt is neither essential nor required
	# apt is just nice enough not to remove itself
	# and is how debootstrap works, so debootstrap kindly installs it for us
	[apt]='apt'
)
for pkg in "${packages[@]}"; do
	IFS=$'\n'
	# TODO decide if Recommends is appropriate for us to assume here (or whether we should double-check apt.conf for "install recommends" setting)
	depends=( $(dpkg-query -s "$pkg" | awk -F ' *[:,|] +' '
		$1 == "Depends" || $1 == "Pre-Depends" || $1 == "Recommends" {
			gsub(/ *, */, "\n");
			for (i = 2; i <= NF; ++i) {
				print $i
			}
		}
		$1 == "Priority" && $2 == "required" {
			print "REQUIRED"
		}
		#$1 == "Essential" && $2 == "yes" {
		#	print "ESSENTIAL"
		#}
	') )
	unset IFS

	for depend in "${depends[@]}"; do
		depend="${depend%% *}" # trim off constraints (version, etc)
		case "$depend" in
			REQUIRED|ESSENTIAL)
				[ -z "${revdeps[$pkg]}" ] || revdeps[$pkg]+=' '
				revdeps[$pkg]+="$depend"
				;;
			*)
				[ -z "${revdeps[$depend]}" ] || revdeps[$depend]+=' '
				revdeps[$depend]+="$pkg"
				;;
		esac
	done
done
for pkg in "${packages[@]}"; do
	[ -z "${revdeps[$pkg]}" ] || continue
	echo "$pkg"
done
