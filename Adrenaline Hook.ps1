# TetraDev
# Adrenaline Hook is a tool whose purpose is to add any GamePass titles/applications to the AMD Adrenaline Software.
# Built using PowerShell Studio 2023
# Version 1.0.1
# Github Profile "https://github.com/tetraguy"

# Terminate AMD Software Process
Get-Process -Name "RadeonSoftware" -ErrorAction SilentlyContinue | ForEach-Object {
	Stop-Process -Id $_.Id -Force
	Write-Output "Terminated: $($_.ProcessName) (ID: $($_.Id))"
}

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
$formAdrenalineHook_Load = {
	
	
}

# Set Globals Variables
$selectedItems = @()
$gmdbPath = "$env:LOCALAPPDATA\AMD\CN\gmdb.blb"
$gamesList = @()

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
function Update-ListViewColumnSort
{

	
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

$buttonScanMSStoreAppsGameP_Click={
	
	$listView.Items.Clear()
	
	# Scan for installed UWP applications
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
				
				# Check for MicrosoftGame.config
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
					$listView.Sorting = 'Ascending'
					
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
	
	# Add selected applications to AMD Software
	Get-Process -Name "RadeonSoftware" -ErrorAction SilentlyContinue | ForEach-Object {
		Stop-Process -Id $_.Id -Force
		Write-Output "Terminated: $($_.ProcessName) (ID: $($_.Id))"
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
	
	$msg = "Do you want to hook the following apps?`n`n" + ($selectedItems | ForEach-Object { $_.Name }) -join "`n"
	$result = [System.Windows.Forms.MessageBox]::Show($msg, "Confirm", "YesNo", "Question")
	
	if ($result -eq "No")
	{
		[System.Windows.Forms.MessageBox]::Show("Import Aborted!", "Canceled", "OK", "Information")
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
			upscaling_sharpness = 75
			upscaling_target_resolution = ""
			upscaling_use_borderless = "FALSE"
			useEyefinity	    = "FALSE"
			userprofiletype	    = -1
			week_played_mins    = 0
		}
		$json.games += $newGame
	}
	
	$json | ConvertTo-Json -Depth 100 | Set-Content -Path $gmdbPath -Encoding UTF8
	Stop-Process -Name "AMDSoftware" -ErrorAction SilentlyContinue
	$listView.Items.Clear()
	[System.Windows.Forms.MessageBox]::Show("Programs hooked to AMD Adrenaline!", "Success", "OK", "Information")
	
}

$buttonScanInstalledProgram_Click={
	
	$listView.Items.Clear()
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
	}
	
}

$buttonHookProgramManually_Click={

	
	while ($true)
	{
		$dialog = New-Object Windows.Forms.OpenFileDialog
		$dialog.Filter = "Executable Files (*.exe)|*.exe"
		$dialog.InitialDirectory = "c:\"
		$dialog.Title = "Select a Game Excutable You Want to Add to AMD Software"
		if ($dialog.ShowDialog() -eq "OK")
		{
			$exePath = $dialog.FileName
			$exeName = [System.IO.Path]::GetFileName($exePath)
			$title = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
			$result = [System.Windows.Forms.MessageBox]::Show("Do you want to hook '$exeName' to AMD Adrenaline?", "Confirm", "YesNo", "Question")
			if ($result -eq "Yes")
			{		
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
					last_played_mins    = 0
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
					total_played_mins   = 0
					uninstall_location  = -1
					uninstalled		    = "FALSE"
					uplay_id		    = -1
					upscaling_enabled   = "FALSE"
					upscaling_sharpness = 75
					upscaling_target_resolution = ""
					upscaling_use_borderless = "FALSE"
					useEyefinity	    = "FALSE"
					userprofiletype	    = -1
					week_played_mins    = 0
				}
				
				$json.games += $newGame
				$json | ConvertTo-Json -Depth 100 | Set-Content -Path $gmdbPath -Encoding UTF8
				[System.Windows.Forms.MessageBox]::Show("$title hooked successfully!", "Success", "OK", "Information")
				break
			}
		}
		else
		{
			break
		}
	}
	
		Get-Process -Name "RadeonSoftware" -ErrorAction SilentlyContinue | ForEach-Object {
		Stop-Process -Id $_.Id -Force
		Write-Output "Terminated: $($_.ProcessName) (ID: $($_.Id))"
	}
}

$buttonOpenAMDSoftware_Click ={
	
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

$buttonViewHookedGames_Click={
	
	if (Test-Path $gmdbPath)
	{
		try
		{
			$json = Get-Content $gmdbPath -Raw | ConvertFrom-Json
			$titles = $json.games | ForEach-Object { $_.title }
			
			# Create a new form for the scrollable list
			$popup = New-Object Windows.Forms.Form
			$popup.Text = "Hooked Games"
			$popup.Size = New-Object Drawing.Size(400, 500)
			$popup.StartPosition = "CenterParent"
			
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

$buttonRemoveHookedApplicat_Click={
	
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

$linklabelCheckForUpdates_LinkClicked=[System.Windows.Forms.LinkLabelLinkClickedEventHandler]{
#Event Argument: $_ = [System.Windows.Forms.LinkLabelLinkClickedEventArgs]
	
	Start-Process "https://github.com/tetraguy/Adrenaline-Hook"
	
	
}
