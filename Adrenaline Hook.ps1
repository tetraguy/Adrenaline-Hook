# TetraDev
# Adrenaline Hook is a tool whose purpose is to add any GamePass titles/applications to the AMD Adrenaline Software.
# Built using Sapien PowerShell Studio 2025
# Version 1.2.0
# Github Profile "https://github.com/tetraguy"

# Set Globals Variables
$selectedItems = @()
$gmdbPath = "$env:LOCALAPPDATA\AMD\CN\gmdb.blb"
$gamesList = @()

# Remove unnecessary backup
$blbPath = "$env:LOCALAPPDATA\AMD\CN\backup.blb"
if (Test-Path $blbPath)
{
	Remove-Item $blbPath -Force
}


# Admin Rights Check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
	[System.Windows.Forms.MessageBox]::Show("Adrenaline Hook must be run as Administrator for full functionality.", "Admin Rights Required", "OK", "Warning")
	
	exit
}

# Logger Function
function Write-Log
{
	param ([string]$message)
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
	"$timestamp - $message" | Out-File "$env:LOCALAPPDATA\AdrenalineHook\activity.log" -Append
}

# Auto-Update Checker GitHub Repo
function Check-ForUpdate
{
	$repo = "https://api.github.com/repos/tetraguy/Adrenaline-Hook/releases/latest"
	try
	{
		$response = Invoke-RestMethod -Uri $repo -UseBasicParsing
		$latest = $response.tag_name
		$htmlUrl = $response.html_url
		$current = "v1.2.0" # actual version
		
		if ($latest -ne $current)
		{
			$popup = New-Object Windows.Forms.Form
			$popup.Text = "Update Available"
			$popup.Size = New-Object Drawing.Size(400, 150)
			$popup.StartPosition = "CenterParent"
			$popup.FormBorderStyle = 'FixedDialog'
			$popup.MaximizeBox = $false
			$popup.MinimizeBox = $false
			
			$label = New-Object Windows.Forms.Label
			$label.Text = "A new version ($latest) is available."
			$label.SetBounds(10, 20, 380, 30)
			
			$btnDownload = New-Object Windows.Forms.Button
			$btnDownload.Text = "Download Update"
			$btnDownload.SetBounds(80, 60, 120, 30)
			$btnDownload.Add_Click({
					Start-Process $htmlUrl
					$popup.Close()
				})
			
			$btnNotNow = New-Object Windows.Forms.Button
			$btnNotNow.Text = "Not Now"
			$btnNotNow.SetBounds(210, 60, 120, 30)
			$btnNotNow.Add_Click({ $popup.Close() })
			
			$popup.Controls.AddRange(@($label, $btnDownload, $btnNotNow))
			$popup.ShowDialog() | Out-Null
		}
	}
	catch
	{
		Write-Log "Update check failed: $_"
	}
}

# JSON Preview/Editor
function Show-JsonEditor
{
	$editorForm = New-Object Windows.Forms.Form
	$editorForm.Text = "Application Database Editor"
	$editorForm.Size = New-Object Drawing.Size(600, 600)
	
	$textBox = New-Object Windows.Forms.TextBox
	$textBox.Multiline = $true
	$textBox.ScrollBars = 'Both'
	$textBox.Dock = 'Fill'
	$textBox.Text = Get-Content $gmdbPath -Raw
	
	$btnSave = New-Object Windows.Forms.Button
	$btnSave.Text = "Save"
	$btnSave.Dock = 'Bottom'
	$btnSave.Add_Click({
			$textBox.Text | Set-Content $gmdbPath
			[System.Windows.Forms.MessageBox]::Show("Saved successfully.", "Saved", "OK", "Information")
		})
	
	$editorForm.Controls.AddRange(@($textBox, $btnSave))
	$editorForm.ShowDialog()
}


# Execute startup features
Validate-Json | Out-Null
Check-ForUpdate

# Terminate AMD Software Process
Get-Process -Name "RadeonSoftware" -ErrorAction SilentlyContinue | ForEach-Object {
	Stop-Process -Id $_.Id -Force
}

# Set custom icon
$iconPath = ".\Adrenaline Hook.ico"

# Load required system dynamic libraries
Add-Type -AssemblyName "System.EnterpriseServices"
$publish = [System.EnterpriseServices.Internal.Publish]::new()

$dlls = @(
	'System.Memory.dll',
	'System.Numerics.Vectors.dll',
	'System.Runtime.CompilerServices.Unsafe.dll',
	'System.Security.Principal.Windows.dll'
)

foreach ($dll in $dlls)
{
	$dllPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\$dll"
	$publish.GacInstall($dllPath)
}

# Load Form GUI
$form_Load = {
	
	
}


# Load existing game titles from BLB if available
$existingGameTitles = @()
if (Test-Path $gmdbPath)
{
	try
	{
		$jsonContent = Get-Content $gmdbPath -Raw | ConvertFrom-Json
		$existingGameTitles = $jsonContent.games | ForEach-Object { $_.title }
	}
	catch
	{
		Write-Warning "Failed to read or parse gmdb.json"
	}
}

