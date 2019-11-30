# PSMediaPresenter
Very simple media presenter using PowerShell and WPF

## Installation
1. Download [PSMediaPresenter.ps1](../../raw/master/PSMediaPresenter.ps1)
2. Create a shortcut with proper Target value
   ```
   C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%USERPROFILE%\Downloads\PSMediaPresenter.ps1"
   ```
   * Bypass the default 'Restricted' execution policy
   * Hide 'Normal' black shell console window
   * Adjust the path, for example,"C:\Scripts\PSMediaPresenter.ps1"

## Usage
1. Run **PSMediaPresenter.ps1** using the shortcut or from PowerShell
2. Drag and drop image files to the listbox
3. Remove unwanted files using up/down key and delete key
4. Clic the listbox to show the selected image, maximized in the selected screen

## Reference
* [Microsoft dotnet API](https://docs.microsoft.com/en-us/dotnet/api/system.windows.window)
* [NETMediaPresenter](https://github.com/hamletmun/NETMediaPresenter)
