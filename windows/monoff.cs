/* Utility to turn off the monitor on Windows.
 * csc /t:winexe /o /r:System.dll /r:System.Windows.Forms.dll /out:"%SystemRoot%\monoff.scr" monoff.cs
 */

using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

class MonOff
{
	private const int HWND_BROADCAST	= 0xffff;
	private const int WM_SYSCOMMAND		= 0x112;
	private const int SC_MONITORPOWER	= 0xf170;

	enum PowerState : int
	{
		On = -1,
		Low = 0,
		Off = 2,
	}

	[DllImport("user32.dll", CharSet=CharSet.Unicode)]
	static extern IntPtr SendMessage(IntPtr hWnd, uint Msg,
		IntPtr wParam, IntPtr lParam);

	static void Main(string[] args)
	{
		StringComparison sc = StringComparison.OrdinalIgnoreCase;
		if (args.Length < 1)
			Power(PowerState.Off);
		else if (args[0].Equals("/s", sc))
			Screensaver();
		else if (args[0].StartsWith("/c:", sc))
			Configure();
		else if (args[0].Equals("/off", sc))
			Power(PowerState.Off);
		else if (args[0].Equals("/low", sc))
			Power(PowerState.Low);
		else if (args[0].Equals("/on", sc))
			Power(PowerState.On);
	}

	static void Power(PowerState state)
	{
		using (Form foo = new Form()) {
			SendMessage(foo.Handle, WM_SYSCOMMAND,
				(IntPtr)SC_MONITORPOWER, (IntPtr)state);
		}
	}

	static void Power()
	{
		Power(PowerState.Off);
	}

	static void Screensaver()
	{
		Process scr = new Process();
		scr.StartInfo.FileName = "scrnsave.scr";
		scr.StartInfo.Arguments = "/S";
		scr.StartInfo.UseShellExecute = false;
		scr.StartInfo.CreateNoWindow = true;

		Power(PowerState.Off);
		scr.Start();
		scr.WaitForExit();
	}

	static void Configure()
	{
		MessageBox.Show("This screensaver has no configuration options.");
	}
}