#region Control Helper Functions
function Show-NotifyIcon
{
<#
	.SYNOPSIS
		Displays a NotifyIcon's balloon tip message in the taskbar's notification area.
	
	.DESCRIPTION
		Displays a NotifyIcon's a balloon tip message in the taskbar's notification area.
		
	.PARAMETER NotifyIcon
     	The NotifyIcon control that will be displayed.
	
	.PARAMETER BalloonTipText
     	Sets the text to display in the balloon tip.
	
	.PARAMETER BalloonTipTitle
		Sets the Title to display in the balloon tip.
	
	.PARAMETER BalloonTipIcon	
		The icon to display in the ballon tip.
	
	.PARAMETER Timeout	
		The time the ToolTip Balloon will remain visible in milliseconds. 
		Default: 0 - Uses windows default.
#>
	 param(
	  [Parameter(Mandatory = $true, Position = 0)]
	  [ValidateNotNull()]
	  [System.Windows.Forms.NotifyIcon]$NotifyIcon,
	  [Parameter(Mandatory = $true, Position = 1)]
	  [ValidateNotNullOrEmpty()]
	  [String]$BalloonTipText,
	  [Parameter(Position = 2)]
	  [String]$BalloonTipTitle = '',
	  [Parameter(Position = 3)]
	  [System.Windows.Forms.ToolTipIcon]$BalloonTipIcon = 'None',
	  [Parameter(Position = 4)]
	  [int]$Timeout = 0
 	)
	
	if($null -eq $NotifyIcon.Icon)
	{
		#Set a Default Icon otherwise the balloon will not show
		$NotifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon([System.Windows.Forms.Application]::ExecutablePath)
	}
	
	$NotifyIcon.ShowBalloonTip($Timeout, $BalloonTipTitle, $BalloonTipText, $BalloonTipIcon)
}




function Update-ListViewColumnSort
{
<#
	.SYNOPSIS
		Sort the ListView's item using the specified column.
	
	.DESCRIPTION
		Sort the ListView's item using the specified column.
		This function uses Add-Type to define a class that sort the items.
		The ListView's Tag property is used to keep track of the sorting.
	
	.PARAMETER ListView
		The ListView control to sort.
	
	.PARAMETER ColumnIndex
		The index of the column to use for sorting.
	
	.PARAMETER SortOrder
		The direction to sort the items. If not specified or set to None, it will toggle.
	
	.EXAMPLE
		Update-ListViewColumnSort -ListView $listview1 -ColumnIndex 0
	
	.NOTES
		Additional information about the function.
#>
	
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[System.Windows.Forms.ListView]
		$ListView,
		[Parameter(Mandatory = $true)]
		[int]
		$ColumnIndex,
		[System.Windows.Forms.SortOrder]
		$SortOrder = 'None'
	)
	
	if (($ListView.Items.Count -eq 0) -or ($ColumnIndex -lt 0) -or ($ColumnIndex -ge $ListView.Columns.Count))
	{
		return;
	}
	
	#region Define ListViewItemComparer
	try
	{
		[ListViewItemComparer] | Out-Null
	}
	catch
	{
		Add-Type -ReferencedAssemblies ('System.Windows.Forms') -TypeDefinition  @" 
	using System;
	using System.Windows.Forms;
	using System.Collections;
	public class ListViewItemComparer : IComparer
	{
	    public int column;
	    public SortOrder sortOrder;
	    public ListViewItemComparer()
	    {
	        column = 0;
			sortOrder = SortOrder.Ascending;
	    }
	    public ListViewItemComparer(int column, SortOrder sort)
	    {
	        this.column = column;
			sortOrder = sort;
	    }
	    public int Compare(object x, object y)
	    {
			if(column >= ((ListViewItem)x).SubItems.Count)
				return  sortOrder == SortOrder.Ascending ? -1 : 1;
		
			if(column >= ((ListViewItem)y).SubItems.Count)
				return sortOrder == SortOrder.Ascending ? 1 : -1;
		
			if(sortOrder == SortOrder.Ascending)
	        	return String.Compare(((ListViewItem)x).SubItems[column].Text, ((ListViewItem)y).SubItems[column].Text);
			else
				return String.Compare(((ListViewItem)y).SubItems[column].Text, ((ListViewItem)x).SubItems[column].Text);
	    }
	}
"@ | Out-Null
	}
	#endregion
	
	if ($ListView.Tag -is [ListViewItemComparer])
	{
		#Toggle the Sort Order
		if ($SortOrder -eq [System.Windows.Forms.SortOrder]::None)
		{
			if ($ListView.Tag.column -eq $ColumnIndex -and $ListView.Tag.sortOrder -eq 'Ascending')
			{
				$ListView.Tag.sortOrder = 'Descending'
			}
			else
			{
				$ListView.Tag.sortOrder = 'Ascending'
			}
		}
		else
		{
			$ListView.Tag.sortOrder = $SortOrder
		}
		
		$ListView.Tag.column = $ColumnIndex
		$ListView.Sort() #Sort the items
	}
	else
	{
		if ($SortOrder -eq [System.Windows.Forms.SortOrder]::None)
		{
			$SortOrder = [System.Windows.Forms.SortOrder]::Ascending
		}
		
		#Set to Tag because for some reason in PowerShell ListViewItemSorter prop returns null
		$ListView.Tag = New-Object ListViewItemComparer ($ColumnIndex, $SortOrder)
		$ListView.ListViewItemSorter = $ListView.Tag #Automatically sorts
	}
}



