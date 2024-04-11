param(
	[switch] $DryRun,
	[Parameter(ValueFromRemainingArguments)] [string[]] $Package
);

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

if (-not $Package) {
	Write-Error "No packages specified"
	exit 1
}

echo "Indexing provisioned packages..."

$provVersions = @{}

# Note: On my system this only works in PS5, not PS7
Get-AppxProvisionedPackage -Online | % {
	$provVersions[$_.DisplayName] = $_.PackageName
}

# Backup plan:
#$lines = dism /online /get-provisionedappxpackages
#foreach ($line in $lines) {
#	if ($line -match '^DisplayName : (.+)$') {
#		$current = $Matches[1]
#	}
#	if ($line -match '^PackageName : (.+)$') {
#		$provVersions[$current] = $Matches[1]
#	}
#}


$Package | % {
	$base = ($_ -split "_")[0]
	echo "Removing $base"

	# Unprovision first...
	$provPackage = $provVersions[$base]
	if ($provPackage) {
		echo "  -> Provisioned version: $provPackage"
		if (-not $DryRun) {
			#dism /online /remove-provisionedappxpackage /packagename:"$provPackage"
			Remove-AppxProvisionedPackage -Online -PackageName $provPackage

		}
	} else {
		echo "  -> Not provisioned"
	}

	# Then will be able to uninstall for AllUsers.
	$appx = Get-AppxPackage $base -AllUsers
	if ($appx) {
		$appx | % {echo "  -> Installed version: $($_.PackageFullName)"}
		if (-not $DryRun) {
			$appx | Remove-AppxPackage -AllUsers
		}
	} else {
		echo "  -> Not installed"
	}
}
echo "Done."
