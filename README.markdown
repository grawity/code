1. Edit `wtsmonitor.WTSMonitor.OnSession()` to suit your needs.

2. For a single user:

       wtsmonitor.pyw

    System-wide:

       wtsmonitor.py install --startup auto
       wtsmonitor.py start
       sc query WTSMonitor