function Add-ListViewItem
{
<#
	.SYNOPSIS
		Adds the item(s) to the ListView and stores the object in the ListViewItem's Tag property.

	.DESCRIPTION
		Adds the item(s) to the ListView and stores the object in the ListViewItem's Tag property.

	.PARAMETER ListView
		The ListView control to add the items to.

	.PARAMETER Items
		The object or objects you wish to load into the ListView's Items collection.
		
	.PARAMETER  ImageIndex
		The index of a predefined image in the ListView's ImageList.
	
	.PARAMETER  SubItems
		List of strings to add as Subitems.
	
	.PARAMETER Group
		The group to place the item(s) in.
	
	.PARAMETER Clear
		This switch clears the ListView's Items before adding the new item(s).
	
	.EXAMPLE
		Add-ListViewItem -ListView $listview1 -Items "Test" -Group $listview1.Groups[0] -ImageIndex 0 -SubItems "Installed"
#>
	
	Param( 
	[ValidateNotNull()]
	[Parameter(Mandatory=$true)]
	[System.Windows.Forms.ListView]$ListView,
	[ValidateNotNull()]
	[Parameter(Mandatory=$true)]
	$Items,
	[int]$ImageIndex = -1,
	[string[]]$SubItems,
	$Group,
	[switch]$Clear)
	
	if($Clear)
	{
		$ListView.Items.Clear();
    }
    
    $lvGroup = $null
    if ($Group -is [System.Windows.Forms.ListViewGroup])
    {
        $lvGroup = $Group
    }
    elseif ($Group -is [string])
    {
        #$lvGroup = $ListView.Group[$Group] # Case sensitive
        foreach ($groupItem in $ListView.Groups)
        {
            if ($groupItem.Name -eq $Group)
            {
                $lvGroup = $groupItem
                break
            }
        }
        
        if ($null -eq $lvGroup)
        {
            $lvGroup = $ListView.Groups.Add($Group, $Group)
        }
    }
    
	if($Items -is [Array])
	{
		$ListView.BeginUpdate()
		foreach ($item in $Items)
		{		
			$listitem  = $ListView.Items.Add($item.ToString(), $ImageIndex)
			#Store the object in the Tag
			$listitem.Tag = $item
			
			if($null -ne $SubItems)
			{
				$listitem.SubItems.AddRange($SubItems)
			}
			
			if($null -ne $lvGroup)
			{
				$listitem.Group = $lvGroup
			}
		}
		$ListView.EndUpdate()
	}
	else
	{
		#Add a new item to the ListView
		$listitem  = $ListView.Items.Add($Items.ToString(), $ImageIndex)
		#Store the object in the Tag
		$listitem.Tag = $Items
		
		if($null -ne $SubItems)
		{
			$listitem.SubItems.AddRange($SubItems)
		}
		
		if($null -ne $lvGroup)
		{
			$listitem.Group = $lvGroup
		}
	}
}


#endregion

