// Iris single-file launcher.
// A tiny host that carries iris.ps1 + iris.ico embedded inside it. On launch it
// drops them into %LOCALAPPDATA%\Iris and starts the script with no console window.
// Compiled by the machine's own csc.exe - no third-party packer, nothing downloaded.
using System;
using System.IO;
using System.Diagnostics;
using System.Reflection;

class IrisLauncher {
    static void Main() {
        string dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Iris");
        Directory.CreateDirectory(dir);

        string ps1 = Path.Combine(dir, "iris.ps1");
        Extract("iris.ps1", ps1);
        Extract("iris.ico", Path.Combine(dir, "iris.ico"));

        var psi = new ProcessStartInfo("powershell.exe",
            "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + ps1 + "\"");
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        Process.Start(psi);
        // Bootstrapper exits immediately; the hidden PowerShell keeps Iris alive.
    }

    static void Extract(string resource, string dest) {
        Assembly asm = Assembly.GetExecutingAssembly();
        using (Stream s = asm.GetManifestResourceStream(resource))
        using (FileStream f = File.Create(dest)) {
            s.CopyTo(f);
        }
    }
}
