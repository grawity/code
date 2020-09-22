using System;
using System.Net;

class Cidr
{
	static bool ip_in_net(string host, string net)
	{
		string[] tmp = net.Split("/");
		//assert(tmp.Length == 2)

		IPAddress haddr = IPAddress.Parse(host);
		IPAddress naddr = IPAddress.Parse(tmp[0]);
		int plen = Int32.Parse(tmp[1]);

		if (haddr.AddressFamily != naddr.AddressFamily)
			return false;

		byte[] hbyte = haddr.GetAddressBytes();
		byte[] nbyte = naddr.GetAddressBytes();
		int bad = 0;

		if (hbyte.Length != nbyte.Length)
			return false;

		if (plen < 0 || plen > hbyte.Length*8)
			return false;

		for (int i = 0; i < hbyte.Length && plen > 0; i++) {
			int bits = Math.Min(plen, 8);
			int bmask = (0xFF00 >> bits) & 0xFF;
			bad |= (hbyte[i] ^ nbyte[i]) & bmask;
			plen -= 8;
		}

		return (bad == 0);
	}

	static void Main(string[] args)
	{
		string host = args[0];
		string net = args[1];

		if (ip_in_net(host, net)) {
			Console.WriteLine("yes, "+host+" is in network "+net);
		} else {
			Console.WriteLine("no, "+host+" is not in network "+net);
		}
	}
}