$buttonScanMSStoreAppsGameP_Click = {
	
	Write-Log
	
	$listView.Items.Clear()
	
	# reload existing game titles from BLB if available
	$existingGameTitles = @()
	if (Test-Path $gmdbPath)
	{
		try
		{
			$jsonContent = Get-Content $gmdbPath -Raw | ConvertFrom-Json
			$existingGameTitles = $jsonContent.games | ForEach-Object { $_.title }
		}
		catch
		{
			Write-Warning "Failed to read or parse gmdb.json"
		}
	}
	
	# Scan for installed UWP applications
	# Define context menu once
	$contextMenu = New-Object System.Windows.Forms.ContextMenu
	$menuHook = New-Object System.Windows.Forms.MenuItem "Hook This"
	$menuOpen = New-Object System.Windows.Forms.MenuItem "Open Install Location"
	$menuDetails = New-Object System.Windows.Forms.MenuItem "Application Details"
	$menuStart = New-Object System.Windows.Forms.MenuItem "Start Application"
	
	
	$menuHook.add_Click({
			$item = $listView.SelectedItems[0]
			[System.Windows.Forms.MessageBox]::Show("To hook: " + $item.Text + ", click on the checkbox next to it and click on Hook Applicatio(s).")
		})
	
	$menuOpen.add_Click({
			$path = $listView.SelectedItems[0].SubItems[1].Text
			if (Test-Path $path)
			{
				Start-Process -FilePath (Split-Path $path -Parent)
			}
		})
	
	$menuDetails.add_Click({
			$item = $listView.SelectedItems[0]
			$appName = $item.Text
			$installPath = $item.SubItems[1].Text
			$logoPath = $item.Tag.image_info
			$publisher = $item.Tag.publisher
			$version = $item.Tag.version
			$architecture = $item.Tag.architecture
			
			$detailsForm = New-Object Windows.Forms.Form
			$detailsForm.Text = "Application Details"
			$detailsForm.Size = New-Object Drawing.Size(400, 300)
			$detailsForm.StartPosition = "CenterParent"
			$detailsForm.FormBorderStyle = 'FixedDialog'
			$detailsForm.MaximizeBox = $false
			$detailsForm.MinimizeBox = $false
			
			
			if (Test-Path $logoPath)
			{
				$logo = New-Object Windows.Forms.PictureBox
				$logo.Image = [System.Drawing.Image]::FromFile($logoPath)
				$logo.SizeMode = 'Zoom'
				$logo.SetBounds(10, 10, 64, 64)
				$detailsForm.Controls.Add($logo)
			}
			
			$lblName = New-Object Windows.Forms.Label
			$lblName.Text = "Application Name: $appName"
			$lblName.SetBounds(80, 10, 300, 20)
			
			$lblPublisher = New-Object Windows.Forms.Label
			$lblPublisher.Text = "Publisher: $publisher"
			$lblPublisher.SetBounds(80, 40, 300, 20)
			
			$lblPath = New-Object Windows.Forms.Label
			$lblPath.Text = "Install Location: $installPath"
			$lblPath.SetBounds(80, 70, 300, 20)
			
			$lblVersion = New-Object Windows.Forms.Label
			$lblVersion.Text = "Version: $version"
			$lblVersion.SetBounds(80, 100, 300, 20)
			
			$lblArch = New-Object Windows.Forms.Label
			$lblArch.Text = "Architecture: $architecture"
			$lblArch.SetBounds(80, 130, 300, 20)
			
			$btnClose = New-Object Windows.Forms.Button
			$btnClose.Text = "Close"
			$btnClose.SetBounds(150, 220, 100, 30)
			$btnClose.Add_Click({ $detailsForm.Close() })
			
			$detailsForm.Controls.AddRange(@($lblName, $lblPublisher, $lblPath, $lblVersion, $lblArch, $btnClose))
			$detailsForm.ShowDialog() | Out-Null
		})
	
	$menuStart.add_Click({
			$item = $listView.SelectedItems[0]
			$exePath = $item.SubItems[1].Text
			if (Test-Path $exePath)
			{
				try
				{
					Start-Process $exePath
				}
				catch
				{
					[System.Windows.Forms.MessageBox]::Show("Failed to start application.`n$_", "Error", "OK", "Error")
				}
			}
			else
			{
				[System.Windows.Forms.MessageBox]::Show("Executable path does not exist.", "Error", "OK", "Warning")
			}
		})
	$contextMenu.MenuItems.AddRange(@($menuHook, $menuOpen, $menuDetails, $menuStart))
	$listView.ContextMenu = $contextMenu
	
	# Scan UWP Apps
	Get-AppxPackage | ForEach-Object {
		$manifestPath = Join-Path $_.InstallLocation "AppxManifest.xml"
		if (Test-Path $manifestPath)
		{
			try
			{
				[xml]$manifest = Get-Content $manifestPath -ErrorAction Stop
				$displayName = $manifest.Package.Properties.DisplayName
				
				# Skip unwanted entries
				if ($displayName -match "(?i)ms-resource|WindowsAppRuntime|AppManifest|DisplayName")
				{
					return
				}
				
				$logoPath = $manifest.Package.Properties.Logo
				$fullLogoPath = Join-Path $_.InstallLocation $logoPath
				
				$gameConfigPath = Join-Path $_.InstallLocation "MicrosoftGame.config"
				$exePath = $null
				if (Test-Path $gameConfigPath)
				{
					[xml]$gameConfig = Get-Content $gameConfigPath -ErrorAction Stop
					$exeName = $gameConfig.SelectSingleNode("//ExecutableList/Executable").Name
					if ($exeName)
					{
						$exeFile = Get-ChildItem -Path $_.InstallLocation -Recurse -Filter $exeName -ErrorAction SilentlyContinue | Select-Object -First 1
						if ($exeFile)
						{
							$exePath = $exeFile.FullName
						}
					}
				}
				
				if (-not $exePath)
				{
					$exeFile = Get-ChildItem $_.InstallLocation -Recurse -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
					if ($exeFile)
					{
						$exePath = $exeFile.FullName
					}
				}
				
				if ($exePath -and (Test-Path $exePath))
				{
					$publisher = $_.Publisher -replace '.*CN=', ''
					$version = $_.Version
					$architecture = $_.Architecture
					
					$item = $listView.Items.Add($displayName)
					$item.SubItems.Add($exePath)
					$item.Tag = @{
						image_info	     = $fullLogoPath
						publisher	     = $publisher
						version		     = $version
						architecture	 = $architecture
						install_location = $exePath
					}
					
					if ($existingGameTitles -contains $displayName)
					{
						$item.ForeColor = [System.Drawing.Color]::DarkRed
					}
				}
			}
			catch
			{
				Write-Warning "Could not read manifest or config for $($_.Name)"
			}
		}
	}
	
}

