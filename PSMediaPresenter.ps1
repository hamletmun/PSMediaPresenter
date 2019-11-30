<#
    https://docs.microsoft.com/en-us/dotnet/api/system.windows.window
    https://docs.microsoft.com/en-us/dotnet/api/system.windows.media.mediaplayer

    http://mostlytech.blogspot.com/2008/01/maximizing-wpf-window-to-second-monitor.html
#>

<# Manual
$AllScreens = [Collections.ArrayList]@(
    @{DeviceName='\\.\DISPLAY1'; WorkingArea=@{left=0;top=0}},
    @{DeviceName='\\.\DISPLAY2'; WorkingArea=@{left=1920;top=0}}
)
#>

<# WinForms
Add-Type -AssemblyName System.Windows.Forms
$AllScreens = [Windows.Forms.Screen]::AllScreens
#>

# Platform Invoke
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace Win32 {

    [StructLayout(LayoutKind.Sequential)]
    public struct Rect
    {
        public int left;
        public int top;
        public int right;
        public int bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct MONITORINFOEX
    {
        public int Size;
        public Rect Monitor;
        public Rect WorkArea;
        public uint Flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string DeviceName;
    }

    public class NativeMethods
    {
        public delegate bool MonitorEnumDelegate(IntPtr hMonitor, IntPtr hdcMonitor, ref Rect lprcMonitor, IntPtr dwData);

        [DllImport("user32.dll")]
        public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumDelegate lpfnEnum, IntPtr dwData);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX lpmi);
    }
}
"@

$MonitorEnum = {
    # Write-Host "Monitor: $args"
    $mi = New-Object Win32.MONITORINFOEX
    $mi.Size = [Runtime.InteropServices.Marshal]::SizeOf($mi)
    [Win32.NativeMethods]::GetMonitorInfo($args[0], [ref]$mi)
    $screen = New-Object PSObject -Property @{
        DeviceName = $mi.DeviceName
        WorkingArea = $mi.Monitor
    }
    $AllScreens.Add($screen)
    Return $True
}

$AllScreens = [Collections.ArrayList]@()
[void][Win32.NativeMethods]::EnumDisplayMonitors(0, 0, $MonitorEnum, 0)
#>

Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="PowerShell Media Presenter"
    WindowStartupLocation="CenterScreen"
    Width="640" Height="240"
    MinWidth="240" MinHeight="120">

    <DockPanel>
        <WrapPanel DockPanel.Dock="Top">
            <Label>Drop media files here and show on:</Label>
            <ComboBox Name="ScreenList" SelectedItem="{Binding SelectInfo, Mode=OneWayToSource}" />
        </WrapPanel>
        <StatusBar DockPanel.Dock="Bottom">
            <StatusBarItem>
                <TextBlock Name="StatusBar">Ready</TextBlock>
            </StatusBarItem>
        </StatusBar>
        <ListView Name="MediaList" DockPanel.Dock="Top" SelectedItem="{Binding SelectInfo, Mode=OneWayToSource}" AllowDrop="True" />
    </DockPanel>
</Window>
"@
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$MainWindow = [Windows.Markup.XamlReader]::Load($reader)

$ScreenList = $MainWindow.FindName('ScreenList')
$MediaList = $MainWindow.FindName('MediaList')
$StatusBar = $MainWindow.FindName('StatusBar')

[xml]$xaml2 = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    WindowStyle="None"
    Background="Black">
    <MediaElement Name="MediaPlayer" LoadedBehavior="Manual" />
</Window>
"@
$reader2 = (New-Object System.Xml.XmlNodeReader $xaml2)
$window2 = [Windows.Markup.XamlReader]::Load($reader2)

$MediaPlayer = $window2.FindName('MediaPlayer')

$ScreenList_SelectionChanged = {
    If ($ScreenList.SelectedItem -eq "NONE") {
        $MediaPlayer.Stop()
        $window2.Hide()
    } Else {
        $window2.WindowState="Normal"
        $SelectedScreen = $AllScreens[$ScreenList.SelectedIndex].WorkingArea
        $window2.Left = $SelectedScreen.left
        $window2.Top = $SelectedScreen.top
        $window2.Show()
        $window2.WindowState="Maximized"
        $MediaPlayer.Play()
        $MainWindow.Activate()
    }
}

$MediaList_SelectionChanged = {
    $MediaPlayer.Source = $MediaList.SelectedItem
    If ($ScreenList.SelectedItem -ne "NONE") {
        $MediaPlayer.Play()
    }
}

$MediaList_DragOver = [Windows.DragEventHandler]{
    If ($_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        $_.Effects = 'Copy'
    } Else {
        $_.Effects = 'None'
    }
}

$MediaList_Drop = [Windows.DragEventHandler]{
    ForEach ($filename in $_.Data.GetData([Windows.DataFormats]::FileDrop)) {
        $MediaList.Items.Add($filename)
    }
    $StatusBar.Text = "List contains $($MediaList.Items.Count) items"
}

$MediaList_KeyDown = {
    If ($_.Key -eq "Delete") {
        $MediaList.Items.Remove($MediaList.SelectedItem)
    }
    $statusBar.Text = "List contains $($MediaList.Items.Count) items"
}

$MainWindow_Loaded = {
    ForEach ($Screen in $AllScreens) {
        $ScreenList.Items.Add($Screen.DeviceName)
    }
    $ScreenList.Items.Add("NONE")
    $ScreenList.SelectedIndex = $ScreenList.Items.Count - 1
}
$MainWindow_Closed = {
    $window2.Close()
}
$window2_Closed = {
    $MediaPlayer.Stop()
}

$ScreenList.Add_SelectionChanged($ScreenList_SelectionChanged)
$MediaList.Add_SelectionChanged($MediaList_SelectionChanged)
$MediaList.Add_DragOver($MediaList_DragOver)
$MediaList.Add_Drop($MediaList_Drop)
$MediaList.Add_KeyDown($MediaList_KeyDown)

$MainWindow.Add_Loaded($MainWindow_Loaded)
$MainWindow.Add_Closed($MainWindow_Closed)
$window2.Add_Closed($window2_Closed)

[void] $MainWindow.ShowDialog()