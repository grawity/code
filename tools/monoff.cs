/* Utility to turn off the monitor on Windows.
 * csc /t:winexe /optimize /out:"%SystemRoot%\monoff.scr" monoff.cs
 */

using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

class MonOff
{
	private const int HWND_BROADCAST	= 0xffff;
	private const int WM_SYSCOMMAND	= 0x112;
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
		var sc = StringComparison.OrdinalIgnoreCase;
		if (args.Length < 1 || args[0].Equals("/s", sc))
			Power();
		else if (args[0].Equals("/c", sc) || args[0].StartsWith("/c:", sc))
			Configure();
	}

	static void Power()
	{
		SendMessage((IntPtr)HWND_BROADCAST, WM_SYSCOMMAND,
			(IntPtr)SC_MONITORPOWER, (IntPtr)PowerState.Off);
	}
	
	static void Configure()
	{
		MessageBox.Show("This screensaver has no configuration options.");
	}
}