$buttonHookSelections_Click = {
	
	Write-Log
	# Add selected applications to AMD Software
	Get-Process -Name "RadeonSoftware" -ErrorAction SilentlyContinue | ForEach-Object {
		Stop-Process -Id $_.Id -Force
	}
	
	$selectedItems = $listView.CheckedItems | ForEach-Object {
		[PSCustomObject]@{
			Name = $_.Text
			Path = $_.SubItems[1].Text
			Image = $_.Tag.image_info
		}
	}
	
	if ($selectedItems.Count -eq 0)
	{
		[System.Windows.Forms.MessageBox]::Show("No items selected!", "Error", "OK", "Error")
		return
	}
	
	$msg = "Do you want to hook the following apps?`n`n" + ($selectedItems | ForEach-Object { " `n - " + $_.Name }) -join "`n"
	$result = [System.Windows.Forms.MessageBox]::Show($msg, "Confirm", "YesNo", "Question")
	
	if ($result -eq "No")
	{
		[System.Windows.Forms.MessageBox]::Show("Hook Aborted!", "Canceled", "OK", "Information")
		return
	}
	
	if (Test-Path $gmdbPath)
	{
		$json = Get-Content $gmdbPath -Raw | ConvertFrom-Json
	}
	else
	{
		$json = [PSCustomObject]@{ engines = @(); games = @() }
	}
	#$app.Image
	foreach ($app in $selectedItems)
	{
		$newGame = [PSCustomObject]@{
			FRAMEGEN_PerfMode   = 0
			FRAMEGEN_SearchMode = 0
			amdId			    = -1
			appDisplayScalingSet = "FALSE"
			appHistogramCapture = "FALSE"
			arguments		    = ""
			athena_support	    = "FALSE"
			auto_enable_ps_state = "USEGLOBAL"
			averageFPS		    = -1
			color_enabled	    = "FALSE"
			colors			    = @()
			commandline		    = ""
			exe_path		    = $app.Path
			eyefinity_enabled   = "FALSE"
			framegen_enabled    = 0
			freeSyncForceSet    = "FALSE"
			guid			    = [guid]::NewGuid().ToString()
			has_framegen_profile = "FALSE"
			has_upscaling_profile = "FALSE"
			hidden			    = "FALSE"
			image_info		    = $app.Image
			install_location    = ""
			installer_id	    = ""
			is_ai_app		    = "FALSE"
			is_appforlink	    = "FALSE"
			is_favourite	    = "FALSE"
			last_played_mins    = 0
			lastlaunchtime	    = ""
			lastperformancereporttime = ""
			lnk_path		    = ""
			manual			    = "FALSE"
			origin_id		    = -1
			overdrive		    = @()
			overdrive_enabled   = "FALSE"
			percentile95_msec   = -1
			profileCustomized   = "FALSE"
			profileEnabled	    = "TRUE"
			rayTracing		    = "FALSE"
			rendering_process   = ""
			revertuserprofiletype = -1
			smartshift_enabled  = "FALSE"
			special_flags	    = ""
			steam_id		    = -1
			title			    = $app.Name
			total_played_mins   = 0
			uninstall_location  = -1
			uninstalled		    = "FALSE"
			uplay_id		    = -1
			upscaling_enabled   = "FALSE"
			upscaling_sharpness = 0
			upscaling_target_resolution = ""
			upscaling_use_borderless = "FALSE"
			useEyefinity	    = "FALSE"
			userprofiletype	    = -1
			week_played_mins    = 0
		}
		$json.games += $newGame
	}
	
	$json | ConvertTo-Json -Depth 100 | Set-Content -Path $gmdbPath -Encoding UTF8
	$listView.Items.Clear()
	[System.Windows.Forms.MessageBox]::Show("Programs hooked to AMD Adrenaline!", "Success", "OK", "Information")
	
	# After showing "Programs added to AMD Adrenaline!" message
	$addedTitles = $selectedItems | ForEach-Object { " - " + $_.Name } | Out-String
	$restartMsg = "In order for AMD Adrenalin to recognize the following programs, you need to restart your device:`n`n$addedTitles`nWould you like to restart now?"
	$restartConfirm = [System.Windows.Forms.MessageBox]::Show($restartMsg, "Restart Required", "YesNo", "Question")
	
	if ($restartConfirm -eq "Yes")
	{
		Restart-Computer -Force
	}
	
}

