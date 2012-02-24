Additional Git credential helpers:

## git-credential-netrc

Read-only helper for traditional `~/.netrc`. No advantages over built-in `git-credential-store`. Looks for `machine <protocol>@<host>` and `machine <host>` entries.

## git-credential-lib

Modular helper supporting several backends:

  * **`gnomekeyring`** – GNOME Keyring (using the legacy Python 2 `gnomekeyring` module)

  * **`windows`** – Windows Credential Manager (using PyWin32 modules)

  * **`windows-nogui`** – same as `windows` but does not use GUI prompts
