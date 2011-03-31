#!python
import win32service as svc
import win32serviceutil as svcutil

import wtsmonitor

class WTSMonitorService(svcutil.ServiceFramework):
	_svc_name_ = "WTSMonitor"
	_svc_display_name_ = "Terminal Services event monitor"

	m = None

	def SvcStop(self):
		self.ReportServiceStatus(svc.SERVICE_STOP_PENDING)
		self.m.stop()
		self.ReportServiceStatus(svc.SERVICE_STOPPED)

	def SvcDoRun(self):
		self.m = wtsmonitor.WTSMonitor(all_sessions=True)
		self.m.start()

if __name__ == '__main__':
	svcutil.HandleCommandLine(WTSMonitorService)