$buttonScanInstalledSoftwar_Click={
	
	Write-Log
	$listView.Items.Clear()
	
	# reload existing game titles from BLB if available
	$existingGameTitles = @()
	if (Test-Path $gmdbPath)
	{
		try
		{
			$jsonContent = Get-Content $gmdbPath -Raw | ConvertFrom-Json
			$existingGameTitles = $jsonContent.games | ForEach-Object { $_.title }
		}
		catch
		{
			Write-Warning "Failed to read or parse gmdb.json"
		}
	}
	
	$paths = @(
		"HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
		"HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
	)
	foreach ($path in $paths)
	{
		Get-ItemProperty $path -ErrorAction SilentlyContinue | ForEach-Object {
			if ($_.DisplayName -and $_.InstallLocation -and (Test-Path $_.InstallLocation))
			{
				# Get the first .exe file inside the install location
				$exe = Get-ChildItem -Path $_.InstallLocation -Recurse -Filter *.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
				if ($exe)
				{
					$item = $listView.Items.Add($_.DisplayName)
					$item.SubItems.Add($exe.FullName)
					$listView.Sorting = 'Ascending'
					
					# Add for coloring if already in Database
					if ($existingGameTitles -contains $_.DisplayName)
					{
						$item.ForeColor = 'DarkRed'
					}
					
					# Store the exe path for use in Add Selected
					$item.Tag = @{
						image_info = $exe.FullName
					}
				}
			}
		}
		# .exe Icon Preview
		function Get-ExeIcon ($exePath)
		{
			if (Test-Path $exePath)
			{
				try
				{
					return [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
				}
				catch
				{
					return [System.Drawing.SystemIcons]::Application
				}
			}
			return [System.Drawing.SystemIcons]::Application
		}
		Get-ExeIcon
	}
	
	$contextMenu = New-Object System.Windows.Forms.ContextMenu
	$menuHook = New-Object System.Windows.Forms.MenuItem "Hook This"
	$menuOpen = New-Object System.Windows.Forms.MenuItem "Open Install Location"
	
	$menuHook.add_Click({
			$item = $listView.SelectedItems[0]
			[System.Windows.Forms.MessageBox]::Show("To hook: " + $item.Text + ", click on the checkbox next to it and click on Hook Applicatio(s).")
		})
	
	$menuOpen.add_Click({
			$path = $listView.SelectedItems[0].SubItems[1].Text
			if (Test-Path $path)
			{
				Start-Process -FilePath (Split-Path $path -Parent)
			}
		})
	
	$contextMenu.MenuItems.AddRange(@($menuHook, $menuOpen))
	$listView.ContextMenu = $contextMenu
	
}

$buttonHookProgramManually_Click = {
	Write-Log
	
	# Open file dialog once
	$dialog = New-Object Windows.Forms.OpenFileDialog
	$dialog.Filter = "Executable Files (*.exe)|*.exe"
	$dialog.InitialDirectory = "C:\"
	$dialog.Title = "Select Application"
	
	# Only proceed if user selects a file
	if ($dialog.ShowDialog() -ne "OK")
	{
		return # User canceled - do nothing
	}
	
	$exePath = $dialog.FileName
	$exeName = [System.IO.Path]::GetFileName($exePath)
	$title = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
	
	$result = [System.Windows.Forms.MessageBox]::Show("Do you want to hook '$exeName' to AMD Adrenaline?", "Confirm", "YesNo", "Question")
	if ($result -ne "Yes")
	{
		return # User chose not to hook - do nothing
	}
	
	if (Test-Path $gmdbPath)
	{
		$json = Get-Content $gmdbPath -Raw | ConvertFrom-Json
	}
	else
	{
		$json = [PSCustomObject]@{ engines = @(); games = @() }
	}
	
	$newGame = [PSCustomObject]@{
		FRAMEGEN_PerfMode   = 0
		FRAMEGEN_SearchMode = 0
		amdId			    = -1
		appDisplayScalingSet = "FALSE"
		appHistogramCapture = "FALSE"
		arguments		    = ""
		athena_support	    = "FALSE"
		auto_enable_ps_state = "USEGLOBAL"
		averageFPS		    = -1
		color_enabled	    = "FALSE"
		colors			    = @()
		commandline		    = ""
		exe_path		    = $exePath
		eyefinity_enabled   = "FALSE"
		framegen_enabled    = 0
		freeSyncForceSet    = "FALSE"
		guid			    = [guid]::NewGuid().ToString()
		has_framegen_profile = "FALSE"
		has_upscaling_profile = "FALSE"
		hidden			    = "FALSE"
		image_info		    = $exePath
		install_location    = ""
		installer_id	    = ""
		is_ai_app		    = "FALSE"
		is_appforlink	    = "FALSE"
		is_favourite	    = "FALSE"
		last_played_mins    = 2
		lastlaunchtime	    = ""
		lastperformancereporttime = ""
		lnk_path		    = ""
		manual			    = "TRUE"
		origin_id		    = -1
		overdrive		    = @()
		overdrive_enabled   = "FALSE"
		percentile95_msec   = -1
		profileCustomized   = "FALSE"
		profileEnabled	    = "TRUE"
		rayTracing		    = "FALSE"
		rendering_process   = ""
		revertuserprofiletype = -1
		smartshift_enabled  = "FALSE"
		special_flags	    = ""
		steam_id		    = -1
		title			    = $title
		total_played_mins   = 5
		uninstall_location  = -1
		uninstalled		    = "FALSE"
		uplay_id		    = -1
		upscaling_enabled   = "FALSE"
		upscaling_sharpness = 0
		upscaling_target_resolution = ""
		upscaling_use_borderless = "FALSE"
		useEyefinity	    = "FALSE"
		userprofiletype	    = -1
		week_played_mins    = 0
	}
	
	$json.games += $newGame
	$json | ConvertTo-Json -Depth 100 | Set-Content -Path $gmdbPath -Encoding UTF8
	
	[System.Windows.Forms.MessageBox]::Show("$title hooked successfully!", "Success", "OK", "Information")
	
	# Restart RadeonSoftware
	Get-Process -Name "RadeonSoftware" -ErrorAction SilentlyContinue | ForEach-Object {
		Stop-Process -Id $_.Id -Force
		Write-Output "Terminated: $($_.ProcessName) (ID: $($_.Id))"
	}
}


$buttonOpenAMDSoftware_Click ={
	
	Write-Log
	# Define the target app display name
	$targetAppName = "AMD Software"
	
	# Try to find the app in the Start Apps list
	$app = Get-StartApps | Where-Object { $_.Name -eq $targetAppName }
	
	if ($app)
	{
		Write-Output "Found app: $($app.Name). Attempting to launch..."
		Start-Process "shell:AppsFolder\$($app.AppID)"
	}
	else
	{
		Write-Warning "App '$targetAppName' not found among installed UWP apps."
	}
	
}

$listView.Add_ItemActivate({
		$sel = $listView.SelectedItems[0]
		$AppName = $sel.Text
		$InstallPath = $sel.SubItems[1].Text
		[System.Windows.Forms.MessageBox]::Show("Selected: $AppName`nPath: $InstallPath", "Selected")
	})

$buttonViewHookedApplicatio_Click={
	
	Write-Log
	if (Test-Path $gmdbPath)
	{
		try
		{
			$json = Get-Content $gmdbPath -Raw | ConvertFrom-Json
			$titles = $json.games | ForEach-Object { $_.title }
			
			
			# Create a new form for the scrollable list
			$popup = New-Object Windows.Forms.Form
			$popup.Text = "Hooked Applications"
			$popup.Size = New-Object Drawing.Size(400, 500)
			$popup.StartPosition = "CenterParent"
			$popup.FormBorderStyle = 'FixedDialog'
			$popup.MaximizeBox = $false
			$popup.MinimizeBox = $false
			
			
			$listbox = New-Object Windows.Forms.ListBox
			$listbox.Dock = 'Fill'
			$listbox.IntegralHeight = $false
			$listbox.Items.AddRange($titles)
			
			$popup.Controls.Add($listbox)
			$popup.ShowDialog() | Out-Null
		}
		catch
		{
			[System.Windows.Forms.MessageBox]::Show("Failed to load or parse gmdb.blb.", "Error", "OK", "Error")
		}
	}
	else
	{
		[System.Windows.Forms.MessageBox]::Show("No gmdb.blb file found.", "Not Found", "OK", "Warning")
	}
	
}


$buttonBackupDatabase_Click={
	
	Write-Log
	if (Test-Path $gmdbPath)
	{
		$confirm = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to backup the current database?", "Confirm Backup", "YesNo", "Question")
		if ($confirm -eq "Yes")
		{
			Copy-Item -Path $gmdbPath -Destination "$env:LOCALAPPDATA\AMD\CN\backup.blb" -Force
			[System.Windows.Forms.MessageBox]::Show("Backup created successfully!", "Success", "OK", "Information")
		}
	}
	else
	{
		[System.Windows.Forms.MessageBox]::Show("No gmdb.blb file found to back up.", "Error", "OK", "Error")
	}
	
}

$buttonRestoreDatabase_Click={
	
	Write-Log
	$backupPath = "$env:LOCALAPPDATA\AMD\CN\backup.blb"
	if (Test-Path $backupPath)
	{
		$confirm = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to restore the backup? This will overwrite the current version.", "Confirm Restore", "YesNo", "Warning")
		if ($confirm -eq "Yes")
		{
			Copy-Item -Path $backupPath -Destination $gmdbPath -Force
			[System.Windows.Forms.MessageBox]::Show("Backup restored successfully!", "Restored", "OK", "Information")
		}
	}
	else
	{
		[System.Windows.Forms.MessageBox]::Show("No backup file found to restore.", "Not Found", "OK", "Warning")
	}
	
}

$buttonRemoveAHookedApplica_Click={
	
	Write-Log
	if (-not (Test-Path $gmdbPath))
	{
		[System.Windows.Forms.MessageBox]::Show("No gmdb.blb file found.", "Not Found", "OK", "Warning")
		return
	}
	
	try
	{
		$json = Get-Content $gmdbPath -Raw | ConvertFrom-Json
		$games = $json.games
		
		$popup = New-Object Windows.Forms.Form
		$popup.Text = "Select the Application(s) to Un-Hook"
		$popup.Size = New-Object Drawing.Size(500, 500)
		$popup.StartPosition = "CenterParent"
		$popup.FormBorderStyle = 'FixedDialog'
		$popup.MaximizeBox = $false
		$popup.MinimizeBox = $false
		
		$lv = New-Object Windows.Forms.ListView
		$lv.Bounds = New-Object Drawing.Rectangle(10, 10, 460, 400)
		$lv.View = 'Details'
		$lv.CheckBoxes = $true
		$lv.FullRowSelect = $true
		$lv.GridLines = $true
		$lv.Columns.Add("Title", 440)
		
		foreach ($game in $games)
		{
			$item = $lv.Items.Add($game.title)
			$lv.Sorting = 'Ascending'
		}
		
		$btnUnhook = New-Object Windows.Forms.Button
		$btnUnhook.Text = "Un-Hook Selection(s)"
		$btnUnhook.SetBounds(10, 420, 460, 30)
		$btnUnhook.Add_Click({
				$selected = $lv.CheckedItems
				if ($selected.Count -eq 0)
				{
					[System.Windows.Forms.MessageBox]::Show("No applications selected.", "Notice", "OK", "Information")
					return
				}
				$titlesToRemove = $selected | ForEach-Object { $_.Text }
				$msg = "Are you sure you want to remove the following application(s)?`n`n" + ($titlesToRemove -join "`n")
				$confirm = [System.Windows.Forms.MessageBox]::Show($msg, "Confirm Removal", "YesNo", "Warning")
				if ($confirm -eq "Yes")
				{
					$json.games = $json.games | Where-Object { $titlesToRemove -notcontains $_.title }
					$json | ConvertTo-Json -Depth 100 | Set-Content -Path $gmdbPath -Encoding UTF8
					$popup.Close()
					[System.Windows.Forms.MessageBox]::Show("Selected application(s) have been removed.", "Success", "OK", "Information")
				}
			})
		
		$popup.Controls.AddRange(@($lv, $btnUnhook))
		$popup.ShowDialog() | Out-Null
	}
	catch
	{
		[System.Windows.Forms.MessageBox]::Show("Failed to load or parse gmdb.blb.", "Error", "OK", "Error")
	}
	
}


$buttonSearch_Click = {
	
	Write-Log
	
	$searchTerm = $txtSearch.Text.Trim()
	if (-not $searchTerm)
	{
		[System.Windows.Forms.MessageBox]::Show("Please enter a search term.", "Notice", "OK", "Information")
		return
	}
	$listView.Items.Clear()
	
	# Search in Installed Programs
	$paths = @(
		"HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*",
		"HKLM:\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*"
	)
	foreach ($path in $paths)
	{
		Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$searchTerm*" } | ForEach-Object {
			if ($_.DisplayName -and $_.InstallLocation -and (Test-Path $_.InstallLocation))
			{
				$exePath = Get-ChildItem $_.InstallLocation -Recurse -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
				if ($exePath)
				{
					$item = $listView.Items.Add($_.DisplayName)
					$item.SubItems.Add($exePath.FullName)
					$item.Tag = @{ image_info = $exePath.FullName }
					
					if ($existingGameTitles -contains $_.DisplayName)
					{
						$item.ForeColor = [System.Drawing.Color]::DarkRed
					}
				}
			}
		}
	}
	
	# Search in UWP Apps
	Get-AppxPackage | Where-Object { $_.Name -like "*$searchTerm*" } | ForEach-Object {
		$manifestPath = Join-Path $_.InstallLocation "AppxManifest.xml"
		if (Test-Path $manifestPath)
		{
			try
			{
				[xml]$manifest = Get-Content $manifestPath -ErrorAction Stop
				$displayName = $manifest.Package.Properties.DisplayName
				if ($displayName -match "(?i)ms-resource|WindowsAppRuntime|AppManifest|DisplayName")
				{
					return
				}
				
				$logoPath = $manifest.Package.Properties.Logo
				$fullLogoPath = Join-Path $_.InstallLocation $logoPath
				$gameConfigPath = Join-Path $_.InstallLocation "MicrosoftGame.config"
				$exePath = $null
				
				if (Test-Path $gameConfigPath)
				{
					[xml]$gameConfig = Get-Content $gameConfigPath -ErrorAction Stop
					$exeName = $gameConfig.SelectSingleNode("//ExecutableList/Executable").Name
					if ($exeName)
					{
						$exeFile = Get-ChildItem -Path $_.InstallLocation -Recurse -Filter $exeName -ErrorAction SilentlyContinue | Select-Object -First 1
						if ($exeFile)
						{
							$exePath = $exeFile.FullName
						}
					}
				}
				
				if (-not $exePath)
				{
					$exeFile = Get-ChildItem $_.InstallLocation -Recurse -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
					if ($exeFile)
					{
						$exePath = $exeFile.FullName
					}
				}
				
				if ($exePath -and (Test-Path $exePath))
				{
					$item = $listView.Items.Add($displayName)
					$item.SubItems.Add($exePath)
					$item.Tag = @{ image_info = $fullLogoPath }
					
					if ($existingGameTitles -contains $displayName)
					{
						$item.ForeColor = [System.Drawing.Color]::DarkRed
					}
				}
			}
			catch
			{
				Write-Warning "Could not read manifest or config for $($_.Name)"
			}
		}
	}
	
	$contextMenu = New-Object System.Windows.Forms.ContextMenu
	$menuHook = New-Object System.Windows.Forms.MenuItem "Hook This"
	$menuOpen = New-Object System.Windows.Forms.MenuItem "Open Install Location"
	
	$menuHook.add_Click({
			$item = $listView.SelectedItems[0]
			[System.Windows.Forms.MessageBox]::Show("To hook: " + $item.Text + ", click on the checkbox next to it and click on Hook Applicatio(s).")
		})
	
	$menuOpen.add_Click({
			$path = $listView.SelectedItems[0].SubItems[1].Text
			if (Test-Path $path)
			{
				Start-Process -FilePath (Split-Path $path -Parent)
			}
		})
	
	$contextMenu.MenuItems.AddRange(@($menuHook, $menuOpen))
	$listView.ContextMenu = $contextMenu
	
}

