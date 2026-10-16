param([Parameter(Mandatory)][string]$Directory)
$ErrorActionPreference='Stop'
# COM kaydını değiştirmeden gerçek DLL üzerinden DirectShow filtre nesnesi oluşturur.
Add-Type @'
using System;
using System.Runtime.InteropServices;
[ComImport, Guid("00000001-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface CaptureClassFactory {
    [PreserveSig] int CreateInstance(IntPtr outer, ref Guid iid, out IntPtr instance);
    [PreserveSig] int LockServer(bool value);
}
public static class CaptureProbe {
    [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr LoadLibrary(string path);
    [DllImport("kernel32", CharSet=CharSet.Ansi)] static extern IntPtr GetProcAddress(IntPtr module,string name);
    [DllImport("kernel32")] static extern bool FreeLibrary(IntPtr module);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetClassObject(ref Guid clsid, ref Guid iid, out IntPtr factory);
    public static void Check(string path,string clsid) {
        var module=LoadLibrary(path); if(module==IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        try {
            var address=GetProcAddress(module,"DllGetClassObject"); if(address==IntPtr.Zero) throw new Exception("DllGetClassObject missing");
            var call=(GetClassObject)Marshal.GetDelegateForFunctionPointer(address,typeof(GetClassObject));
            var id=new Guid(clsid); var factoryId=new Guid("00000001-0000-0000-C000-000000000046"); IntPtr factory;
            Marshal.ThrowExceptionForHR(call(ref id,ref factoryId,out factory));
            var instance=(CaptureClassFactory)Marshal.GetObjectForIUnknown(factory); Marshal.Release(factory);
            try {
                var iid=new Guid("56A86895-0AD4-11CE-B03A-0020AF0BA770"); IntPtr filter;
                Marshal.ThrowExceptionForHR(instance.CreateInstance(IntPtr.Zero,ref iid,out filter));
                if(filter==IntPtr.Zero) throw new Exception("IBaseFilter missing"); Marshal.Release(filter);
            } finally {Marshal.FinalReleaseComObject(instance);}
        } finally {FreeLibrary(module);}
    }
}
'@
$is64=[Environment]::Is64BitProcess
if($is64){$video='screen-capture-recorder-x64.dll';$videoId='4ea69364-2c8a-4ae6-a561-56e4b5044439';$audio='audio_sniffer-x64.dll';$audioId='8e146464-db61-4309-afa1-3578e927e935'}
else{$video='screen-capture-recorder.dll';$videoId='4ea6930a-2c8a-4ae6-a561-56e4b5044439';$audio='audio_sniffer.dll';$audioId='8e14549b-db61-4309-afa1-3578e927e935'}
[CaptureProbe]::Check((Join-Path $Directory $video),$videoId)
Write-Output "PASS DirectShow IBaseFilter: $video"
[CaptureProbe]::Check((Join-Path $Directory $audio),$audioId)
Write-Output "PASS DirectShow IBaseFilter: $audio"
