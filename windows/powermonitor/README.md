# Power event monitor service

## Requirements

 * [PyWin32](http://starship.python.net/crew/mhammond/win32/Downloads.html)

## Installation:

 1. Copy `actions.py.example` to `actions.py` and edit according to your needs.

 2. Install and start the service:

       powermonitor.py --startup auto install
       powermonitor.py start

The `actions.py` file will be reloaded every time.
