# Terminal Services event monitor for Windows NT/XP/2003/...

## Requirements

 * [PyWin32](http://starship.python.net/crew/mhammond/win32/Downloads.html)

## Usage

1. Edit `events.py` to suit your needs.

2. For a single user:

       wtsmonitor.pyw

    System-wide:

       wtsmonitor-svc.py --startup auto install
       wtsmonitor-svc.py start
       sc query WTSMonitor
