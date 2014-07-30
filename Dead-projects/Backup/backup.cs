using System;
using System.IO;
using System.Text;

class BackupJob
{
	static string sourceRoot;
	static string destRoot;

	static int Main(string[] argv)
	{
		sourceRoot = @"C:\Documents and Settings\Mantas";
		destRoot = @"C:\Temp\Testing Backup";
		DirectoryInfo di = new DirectoryInfo(sourceRoot);
		try {
			WalkTree(di);
		}
		catch (Exception e) {
			Console.WriteLine(e);
		}
		return 0;
	}

	static void WalkTree(DirectoryInfo di)
	{
		string name = RelativePath(di.FullName, sourceRoot);
		Console.WriteLine("traverse: {0}", name);
		
		foreach (DirectoryInfo fsi in di.GetDirectories()) {
			if (fsi.HasAttribute(FileAttributes.ReparsePoint)) {
				Console.WriteLine("skip (reparse): {0}", name);
				continue;
			}
			WalkTree(fsi);
		}
		
		foreach (FileInfo fsi in di.GetFiles()) {
			BackupFile(fsi);
		}
	}
	
	static void BackupFile(FileInfo fsi)
	{
		string name = RelativePath(fsi.FullName, sourceRoot);
		Console.WriteLine("reach: {0}", name);
		
		BackupState bs = new BackupState(fsi);
	}

	static string RelativePath(string absPath, string rootPath)
	{
		char[] separators = { '\\' };
		string[] absItems = absPath.Split(separators);
		string[] rootItems = rootPath.Split(separators);
		int length = Math.Min(absItems.Length, rootItems.Length);
		int lastCommon = -1;

		for (int i = 0; i < length; i++)
			if (absItems[i] == rootItems[i])
				lastCommon = i;
			else
				break;

		if (lastCommon == -1)
			throw new ArgumentException("Paths do not have a common base: \"" + \
					absPath + "\", \"" + rootPath + "\"");

		StringBuilder relPath = new StringBuilder();

		for (int i = lastCommon+1; i < rootItems.Length; i++)
			if (rootItems[i].Length > 0)
				relPath.Append("..\\");

		for (int i = lastCommon+1; i < absItems.Length-1; i++)
			relPath.Append(absItems[i] + "\\");

		if (absItems.Length == rootItems.Length && relPath.Length == 0)
			relPath.Append(".");
		else
			relPath.Append(absItems[absItems.Length-1]);

		return relPath.ToString();
	}
}

class BackupJobState
{
}

class BackupState
{
	public string		Name;
	public DateTime		LastWriteTime;
	public DateTime		CreationTime;
	public long		Length;
	public FileAttributes	Attributes;
	//public DateTime?	LastBackupTime;
	public bool		ExistsLocally = false;
	
	public bool IsDirectory
	{
		get { return Attributes.HasAttribute(FileAttributes.Directory); }
	}
	
	public string PhysicalName
	{
		get { return Attributes.HasAttribute(FileAttributes.Encrypted) ? Name+".#EFS#" : Name; }
	}
	
	public BackupState()
	{
	}
	
	public BackupState(FileSystemInfo fsi)
	{
		this.Name = fsi.FullName;
		this.Attributes = fsi.Attributes;
		this.CreationTime = fsi.CreationTimeUtc;
		this.LastWriteTime = fsi.LastWriteTimeUtc;
		if (!this.IsDirectory) {
			this.Length = ((FileInfo)fsi).Length;
		}
	}
	
	public BackupState(FileSystemInfo fsi, string? rootDir)
	{
		this.Name = BackupJob.RelativePath(fsi.FullName, rootDir);
	}
	
	public string ToString()
	{
		return Name;
		/*
		st.WriteLine("{0:d} ({1}) {2:d} {3:o} {4:o} {5}",
			(uint)f.Attributes,
			FileIO.AttributesToString(f.Attributes),
			f.Length,
			f.CreationTime,
			f.LastWriteTime,
			NormPath(f.Name));
		*/
	}
}

class FileIO
{
}

static class FileSystemInfoExtensions {
	public static bool HasAttribute(this FileSystemInfo fsi, FileAttributes attr) {
		return (fsi.Attributes & attr) == attr;
	}
}

static class FileAttributesExtensions {
	public static bool Has(this FileAttributes attrset, FileAttributes attr) {
		return (attrset & attr) == attr;
	}

	public static string ToString(this FileAttributes fa)
	{
		string str = "";
		if ((fa & FileAttributes.ReadOnly) != 0)		str += "r";
		if ((fa & FileAttributes.Hidden) != 0)			str += "h";
		if ((fa & FileAttributes.System) != 0)			str += "s";
		if ((fa & FileAttributes.Directory) != 0)		str += "d";
		if ((fa & FileAttributes.Archive) != 0)			str += "a";
		if ((fa & FileAttributes.Device) != 0)			str += "D";
		if ((fa & FileAttributes.Temporary) != 0)		str += "t";
		if ((fa & FileAttributes.SparseFile) != 0)		str += "S";
		if ((fa & FileAttributes.ReparsePoint) != 0)		str += "R";
		if ((fa & FileAttributes.Compressed) != 0)		str += "c";
		if ((fa & FileAttributes.Offline) != 0)			str += "o";
		if ((fa & FileAttributes.NotContentIndexed) != 0)	str += "I";
		if ((fa & FileAttributes.Encrypted) != 0)		str += "e";
		if (str.Length == 0)
			str = "-";
		return str;
	}

	public static FileAttributes FromString(string str)
	{
		if (str[0] >= '0' && str[0] <= '9')
		{
			return (FileAttributes)Convert.ToUInt32(str);
		}
		else
		{
			FileAttributes fa = new FileAttributes();
			foreach (char c in str)
			{
				switch (c)
				{
					case 'r': fa |= FileAttributes.ReadOnly;		break;
					case 'h': fa |= FileAttributes.Hidden;			break;
					case 's': fa |= FileAttributes.System;			break;
					case 'd': fa |= FileAttributes.Directory;		break;
					case 'a': fa |= FileAttributes.Archive;			break;
					case 'D': fa |= FileAttributes.Device;			break;
					case 't': fa |= FileAttributes.Temporary;		break;
					case 'S': fa |= FileAttributes.SparseFile;		break;
					case 'R': fa |= FileAttributes.ReparsePoint;		break;
					case 'c': fa |= FileAttributes.Compressed;		break;
					case 'o': fa |= FileAttributes.Offline;			break;
					case 'I': fa |= FileAttributes.NotContentIndexed;	break;
					case 'e': fa |= FileAttributes.Encrypted;		break;
				}
			}
			return fa;
		}
	}
}