$buttonCheckGitHubRepo_Click={
	
	#Open GitHub link
	Start-Process "https://github.com/tetraguy/Adrenaline-Hook/releases/tag/Release"
	
}

$databseedit_Click={
	
	$editorForm = New-Object Windows.Forms.Form
	$editorForm.Text = "Database Configuration Editor"
	$editorForm.Size = New-Object Drawing.Size(600, 600)
	$editorForm.FormBorderStyle = 'FixedDialog'
	$editorForm.MaximizeBox = $false
	$editorForm.MinimizeBox = $false
	
	$textBox = New-Object Windows.Forms.TextBox
	$textBox.Multiline = $true
	$textBox.ScrollBars = 'Both'
	$textBox.Dock = 'Fill'
	$textBox.Text = Get-Content $gmdbPath -Raw
	
	$btnSave = New-Object Windows.Forms.Button
	$btnSave.Text = "Save"
	$btnSave.Dock = 'Bottom'
	$btnSave.Add_Click({
			$textBox.Text | Set-Content $gmdbPath
			[System.Windows.Forms.MessageBox]::Show("Saved successfully.", "Saved", "OK", "Information")
		})
	
	$editorForm.Controls.AddRange(@($textBox, $btnSave))
	$editorForm.ShowDialog()
	
}

