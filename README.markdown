1. Edit `events.py` to suit your needs.

2. For a single user:

       wtsmonitor.pyw

    System-wide:

       wtsmonitor-svc.py install --startup auto
       wtsmonitor-svc.py start
       sc query WTSMonitor
