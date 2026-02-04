![Adrenaline Hook - Copy](https://github.com/user-attachments/assets/fc06c1f1-0f69-4b73-9e00-2f7c977fbf0b)

<img width="635" height="409" alt="1" src="https://github.com/user-attachments/assets/5ff5d836-9741-4b2a-a19c-9086132bb182" />

Adrenaline Hook is a utility developed to seamlessly integrate UWP, and GamePass titles into AMD Adrenalin Software. Due to Microsoft’s DRM restrictions, manually adding GamePass executables to Adrenalin is typically not possible without complex and temporary workarounds that often break after game updates.

Many GamePass games are not automatically detected by AMD Adrenalin, which prevents users from taking advantage of key AMD features like Frame Generation, Image Sharpening, and more. Adrenaline Hook eliminates this limitation.

Example:
![1](https://github.com/user-attachments/assets/6efb72ae-c272-4c41-b3c5-87ed97653b45)

With a simple click on “Scan MS Store/GamePass Games”, the tool will display all installed UWP apps and games. You can then select the titles you wish to hook into AMD Adrenalin.

![2](https://github.com/user-attachments/assets/de1812fc-983a-4721-b1e3-8ad5ce39546a)
Note: Games already added to AMD Adrenalin will be highlighted in dark red.

Once hooked, the selected game will appear in AMD Adrenalin, allowing you to configure and optimize its graphics settings.

![4](https://github.com/user-attachments/assets/7cc09e2b-cd7a-4aa4-823f-84c1c361cb3e)

Other Key Features Include:

- Hook games from additional platforms such as Steam, Epic Games Launcher, and others.

  ![6](https://github.com/user-attachments/assets/e60b2439-8ae7-4b01-87bf-c816d6a667c4)

- Manually hook custom executable files.
- View and remove previously hooked applications.

  ![8](https://github.com/user-attachments/assets/afe35285-e167-4f8f-98a0-7d816b92255e)

- Create and restore backups of the AMD Adrenalin game database.

I hope you find this tool useful :)

## Run instructions:

⚠️ Important Disclaimer
```
    This script modifies AMD Adrenalin configuration files and interacts with your system.
    It is your responsibility to review and understand the code before running it.
    By using this utility, you acknowledge that you do so at your own risk.
    The creator(s) cannot be held liable for any issues or damages resulting from its use.
    Always back up important files and check the script for trustworthiness.
```
Steps: 
1. Open powershell or CMD in administrator mode (right click application).

https://learn.microsoft.com/en-us/answers/questions/1338912/how-to-run-powershell-as-administrator
1. Using commands 'cd' and 'dir' navigate to the downloaded file. example: 
```powershell #
    cd c:/users/*your user name*/Downloads/Adrenaline-Hook-1.0.7
```

3. Execute the script using: 
```powershell #
    & '.\Adrenaline Hook - Source Code.ps1'
```
### Possible issues:
- When running the script you could can get the error that scripts are not allowed to be ran on the system. Suggested executable fix: 
```Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass```  

(Choose Y afterwards)

https://medium.com/@saviranathunge/powershell-script-execution-issues-35d66afec502