$verify_Click={
	
	$json = Get-Content $gmdbPath -Raw | ConvertFrom-Json
	$hooked = $json.games.Count
	$missing = ($json.games | Where-Object { -not (Test-Path $_.exe_path) }).Count
	[System.Windows.Forms.MessageBox]::Show("✔ $hooked games hooked`n⚠ $missing executables missing", "Adrenaline Hook Summary", "OK", "Information")
	
}



$info_Click={
	
	# System Info Panel
	function Show-SystemInfo
	{
		$gpu = Get-WmiObject Win32_VideoController | Select-Object -First 1
		$info = @(
			"Adrenaline Hook Version: v1.0.7"
			"GPU: $($gpu.Name)"
			"Driver: $($gpu.DriverVersion)"
			"VRAM: {0:N2} GB" -f ($gpu.AdapterRAM / 1GB)
			"Windows Version: $([System.Environment]::OSVersion.Version.ToString())"
			"Processes: $((Get-Process).Count) running"
		) -join "`n"
		
		[System.Windows.Forms.MessageBox]::Show($info, "System Info", "OK", "Information")
	}
	
	Show-SystemInfo
	
}

$reset_Click={
	
	$confirm = [System.Windows.Forms.MessageBox]::Show(
		"Would you like to reset AMD Adrenaline Game settings database?",
		"Confirm Reset",
		"YesNo",
		"Question"
	)
	
	if ($confirm -eq "Yes")
	{
		$blbPath = "$env:LOCALAPPDATA\AMD\CN\gmdb.blb"
		if (Test-Path $blbPath)
		{
			Remove-Item $blbPath -Force
		}
		
		[System.Windows.Forms.MessageBox]::Show(
			"Database has been reset! - AMD Adrenaline Software will start soon to rebuild the database",
			"Reset Complete",
			"OK",
			"Information"
		)
		
		$targetAppName = "AMD Software"
		$app = Get-StartApps | Where-Object { $_.Name -eq $targetAppName }
		
		if ($app)
		{
			Start-Process "shell:AppsFolder\$($app.AppID)"
		}
		else
		{
			[System.Windows.Forms.MessageBox]::Show("App '$targetAppName' not found among installed UWP apps.", "Launch Failed", "OK", "Warning")
		}
	}
	
}

