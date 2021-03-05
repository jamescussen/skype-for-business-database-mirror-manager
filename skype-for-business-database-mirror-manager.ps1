########################################################################
# Name: Lync 2013 / Skype4B Database Mirror Manager 
# Version: v1.0.5 (23/3/2016)
# Created On: 2/5/2013
# Created By: James Cussen
# More Info: http://www.myskypelab.com
#
# Copyright: Copyright (c) 2016, James Cussen (www.myskypelab.com) All rights reserved.
# Licence: 	Redistribution and use of script, source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#				1) Redistributions of script code must retain the above copyright notice, this list of conditions and the following disclaimer.
#				2) Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#				3) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#				4) This license does not include any resale or commercial use of this software.
#				5) Any portion of this software may not be reproduced, duplicated, copied, sold, resold, or otherwise exploited for any commercial purpose without express written consent of James Cussen.
#			THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; LOSS OF GOODWILL OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Release Notes:
# 1.00 Initial Release.
# 1.01 Enhancements: 
#      - Added enhanced handling of error states so the GUI doesn't display the option to change the mirror state of databases 
#      that aren't mirrored. I noticed this when doing CU updates and disconnected mirrors giving "DatabaseInaccessibleOrMirroringNotEnabled"
#      errors that need to be handled in a way that makes sense in the GUI.
#
#      - Change the foreground colour of the database name label when the user has selected to change the state. This gives a visual
#      indication of what is going to be changed when the Invoke button is pressed (ie. Any database with a green label will be
#      changed over when the Invoke button is pressed.)	
#
# 1.02 Update
#	   - Added a check box for automatically agreeing to changeover without having to explicitly agree to every database change in the Powershell window.
#	   - Script now checks for the location of the central management store for Migration scenarios when it still resides on Lync 2010. This previously resulted in an error.
#	   - Suppressed warnings from Powershell window that would be displayed when getting status of databases that weren't available.	
#	   - Write the commands being run to Powershell window for more feedback to the user.
#	   - Database names are now listed in Powershell window with mirror state when refresh is done.
#	   - Script is now signed.
#	   - Updated the form icon.
#	   - Removed the dedicated Close button because it's unnecessary.
#
# 1.03 Update
#		- Added Powershell pre-req checks and Module loading.
#		- Updated reporting of database status in PS window
#		- Added Up and Down keys in the pool listbox 
#		- Updated to work with Skype for Business!
#
# 1.04 Update
#		- There were reports of issues on some versions of Powershell. ErrorVariable flags were removed in this version to fix these errors.
#
# 1.05 Updated Signature
#
########################################################################

$theVersion = $PSVersionTable.PSVersion
$MajorVersion = $theVersion.Major

Write-Host ""
Write-Host "--------------------------------------------------------------"
Write-Host "Powershell Version Check..." -foreground "yellow"
if($MajorVersion -eq  "1")
{
	Write-Host "This machine only has Version 1 Powershell installed.  This version of Powershell is not supported." -foreground "red"
}
elseif($MajorVersion -eq  "2")
{
	Write-Host "This machine has Version 2 Powershell installed. This version of Powershell is not supported." -foreground "red"
}
elseif($MajorVersion -eq  "3")
{
	Write-Host "This machine has version 3 Powershell installed. CHECK PASSED!" -foreground "green"
}
elseif($MajorVersion -eq  "4")
{
	Write-Host "This machine has version 4 Powershell installed. CHECK PASSED!" -foreground "green"
}
else
{
	Write-Host "This machine has version $MajorVersion Powershell installed. Unknown level of support for this version." -foreground "yellow"
}
Write-Host "--------------------------------------------------------------"
Write-Host ""

Function Get-MyModule 
{ 
Param([string]$name) 
	
	if(-not(Get-Module -name $name)) 
	{ 
		if(Get-Module -ListAvailable | Where-Object { $_.name -eq $name }) 
		{ 
			Import-Module -Name $name 
			return $true 
		} #end if module available then import 
		else 
		{ 
			return $false 
		} #module not available 
	} # end if not module 
	else 
	{ 
		return $true 
	} #module already loaded 
} #end function get-MyModule 


$Script:LyncModuleAvailable = $false
$Script:SkypeModuleAvailable = $false

Write-Host "--------------------------------------------------------------"
#Import Lync Module
if(Get-MyModule "Lync")
{
	Invoke-Expression "Import-Module Lync"
	Write-Host "Imported Lync Module..." -foreground "green"
	$Script:LyncModuleAvailable = $true
}
else
{
	Write-Host "Unable to import Lync Module... The Lync module is required to run this tool." -foreground "yellow"
}
#Import SkypeforBusiness Module
if(Get-MyModule "SkypeforBusiness")
{
	Invoke-Expression "Import-Module SkypeforBusiness"
	Write-Host "Imported SkypeforBusiness Module..." -foreground "green"
	$Script:SkypeModuleAvailable = $true
}
else
{
	Write-Host "Unable to import SkypeforBusiness Module... (Expected on a Lync 2013 system)" -foreground "yellow"
}


# Set the error preference ============================================================
$ErrorActionPreference = "SilentlyContinue"
$OutOfSyncMessage = "One or more of the SQL databases contained within the `"Database Types`" (listed above) have different Principal/Mirror states. To sync the databases to a single state, select the required Primary or Mirror state and Invoke the changeover."

# Set up the form  ============================================================

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 

$objForm = New-Object System.Windows.Forms.Form 
$objForm.Text = "Lync/Skype Mirror Manager v1.04"
$objForm.Size = New-Object System.Drawing.Size(350,610) 
$objForm.StartPosition = "CenterScreen"
[byte[]]$WindowIcon = @(66, 77, 56, 3, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 16, 0, 0, 0, 16, 0, 0, 0, 1, 0, 24, 0, 0, 0, 0, 0, 2, 3, 0, 0, 18, 11, 0, 0, 18, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114,0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0,198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 205, 132, 32, 234, 202, 160,255, 255, 255, 244, 229, 208, 205, 132, 32, 202, 123, 16, 248, 238, 224, 198, 114, 0, 205, 132, 32, 234, 202, 160, 255,255, 255, 255, 255, 255, 244, 229, 208, 219, 167, 96, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 248, 238, 224, 198, 114, 0, 198, 114, 0, 223, 176, 112, 255, 255, 255, 219, 167, 96, 198, 114, 0, 198, 114, 0, 255, 255, 255, 255, 255, 255, 227, 185, 128, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 241, 220, 192, 198, 114, 0, 198,114, 0, 248, 238, 224, 255, 255, 255, 244, 229, 208, 198, 114, 0, 198, 114, 0, 255, 255, 255, 255, 255, 255, 227, 185, 128, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 241, 220, 192, 198, 114, 0, 216, 158, 80, 255, 255, 255, 255, 255, 255, 252, 247, 240, 209, 141, 48, 198, 114, 0, 255, 255, 255, 255, 255, 255, 227, 185, 128, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 241, 220, 192, 198, 114, 0, 241, 220, 192, 255, 255, 255, 252, 247, 240, 212, 149, 64, 234, 202, 160, 198, 114, 0, 255, 255, 255, 255, 255, 255, 227, 185, 128, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 241, 220, 192, 205, 132, 32, 255, 255, 255, 255, 255, 255, 227, 185, 128, 198, 114, 0, 248, 238, 224, 202, 123, 16, 255, 255, 255, 255, 255, 255, 227, 185, 128, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 241, 220, 192, 234, 202, 160, 255, 255, 255, 255, 255, 255, 205, 132, 32, 198, 114, 0, 223, 176, 112, 223, 176, 112, 255, 255, 255, 255, 255, 255, 227, 185, 128, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 244, 229, 208, 252, 247, 240, 255, 255, 255, 237, 211, 176, 198, 114, 0, 198, 114, 0, 202, 123, 16, 248, 238, 224, 255, 255, 255, 255, 255, 255, 227, 185, 128, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 212, 149, 64, 255, 255, 255, 255, 255, 255, 255, 255, 255, 212, 149, 64, 198, 114, 0, 198, 114, 0, 198, 114, 0, 234, 202, 160, 255, 255,255, 255, 255, 255, 241, 220, 192, 205, 132, 32, 198, 114, 0, 198, 114, 0, 205, 132, 32, 227, 185, 128, 227, 185, 128, 227, 185, 128, 227, 185, 128, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 205, 132, 32, 227, 185, 128, 227, 185,128, 227, 185, 128, 219, 167, 96, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 198, 114, 0, 0, 0)
$ico = New-Object IO.MemoryStream($WindowIcon, 0, $WindowIcon.Length)
$objForm.Icon = [System.Drawing.Icon]::FromHandle((new-object System.Drawing.Bitmap -argument $ico).GetHIcon())
$objForm.KeyPreview = $True


# Add the listbox containing the Get-Cs cmdlets ============================================================

$objPoolsListbox = New-Object System.Windows.Forms.Listbox 
$objPoolsListbox.Location = New-Object System.Drawing.Size(20,30) 
$objPoolsListbox.Size = New-Object System.Drawing.Size(300,180) 


# Add Lync Pools
Get-CSService -UserServer | where-object {$_.version -eq "6" -or $_.version -eq "7"} | select-object PoolFQDN | ForEach-Object {[void] $objPoolsListbox.Items.Add($_.PoolFQDN);$pools +=  $_.PoolFQDN}

# Add Persistent Chat Pools
Get-CSService -PersistentChatServer | where-object {$_.version -eq "6" -or $_.version -eq "7"} | select-object PoolFQDN | select-object PoolFQDN| ForEach-Object {[void] $objPoolsListbox.Items.Add($_.PoolFQDN);$pools +=  $_.PoolFQDN}

  
$objForm.Controls.Add($objPoolsListbox) 

# Pools Click Event
$objPoolsListbox.add_Click(
{
    $script:pool = $objPoolsListbox.SelectedItem
	checkDatabase

})
$objPoolsListbox.add_KeyUp(
{
	if ($_.KeyCode -eq "Up" -or $_.KeyCode -eq "Down") 
	{	
		$script:pool = $objPoolsListbox.SelectedItem
		checkDatabase
	}
})

$objPrimaryLabel = New-Object System.Windows.Forms.Label
$objPrimaryLabel.Location = New-Object System.Drawing.Size(120,230) 
$objPrimaryLabel.Size = New-Object System.Drawing.Size(50,15) 
$objPrimaryLabel.Text = "Primary"
$objForm.Controls.Add($objPrimaryLabel)

$objPrimaryLabel = New-Object System.Windows.Forms.Label
$objPrimaryLabel.Location = New-Object System.Drawing.Size(170,230) 
$objPrimaryLabel.Size = New-Object System.Drawing.Size(60,15) 
$objPrimaryLabel.Text = "Secondary"
$objForm.Controls.Add($objPrimaryLabel)

$objPoolsLabel = New-Object System.Windows.Forms.Label
$objPoolsLabel.Location = New-Object System.Drawing.Size(20,15) 
$objPoolsLabel.Size = New-Object System.Drawing.Size(100,15) 
$objPoolsLabel.Text = "Available Pools"
$objForm.Controls.Add($objPoolsLabel)


###### INITIALISE VARIABLES ###########
$script:physicalStateUSERPrimary = $false
$script:physicalStateUSERMirror = $false
$script:physicalStateAPPPrimary = $false
$script:physicalStateAPPMirror = $false
$script:physicalStateCentralMgmtPrimary = $false
$script:physicalStateCentralMgmtMirror = $false
$script:physicalStateArchivingPrimary = $false
$script:physicalStateArchivingMirror = $false
$script:physicalStateMonitoringPrimary = $false
$script:physicalStateMonitoringMirror = $false
$script:physicalStatePersistentChatPrimary = $false
$script:physicalStatePersistentChatMirror = $false
$script:physicalStatePersistentChatCompliancePrimary = $false
$script:physicalStatePersistentChatComplianceMirror = $false


#Auto Accept
$AutoAcceptLabel = New-Object System.Windows.Forms.Label
$AutoAcceptLabel.Location = New-Object System.Drawing.Size(190,208) 
$AutoAcceptLabel.Size = New-Object System.Drawing.Size(110,15) 
$AutoAcceptLabel.Text = "Auto Accept Failover"
$objForm.Controls.Add($AutoAcceptLabel)

$AutoAcceptCheckBox = New-Object System.Windows.Forms.Checkbox 
$AutoAcceptCheckBox.Location = New-Object System.Drawing.Size(300,206) 
$AutoAcceptCheckBox.Size = New-Object System.Drawing.Size(20,20)
$AutoAcceptCheckBox.Add_Click({
})
$objForm.Controls.Add($AutoAcceptCheckBox) 
$AutoAcceptCheckBox.Checked = $false



################# INITIALIZE USER DATABASE ################## 
 
$objDatabaseUSERPrincipal = New-Object System.Windows.Forms.Checkbox 
$objDatabaseUSERPrincipal.Location = New-Object System.Drawing.Size(130,250) 
$objDatabaseUSERPrincipal.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseUSERPrincipal.Add_Click({
$objDatabaseUSERMirror.checked = !$objDatabaseUSERMirror.checked
if($objDatabaseUSERMirror.checked -and $physicalStateUSERMirror -eq $false) 
{$objDatabaseUSERLabel.ForeColor = "Green"}
if($objDatabaseUSERPrincipal.checked -and $physicalStateUSERPrimary -eq $false) 
{$objDatabaseUSERLabel.ForeColor = "Green"}
else
{$objDatabaseUSERLabel.ForeColor = "Black"}
})

$objForm.Controls.Add($objDatabaseUSERPrincipal) 

  
   
$objDatabaseUSERMirror = New-Object System.Windows.Forms.Checkbox 
$objDatabaseUSERMirror.Location = New-Object System.Drawing.Size(180,250) 
$objDatabaseUSERMirror.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseUSERMirror.Add_Click({
$objDatabaseUSERPrincipal.checked = !$objDatabaseUSERPrincipal.checked
if($objDatabaseUSERMirror.checked -and $physicalStateUSERMirror -eq $false) 
{$objDatabaseUSERLabel.ForeColor = "Green"}
elseif($objDatabaseUSERPrincipal.checked -and $physicalStateUSERPrimary -eq $false) 
{$objDatabaseUSERLabel.ForeColor = "Green"}
else
{$objDatabaseUSERLabel.ForeColor = "Black"}
})
$objForm.Controls.Add($objDatabaseUSERMirror) 


$objDatabaseUSERPrincipal.Checked = $false
$objDatabaseUSERMirror.Checked = $false

$objDatabaseUSERLabel = New-Object System.Windows.Forms.Label
$objDatabaseUSERLabel.Location = New-Object System.Drawing.Size(30,250) 
$objDatabaseUSERLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseUSERLabel.Text = "User"
$objForm.Controls.Add($objDatabaseUSERLabel)


$objDatabaseUSERStatusLabel = New-Object System.Windows.Forms.Label
$objDatabaseUSERStatusLabel.Location = New-Object System.Drawing.Size(210,250) 
$objDatabaseUSERStatusLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseUSERStatusLabel.Text = ""
$objDatabaseUSERStatusLabel.forecolor = "red"
$objForm.Controls.Add($objDatabaseUSERStatusLabel)


################# INITIALIZE APP DATABASE ################## 

$objDatabaseAPPPrincipal = New-Object System.Windows.Forms.Checkbox 
$objDatabaseAPPPrincipal.Location = New-Object System.Drawing.Size(130,280) 
$objDatabaseAPPPrincipal.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseAPPPrincipal.Add_Click({
$objDatabaseAPPMirror.checked = !$objDatabaseAPPMirror.checked
if($objDatabaseAPPMirror.checked -and $physicalStateAPPMirror -eq $false) 
{$objDatabaseAPPLabel.ForeColor = "Green"}
elseif($objDatabaseAPPPrincipal.checked -and $physicalStateAPPPrimary -eq $false) 
{$objDatabaseAPPLabel.ForeColor = "Green"}
else
{$objDatabaseAPPLabel.ForeColor = "Black"}
})
  
$objForm.Controls.Add($objDatabaseAPPPrincipal) 
  
$objDatabaseAPPMirror = New-Object System.Windows.Forms.Checkbox 
$objDatabaseAPPMirror.Location = New-Object System.Drawing.Size(180,280) 
$objDatabaseAPPMirror.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseAPPMirror.Add_Click({
$objDatabaseAPPPrincipal.checked = !$objDatabaseAPPPrincipal.checked
if($objDatabaseAPPMirror.checked -and $physicalStateAPPMirror -eq $false) 
{$objDatabaseAPPLabel.ForeColor = "Green"}
elseif($objDatabaseAPPPrincipal.checked -and $physicalStateAPPPrimary -eq $false) 
{$objDatabaseAPPLabel.ForeColor = "Green"}
else
{$objDatabaseAPPLabel.ForeColor = "Black"}
})
  
$objForm.Controls.Add($objDatabaseAPPMirror) 

$objDatabaseAPPLabel = New-Object System.Windows.Forms.Label
$objDatabaseAPPLabel.Location = New-Object System.Drawing.Size(30,280) 
$objDatabaseAPPLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseAPPLabel.Text = "App"
$objForm.Controls.Add($objDatabaseAPPLabel)

$objDatabaseAPPPrincipal.Checked = $false
$objDatabaseAPPMirror.Checked = $false


$objDatabaseAPPStatusLabel = New-Object System.Windows.Forms.Label
$objDatabaseAPPStatusLabel.Location = New-Object System.Drawing.Size(210,280) 
$objDatabaseAPPStatusLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseAPPStatusLabel.Text = ""
$objDatabaseAPPStatusLabel.forecolor = "red"
$objForm.Controls.Add($objDatabaseAPPStatusLabel)


################# INITIALIZE CENTRAL MANAGEMENT DATABASE ################## 

$objDatabaseCentralMgmtPrincipal = New-Object System.Windows.Forms.Checkbox 
$objDatabaseCentralMgmtPrincipal.Location = New-Object System.Drawing.Size(130,310) 
$objDatabaseCentralMgmtPrincipal.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseCentralMgmtPrincipal.Add_Click({
$objDatabaseCentralMgmtMirror.checked = !$objDatabaseCentralMgmtMirror.checked
if($objDatabaseCentralMgmtMirror.checked -and $physicalStateCentralMgmtMirror -eq $false) 
{$objDatabaseCentralMgmtLabel.ForeColor = "Green"}
elseif($objDatabaseCentralMgmtPrincipal.checked -and $physicalStateCentralMgmtPrimary -eq $false) 
{$objDatabaseCentralMgmtLabel.ForeColor = "Green"}
else
{$objDatabaseCentralMgmtLabel.ForeColor = "Black"}
})
  
$objForm.Controls.Add($objDatabaseCentralMgmtPrincipal) 
  
$objDatabaseCentralMgmtMirror = New-Object System.Windows.Forms.Checkbox 
$objDatabaseCentralMgmtMirror.Location = New-Object System.Drawing.Size(180,310) 
$objDatabaseCentralMgmtMirror.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseCentralMgmtMirror.Add_Click({
$objDatabaseCentralMgmtPrincipal.checked = !$objDatabaseCentralMgmtPrincipal.checked
if($objDatabaseCentralMgmtMirror.checked -and $physicalStateCentralMgmtMirror -eq $false) 
{$objDatabaseCentralMgmtLabel.ForeColor = "Green"}
elseif($objDatabaseCentralMgmtPrincipal.checked -and $physicalStateCentralMgmtPrimary -eq $false) 
{$objDatabaseCentralMgmtLabel.ForeColor = "Green"}
else
{$objDatabaseCentralMgmtLabel.ForeColor = "Black"}
})
  
$objForm.Controls.Add($objDatabaseCentralMgmtMirror) 

$objDatabaseCentralMgmtLabel = New-Object System.Windows.Forms.Label
$objDatabaseCentralMgmtLabel.Location = New-Object System.Drawing.Size(30,310) 
$objDatabaseCentralMgmtLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseCentralMgmtLabel.Text = "CentralMgmt"
$objForm.Controls.Add($objDatabaseCentralMgmtLabel)

$objDatabaseCentralMgmtPrincipal.Checked = $false
$objDatabaseCentralMgmtMirror.Checked = $false


$objDatabaseCentralMgmtStatusLabel = New-Object System.Windows.Forms.Label
$objDatabaseCentralMgmtStatusLabel.Location = New-Object System.Drawing.Size(210,310) 
$objDatabaseCentralMgmtStatusLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseCentralMgmtStatusLabel.Text = ""
$objDatabaseCentralMgmtStatusLabel.forecolor = "red"
$objForm.Controls.Add($objDatabaseCentralMgmtStatusLabel)


#################  INITIALIZE  ARCHIVING DATABASE ################## 

$objDatabaseArchivingPrincipal = New-Object System.Windows.Forms.Checkbox 
$objDatabaseArchivingPrincipal.Location = New-Object System.Drawing.Size(130,340) 
$objDatabaseArchivingPrincipal.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseArchivingPrincipal.Add_Click({
$objDatabaseArchivingMirror.checked = !$objDatabaseArchivingMirror.checked
if($objDatabaseArchivingMirror.checked -and $physicalStateArchivingMirror -eq $false) 
{$objDatabaseArchivingLabel.ForeColor = "Green"}
elseif($objDatabaseArchivingPrincipal.checked -and $physicalStateArchivingPrimary -eq $false) 
{$objDatabaseArchivingLabel.ForeColor = "Green"}
else
{$objDatabaseArchivingLabel.ForeColor = "Black"}
})
  
$objForm.Controls.Add($objDatabaseArchivingPrincipal) 
  
$objDatabaseArchivingMirror = New-Object System.Windows.Forms.Checkbox 
$objDatabaseArchivingMirror.Location = New-Object System.Drawing.Size(180,340) 
$objDatabaseArchivingMirror.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseArchivingMirror.Add_Click({
$objDatabaseArchivingPrincipal.checked = !$objDatabaseArchivingPrincipal.checked
if($objDatabaseArchivingMirror.checked -and $physicalStateArchivingMirror -eq $false) 
{$objDatabaseArchivingLabel.ForeColor = "Green"}
elseif($objDatabaseArchivingPrincipal.checked -and $physicalStateArchivingPrimary -eq $false) 
{$objDatabaseArchivingLabel.ForeColor = "Green"}
else
{$objDatabaseArchivingLabel.ForeColor = "Black"}
})
  
$objForm.Controls.Add($objDatabaseArchivingMirror) 

$objDatabaseArchivingLabel = New-Object System.Windows.Forms.Label
$objDatabaseArchivingLabel.Location = New-Object System.Drawing.Size(30,340) 
$objDatabaseArchivingLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseArchivingLabel.Text = "Archiving"
$objForm.Controls.Add($objDatabaseArchivingLabel)

$objDatabaseArchivingPrincipal.Checked = $false
$objDatabaseArchivingMirror.Checked = $false

$objDatabaseArchivingStatusLabel = New-Object System.Windows.Forms.Label
$objDatabaseArchivingStatusLabel.Location = New-Object System.Drawing.Size(210,340) 
$objDatabaseArchivingStatusLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseArchivingStatusLabel.Text = ""
$objDatabaseArchivingStatusLabel.forecolor = "red"
$objForm.Controls.Add($objDatabaseArchivingStatusLabel)


#################  INITIALIZE  MONITORING DATABASE ################## 

$objDatabaseMonitoringPrincipal = New-Object System.Windows.Forms.Checkbox 
$objDatabaseMonitoringPrincipal.Location = New-Object System.Drawing.Size(130,370) 
$objDatabaseMonitoringPrincipal.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseMonitoringPrincipal.Add_Click({
$objDatabaseMonitoringMirror.checked = !$objDatabaseMonitoringMirror.checked
if($objDatabaseMonitoringMirror.checked -and $physicalStateMonitoringMirror -eq $false) 
{$objDatabaseMonitoringLabel.ForeColor = "Green"}
elseif($objDatabaseMonitoringPrincipal.checked -and $physicalStateMonitoringPrimary -eq $false) 
{$objDatabaseMonitoringLabel.ForeColor = "Green"}
else
{$objDatabaseMonitoringLabel.ForeColor = "Black"}
})
  
$objForm.Controls.Add($objDatabaseMonitoringPrincipal) 
  
$objDatabaseMonitoringMirror = New-Object System.Windows.Forms.Checkbox 
$objDatabaseMonitoringMirror.Location = New-Object System.Drawing.Size(180,370) 
$objDatabaseMonitoringMirror.Size = New-Object System.Drawing.Size(20,20)
$objDatabaseMonitoringMirror.Add_Click({
$objDatabaseMonitoringPrincipal.checked = !$objDatabaseMonitoringPrincipal.checked
if($objDatabaseMonitoringMirror.checked -and $physicalStateMonitoringMirror -eq $false) 
{$objDatabaseMonitoringLabel.ForeColor = "Green"}
elseif($objDatabaseMonitoringPrincipal.checked -and $physicalStateMonitoringPrimary -eq $false) 
{$objDatabaseMonitoringLabel.ForeColor = "Green"}
else
{$objDatabaseMonitoringLabel.ForeColor = "Black"}
})

$objForm.Controls.Add($objDatabaseMonitoringMirror) 

$objDatabaseMonitoringLabel = New-Object System.Windows.Forms.Label
$objDatabaseMonitoringLabel.Location = New-Object System.Drawing.Size(30,370) 
$objDatabaseMonitoringLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseMonitoringLabel.Text = "Monitoring"
$objForm.Controls.Add($objDatabaseMonitoringLabel)

$objDatabaseMonitoringPrincipal.Checked = $false
$objDatabaseMonitoringMirror.Checked = $false

$objDatabaseMonitoringStatusLabel = New-Object System.Windows.Forms.Label
$objDatabaseMonitoringStatusLabel.Location = New-Object System.Drawing.Size(210,370) 
$objDatabaseMonitoringStatusLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabaseMonitoringStatusLabel.Text = ""
$objDatabaseMonitoringStatusLabel.forecolor = "red"
$objForm.Controls.Add($objDatabaseMonitoringStatusLabel)

#################  INITIALIZE  PERSISTENT CHAT DATABASE ################## 

$objDatabasePersistentChatPrincipal = New-Object System.Windows.Forms.Checkbox 
$objDatabasePersistentChatPrincipal.Location = New-Object System.Drawing.Size(130,400) 
$objDatabasePersistentChatPrincipal.Size = New-Object System.Drawing.Size(20,20)
$objDatabasePersistentChatPrincipal.Add_Click({
$objDatabasePersistentChatMirror.checked = !$objDatabasePersistentChatMirror.checked
if($objDatabasePersistentChatMirror.checked -and $physicalStatePersistentChatMirror -eq $false) 
{$objDatabasePersistentChatLabel.ForeColor = "Green"}
elseif($objDatabasePersistentChatPrincipal.checked -and $physicalStatePersistentChatPrimary -eq $false) 
{$objDatabasePersistentChatLabel.ForeColor = "Green"}
else
{$objDatabasePersistentChatLabel.ForeColor = "Black"}
})

$objForm.Controls.Add($objDatabasePersistentChatPrincipal) 
  
$objDatabasePersistentChatMirror = New-Object System.Windows.Forms.Checkbox 
$objDatabasePersistentChatMirror.Location = New-Object System.Drawing.Size(180,400) 
$objDatabasePersistentChatMirror.Size = New-Object System.Drawing.Size(20,20)
$objDatabasePersistentChatMirror.Add_Click({
$objDatabasePersistentChatPrincipal.checked = !$objDatabasePersistentChatPrincipal.checked
if($objDatabasePersistentChatMirror.checked -and $physicalStatePersistentChatMirror -eq $false) 
{$objDatabasePersistentChatLabel.ForeColor = "Green"}
elseif($objDatabasePersistentChatPrincipal.checked -and $physicalStatePersistentChatPrimary -eq $false) 
{$objDatabasePersistentChatLabel.ForeColor = "Green"}
else
{$objDatabasePersistentChatLabel.ForeColor = "Black"}
})
  
$objForm.Controls.Add($objDatabasePersistentChatMirror) 

$objDatabasePersistentChatLabel = New-Object System.Windows.Forms.Label
$objDatabasePersistentChatLabel.Location = New-Object System.Drawing.Size(30,400) 
$objDatabasePersistentChatLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabasePersistentChatLabel.Text = "PersistentChat"
$objForm.Controls.Add($objDatabasePersistentChatLabel)

$objDatabasePersistentChatPrincipal.Checked = $false
$objDatabasePersistentChatMirror.Checked = $false

$objDatabasePersistentChatStatusLabel = New-Object System.Windows.Forms.Label
$objDatabasePersistentChatStatusLabel.Location = New-Object System.Drawing.Size(210,400) 
$objDatabasePersistentChatStatusLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabasePersistentChatStatusLabel.Text = ""
$objDatabasePersistentChatStatusLabel.forecolor = "red"
$objForm.Controls.Add($objDatabasePersistentChatStatusLabel)

#################  INITIALIZE  PERSISTENT CHAT COMPLIENCE DATABASE ################## 

$objDatabasePersistentChatCompliancePrincipal = New-Object System.Windows.Forms.Checkbox 
$objDatabasePersistentChatCompliancePrincipal.Location = New-Object System.Drawing.Size(130,430) 
$objDatabasePersistentChatCompliancePrincipal.Size = New-Object System.Drawing.Size(20,20)
$objDatabasePersistentChatCompliancePrincipal.Add_Click({
$objDatabasePersistentChatComplianceMirror.checked = !$objDatabasePersistentChatComplianceMirror.checked
if($objDatabasePersistentChatComplianceMirror.checked -and $physicalStatePersistentChatComplianceMirror -eq $false) 
{$objDatabasePersistentChatComplianceLabel.ForeColor = "Green"}
elseif($objDatabasePersistentChatCompliancePrincipal.checked -and $physicalStatePersistentChatCompliancePrimary -eq $false) 
{$objDatabasePersistentChatComplianceLabel.ForeColor = "Green"}
else
{$objDatabasePersistentChatComplianceLabel.ForeColor = "Black"}
})

$objForm.Controls.Add($objDatabasePersistentChatCompliancePrincipal) 
  
$objDatabasePersistentChatComplianceMirror = New-Object System.Windows.Forms.Checkbox 
$objDatabasePersistentChatComplianceMirror.Location = New-Object System.Drawing.Size(180,430) 
$objDatabasePersistentChatComplianceMirror.Size = New-Object System.Drawing.Size(20,20)
$objDatabasePersistentChatComplianceMirror.Add_Click({
$objDatabasePersistentChatCompliancePrincipal.checked = !$objDatabasePersistentChatCompliancePrincipal.checked
if($objDatabasePersistentChatComplianceMirror.checked -and $physicalStatePersistentChatComplianceMirror -eq $false) 
{$objDatabasePersistentChatComplianceLabel.ForeColor = "Green"}
elseif($objDatabasePersistentChatCompliancePrincipal.checked -and $physicalStatePersistentChatCompliancePrimary -eq $false) 
{$objDatabasePersistentChatComplianceLabel.ForeColor = "Green"}
else
{$objDatabasePersistentChatComplianceLabel.ForeColor = "Black"}
})

$objForm.Controls.Add($objDatabasePersistentChatComplianceMirror) 

$objDatabasePersistentChatComplianceLabel = New-Object System.Windows.Forms.Label
$objDatabasePersistentChatComplianceLabel.Location = New-Object System.Drawing.Size(30,430) 
$objDatabasePersistentChatComplianceLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabasePersistentChatComplianceLabel.Text = "ChatCompliance"
$objForm.Controls.Add($objDatabasePersistentChatComplianceLabel)

$objDatabasePersistentChatCompliancePrincipal.Checked = $false
$objDatabasePersistentChatComplianceMirror.Checked = $false

$objDatabasePersistentChatComplianceStatusLabel = New-Object System.Windows.Forms.Label
$objDatabasePersistentChatComplianceStatusLabel.Location = New-Object System.Drawing.Size(210,430) 
$objDatabasePersistentChatComplianceStatusLabel.Size = New-Object System.Drawing.Size(100,15) 
$objDatabasePersistentChatComplianceStatusLabel.Text = ""
$objDatabasePersistentChatComplianceStatusLabel.forecolor = "red"
$objForm.Controls.Add($objDatabasePersistentChatComplianceStatusLabel)


$objDatabaseOutOfSyncStatusLabel = New-Object System.Windows.Forms.Label
$objDatabaseOutOfSyncStatusLabel.Location = New-Object System.Drawing.Size(30,460) 
$objDatabaseOutOfSyncStatusLabel.Size = New-Object System.Drawing.Size(300,60) 
$objDatabaseOutOfSyncStatusLabel.Text = ""
$objDatabaseOutOfSyncStatusLabel.forecolor = "red"
$objForm.Controls.Add($objDatabaseOutOfSyncStatusLabel)


  
# Add the Invoke button ============================================================

$invokeButton = New-Object System.Windows.Forms.Button
$invokeButton.Location = New-Object System.Drawing.Size(80,530)
$invokeButton.Size = New-Object System.Drawing.Size(75,23)
$invokeButton.Text = "Invoke"
$invokeButton.Add_Click(
{
	$StatusLabel.Text = "Processing..."
	[System.Windows.Forms.Application]::DoEvents()
	#######Invoke a database changeover
	invokeDatabaseChange

	Start-Sleep -s 4
	Write-host ""
	Write-host "---------------------------------------------------"
	Write-host ""

	#######Refresh the settings after database change over has happened
	checkDatabase
	$StatusLabel.Text = ""
})
$objForm.Controls.Add($invokeButton)  

$invokeButton.enabled = $false  


# Add the Invoke button ============================================================

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Size(175,530)
$refreshButton.Size = New-Object System.Drawing.Size(75,23)
$refreshButton.Text = "Refresh"
$refreshButton.Add_Click(
{
	$StatusLabel.Text = "Processing..."
	[System.Windows.Forms.Application]::DoEvents()
	#######Refresh the settings after database change over has happened
	checkDatabase
	$StatusLabel.Text = ""
})
$objForm.Controls.Add($refreshButton)  


# $StatusLabel ============================================================
$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Location = New-Object System.Drawing.Size(10,555) 
$StatusLabel.Size = New-Object System.Drawing.Size(400,15) 
$StatusLabel.Text = ""
$StatusLabel.ForeColor = [System.Drawing.Color]::Red
$StatusLabel.TabStop = $false
$objForm.Controls.Add($StatusLabel)


$objDatabaseUSERPrincipal.Hide()
$objDatabaseUSERMirror.Hide()
$objDatabaseAPPPrincipal.Hide()
$objDatabaseAPPMirror.Hide()
$objDatabaseCentralMgmtPrincipal.Hide()
$objDatabaseCentralMgmtMirror.Hide()
$objDatabaseArchivingPrincipal.Hide()
$objDatabaseArchivingMirror.Hide()
$objDatabaseMonitoringPrincipal.Hide()
$objDatabaseMonitoringMirror.Hide()
$objDatabasePersistentChatPrincipal.Hide()
$objDatabasePersistentChatMirror.Hide()
$objDatabasePersistentChatCompliancePrincipal.Hide()
$objDatabasePersistentChatComplianceMirror.Hide()  


function invokeDatabaseChange
{

Write-host "---------------------------------------------------"

######## INVOKE USER DATABASE ##########
if($objDatabaseUSERStatusLabel.Text -eq "Out of Sync")
{
	if($objDatabaseUSERPrincipal.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of USER database to Primary..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal primary -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal primary" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal primary
		}
	}
	elseif ($objDatabaseUSERMirror.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of USER database to Mirror..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal mirror -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal mirror" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal mirror
		}
	}
}
elseif($objDatabaseUSERPrincipal.Checked -eq $true -and $physicalStateUSERMirror -eq $objDatabaseUSERPrincipal.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of USER database to Primary..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal primary -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal primary" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal primary
	}
}
elseif($objDatabaseUSERMirror.Checked -eq $true -and $physicalStateUSERPrimary -eq $objDatabaseUSERMirror.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of USER database to Mirror..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal mirror -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal mirror" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType User –NewPrincipal mirror
	}
}

######## INVOKE APP DATABASE ##########
if($objDatabaseAPPStatusLabel.Text -eq "Out of Sync")
{
	if($objDatabaseAPPPrincipal.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of Application database to Primary..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal primary -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal primary" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal primary
		}
	}
	elseif ($objDatabaseAPPMirror.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of Application database to Mirror" -ForegroundColor Green
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal mirror -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal mirror" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal mirror
		}
	}
}
elseif($objDatabaseAPPPrincipal.Checked -eq $true -and $physicalStateAPPMirror -eq $objDatabaseAPPPrincipal.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of Application database to Primary..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal primary -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal primary" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal primary
	}
}
elseif($objDatabaseAPPMirror.Checked -eq $true -and $physicalStateAPPPrimary -eq $objDatabaseAPPMirror.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of Application database to Mirror..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal mirror -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal mirror" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Application –NewPrincipal mirror
	}
}

######## INVOKE CentralMgmt DATABASE ##########
if($objDatabaseCentralMgmtStatusLabel.Text -eq "Out of Sync")
{
	if($objDatabaseCentralMgmtPrincipal.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of CentralMgmt database to Primary..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal primary -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal primary" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal primary
		}
	}
	elseif ($objDatabaseCentralMgmtMirror.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of CentralMgmt database to Mirror..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal mirror -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal mirror" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal mirror
		}
	}
}
elseif($objDatabaseCentralMgmtPrincipal.Checked -eq $true -and $physicalStateCentralMgmtMirror -eq $objDatabaseCentralMgmtPrincipal.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of CentralMgmt database to Primary..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal primary -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal primary" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal primary
	}
}
elseif($objDatabaseCentralMgmtMirror.Checked -eq $true -and $physicalStateCentralMgmtPrimary -eq $objDatabaseCentralMgmtMirror.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of CentralMgmt database to Mirror..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal mirror -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal mirror" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType CentralMgmt –NewPrincipal mirror
	}
}

######## INVOKE Archiving DATABASE ##########
if($objDatabaseArchivingStatusLabel.Text -eq "Out of Sync")
{
	if($objDatabaseArchivingPrincipal.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of Archiving database to Primary..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal primary" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal primary
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal primary -Confirm:$false
		}
	}
	elseif ($objDatabaseArchivingMirror.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of Archiving database to Mirror..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal mirror -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal mirror" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal mirror
		}
	}
}
elseif($objDatabaseArchivingPrincipal.Checked -eq $true -and $physicalStateArchivingMirror -eq $objDatabaseArchivingPrincipal.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of Archiving database to Primary..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal primary -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal primary" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal primary
	}
}
elseif($objDatabaseArchivingMirror.Checked -eq $true -and $physicalStateArchivingPrimary -eq $objDatabaseArchivingMirror.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of Archiving database to Mirror..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal mirror -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal mirror" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Archiving –NewPrincipal mirror
	}
}

######## INVOKE Monitoring DATABASE ##########
if($objDatabaseMonitoringStatusLabel.Text -eq "Out of Sync")
{
	if($objDatabaseMonitoringPrincipal.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of Monitoring database to Primary..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal primary -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal primary" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal primary
		}
	}
	elseif ($objDatabaseMonitoringMirror.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of Monitoring database to Mirror..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal mirror -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal mirror" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal mirror
		}
	}
}
elseif($objDatabaseMonitoringPrincipal.Checked -eq $true -and $physicalStateMonitoringMirror -eq $objDatabaseMonitoringPrincipal.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of Monitoring database to Primary..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal primary -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal primary" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal primary
	}
}
elseif($objDatabaseMonitoringMirror.Checked -eq $true -and $physicalStateMonitoringPrimary -eq $objDatabaseMonitoringMirror.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of Monitoring database to Mirror..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal mirror -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal mirror" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType Monitoring –NewPrincipal mirror
	}
}

######## INVOKE PersistentChat DATABASE ##########
if($objDatabasePersistentChatStatusLabel.Text -eq "Out of Sync")
{
	if($objDatabasePersistentChatPrincipal.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of PersistentChat database to Primary..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal primary -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal primary" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal primary
		}
	}
	elseif ($objDatabasePersistentChatMirror.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of PersistentChat database to Mirror..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal mirror -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal mirror" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal mirror
		}
	}
}
elseif($objDatabasePersistentChatPrincipal.Checked -eq $true -and $physicalStatePersistentChatMirror -eq $objDatabasePersistentChatPrincipal.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of PersistentChat database to Primary..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal primary -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal primary" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal primary
	}
}
elseif($objDatabasePersistentChatMirror.Checked -eq $true -and $physicalStatePersistentChatPrimary -eq $objDatabasePersistentChatMirror.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of PersistentChat database to Mirror..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal mirror -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal mirror" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChat –NewPrincipal mirror
	}
}

######## INVOKE PersistentChatCompliance DATABASE ##########
if($objDatabasePersistentChatComplianceStatusLabel.Text -eq "Out of Sync")
{
	if($objDatabasePersistentChatCompliancePrincipal.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of PersistentChatCompliance database to Primary..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal primary -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal primary" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal primary
		}
	}
	elseif ($objDatabasePersistentChatComplianceMirror.Checked)
	{
		Write-Host ""
		Write-Host "Invoking change of PersistentChatCompliance database to Mirror..." -ForegroundColor Green
		Write-Host ""
		if($AutoAcceptCheckBox.Checked)
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal mirror -Confirm:$false
		}
		else
		{
			Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal mirror" -ForegroundColor Green
			Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal mirror
		}
	}
}
elseif($objDatabasePersistentChatCompliancePrincipal.Checked -eq $true -and $physicalStatePersistentChatComplianceMirror -eq $objDatabasePersistentChatCompliancePrincipal.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of PersistentChatCompliance database to Primary..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal primary -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal primary -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal primary" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal primary
	}
}
elseif($objDatabasePersistentChatComplianceMirror.Checked -eq $true -and $physicalStatePersistentChatCompliancePrimary -eq $objDatabasePersistentChatComplianceMirror.Checked)
{
	Write-Host ""
    Write-Host "Invoking change of PersistentChatCompliance database to Mirror..." -ForegroundColor Green
	Write-Host ""
	if($AutoAcceptCheckBox.Checked)
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal mirror -Confirm:$false" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal mirror -Confirm:$false
	}
	else
	{
		Write-Host "Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal mirror" -ForegroundColor Green
		Invoke-CsDatabaseFailover –PoolFQDN $pool –DatabaseType PersistentChatCompliance –NewPrincipal mirror
	}
}


}  
  

function checkDatabase
{
Write-Host ""
Write-Host "Getting Database Status" -ForegroundColor Green
Write-Host ""

$objDatabaseUSERPrincipal.Show()
$objDatabaseUSERMirror.Show()
$objDatabaseAPPPrincipal.Show()
$objDatabaseAPPMirror.Show()
$objDatabaseCentralMgmtPrincipal.Show()
$objDatabaseCentralMgmtMirror.Show()
$objDatabaseArchivingPrincipal.Show()
$objDatabaseArchivingMirror.Show()
$objDatabaseMonitoringPrincipal.Show()
$objDatabaseMonitoringMirror.Show()
$objDatabasePersistentChatPrincipal.Show()
$objDatabasePersistentChatMirror.Show()
$objDatabasePersistentChatCompliancePrincipal.Show()
$objDatabasePersistentChatComplianceMirror.Show()


$objDatabaseUSERLabel.forecolor = "black"
$objDatabaseAPPLabel.forecolor = "black"
$objDatabaseCentralMgmtLabel.forecolor = "black"
$objDatabaseArchivingLabel.forecolor = "black"
$objDatabaseMonitoringLabel.forecolor = "black"
$objDatabasePersistentChatLabel.forecolor = "black"
$objDatabasePersistentChatComplianceLabel.forecolor = "black"

#### RESET VARIABLES
$objDatabaseUSERPrincipal.Checked = $false
$objDatabaseUSERMirror.Checked = $false
$objDatabaseAPPPrincipal.Checked = $false
$objDatabaseAPPMirror.Checked = $false
$objDatabaseCentralMgmtPrincipal.Checked = $false
$objDatabaseCentralMgmtMirror.Checked = $false
$objDatabaseArchivingPrincipal.Checked = $false
$objDatabaseArchivingMirror.Checked = $false
$objDatabaseMonitoringPrincipal.Checked = $false
$objDatabaseMonitoringMirror.Checked = $false
$objDatabasePersistentChatPrincipal.Checked = $false
$objDatabasePersistentChatMirror.Checked = $false
$objDatabasePersistentChatCompliancePrincipal.Checked = $false
$objDatabasePersistentChatComplianceMirror.Checked = $false

$script:physicalStateUSERPrimary = $false
$script:physicalStateUSERMirror = $false
$script:physicalStateAPPPrimary = $false
$script:physicalStateAPPMirror = $false
$script:physicalStateCentralMgmtPrimary = $false
$script:physicalStateCentralMgmtMirror = $false
$script:physicalStateArchivingPrimary = $false
$script:physicalStateArchivingMirror = $false
$script:physicalStateMonitoringPrimary = $false
$script:physicalStateMonitoringMirror = $false
$script:physicalStatePersistentChatPrimary = $false
$script:physicalStatePersistentChatMirror = $false
$script:physicalStatePersistentChatCompliancePrimary = $false
$script:physicalStatePersistentChatComplianceMirror = $false

$invokeButton.enabled = $false 


$objDatabaseUSERStatusLabel.Text = ""
$objDatabaseAPPStatusLabel.Text = ""
$objDatabaseCentralMgmtStatusLabel.Text = ""
$objDatabaseArchivingStatusLabel.Text = ""
$objDatabaseMonitoringStatusLabel.Text = ""
$objDatabasePersistentChatStatusLabel.Text = ""
$objDatabasePersistentChatComplianceStatusLabel.Text = ""
$objDatabaseOutOfSyncStatusLabel.Text = ""




################# UPDATE USER DATABASE ##################	

$error.clear()
$principalStates = Invoke-Expression "Get-CsDatabaseMirrorState -PoolFqdn $pool -DatabaseType user -WarningAction silentlyContinue -ErrorAction silentlyContinue"

if($error -ne $Null)
{
	if($error -match "is not present on pool")
	{
		Write-Host "INFO (User): The user role is not present on the pool $pool" -foreground "Yellow"
		Write-Host ""
	}
	else
	{
		Write-Host "INFO (User): $error" -foreground "Yellow"
		Write-Host ""
	}
}
if($principalStates -eq $Null)
{
	$objDatabaseUSERPrincipal.Hide()
	$objDatabaseUSERMirror.Hide()
}
else
{
foreach ($principalState in $principalStates)
{
	$databasename = $principalState.DatabaseName
	$statusPrimary = $principalState.MirroringStatusOnPrimary
	$statusMirror = $principalState.MirroringStatusOnMirror
	Write-Host "User ($databasename) Primary: " $principalState.StateOnPrimary " ($statusPrimary)"
	Write-Host "User ($databasename) Mirror: " $principalState.StateOnMirror " ($statusMirror)"
	Write-Host ""
	if($principalState.StateOnPrimary -eq "Principal")
	{
		$script:physicalStateUSERPrimary = $true
		$objDatabaseUSERPrincipal.Checked = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnMirror -eq "Principal")
	{
		$script:physicalStateUSERMirror = $true
		$objDatabaseUSERMirror.Checked = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnPrimary -eq "DatabaseInaccessibleOrMirroringNotEnabled" -or $principalState.StateOnMirror -eq "DatabaseInaccessibleOrMirroringNotEnabled")
	{
		$objDatabaseUSERPrincipal.Hide()
		$objDatabaseUSERMirror.Hide()
		$objDatabaseUSERPrincipal.Checked = $false
		$objDatabaseUSERMirror.Checked = $false
	}
}
if($objDatabaseUSERPrincipal.Checked -and $objDatabaseUSERMirror.Checked)
{
	$objDatabaseUSERStatusLabel.Text = "Out of Sync"
	$objDatabaseOutOfSyncStatusLabel.Text = $OutOfSyncMessage
	$objDatabaseUSERPrincipal.Checked = $true
	$objDatabaseUSERMirror.Checked = $false
	$invokeButton.enabled = $true
}
}
################# UPDATE APP DATABASE ################## 
$error.clear()
$principalStates = Invoke-Expression "Get-CsDatabaseMirrorState -PoolFqdn $pool -DatabaseType app -WarningAction silentlyContinue -ErrorAction silentlyContinue"
if($error -ne $Null)
{
	if($error -match "is not present on pool")
	{
		Write-Host "INFO (App): The App role is not present on the pool $pool" -foreground "Yellow"
		Write-Host ""
	}
	else
	{
		Write-Host "INFO (App): $error" -foreground "Yellow"
		Write-Host ""
	}
}
if($principalStates -eq $Null)
{
	$objDatabaseAPPPrincipal.Hide()
	$objDatabaseAPPMirror.Hide()
}
else
{
foreach ($principalState in $principalStates)
{
	$databasename = $principalState.DatabaseName
	$statusPrimary = $principalState.MirroringStatusOnPrimary
	$statusMirror = $principalState.MirroringStatusOnMirror
	Write-Host "App ($databasename) Primary: "  $principalState.StateOnPrimary " ($statusPrimary)"
	Write-Host "App ($databasename) Mirror: "  $principalState.StateOnMirror " ($statusMirror)"
	Write-Host ""
	if($principalState.StateOnPrimary -eq "Principal")
	{
		$objDatabaseAPPPrincipal.Checked = $true
		$script:physicalStateAPPPrimary = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnMirror -eq "Principal")
	{
		$objDatabaseAPPMirror.Checked = $true
		$script:physicalStateAPPMirror = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnPrimary -eq "DatabaseInaccessibleOrMirroringNotEnabled" -or $principalState.StateOnMirror -eq "DatabaseInaccessibleOrMirroringNotEnabled")
	{
		$objDatabaseAPPPrincipal.Hide()
		$objDatabaseAPPMirror.Hide()
		$objDatabaseAPPPrincipal.Checked = $false
		$objDatabaseAPPMirror.Checked = $false
	}
}
if($objDatabaseAPPPrincipal.Checked -and $objDatabaseAPPMirror.Checked)
{
	$objDatabaseAPPStatusLabel.Text = "Out of Sync"
	$objDatabaseOutOfSyncStatusLabel.Text = $OutOfSyncMessage
	$objDatabaseAPPPrincipal.Checked = $true
	$objDatabaseAPPMirror.Checked = $false
	$invokeButton.enabled = $true
}
}
################# UPDATE CENTRAL MANAGEMENT DATABASE ################## 
$CentralManagement = Get-CSService -CentralManagement
$CentralManagementVersion = $CentralManagement.Version

if($CentralManagementVersion -eq "6" -or $CentralManagementVersion -eq "7")
{
	$error.clear()
	$principalStates = Invoke-Expression "Get-CsDatabaseMirrorState -PoolFqdn $pool -DatabaseType CentralMgmt -WarningAction silentlyContinue -ErrorAction silentlyContinue"
	if($error -ne $Null)
	{
		if($error -match "is not present on pool")
		{
			Write-Host "INFO (CentralMgmt): The CentralMgmt role is not present on the pool $pool" -foreground "Yellow"
			Write-Host ""
		}
		else
		{
			Write-Host "INFO (CentralMgmt): $error" -foreground "Yellow"
			Write-Host ""
		}
	}
	if($principalStates -eq $Null)
	{
		$objDatabaseCentralMgmtPrincipal.Hide()
		$objDatabaseCentralMgmtMirror.Hide()
	}
	else
	{
	foreach ($principalState in $principalStates)
	{
		$databasename = $principalState.DatabaseName
		$statusPrimary = $principalState.MirroringStatusOnPrimary
		$statusMirror = $principalState.MirroringStatusOnMirror
		Write-Host "CentralMgmt ($databasename) Primary: "  $principalState.StateOnPrimary " ($statusPrimary)"
		Write-Host "CentralMgmt ($databasename) Mirror: "  $principalState.StateOnMirror " ($statusMirror)"
		Write-Host ""
		if($principalState.StateOnPrimary -eq "Principal")
		{
			$objDatabaseCentralMgmtPrincipal.Checked = $true
			$script:physicalStateCentralMgmtPrimary = $true
			$invokeButton.enabled = $true
		}
		if($principalState.StateOnMirror -eq "Principal")
		{
			$objDatabaseCentralMgmtMirror.Checked = $true
			$script:physicalStateCentralMgmtMirror = $true
			$invokeButton.enabled = $true
		}
		if($principalState.StateOnPrimary -eq "DatabaseInaccessibleOrMirroringNotEnabled" -or $principalState.StateOnMirror -eq "DatabaseInaccessibleOrMirroringNotEnabled")
		{
			$objDatabaseCentralMgmtPrincipal.Hide()
			$objDatabaseCentralMgmtMirror.Hide()
			$objDatabaseCentralMgmtPrincipal.Checked = $false
			$objDatabaseCentralMgmtMirror.Checked = $false
		}
	}
	if($objDatabaseCentralMgmtPrincipal.Checked -and $objDatabaseCentralMgmtMirror.Checked)
	{
		$objDatabaseCentralMgmtStatusLabel.Text = "Out of Sync"
		$objDatabaseOutOfSyncStatusLabel.Text = $OutOfSyncMessage
		$objDatabaseCentralMgmtPrincipal.Checked = $true
		$objDatabaseCentralMgmtMirror.Checked = $false
		$invokeButton.enabled = $true
	}
	}
}
else
{
	$objDatabaseCentralMgmtPrincipal.Hide()
	$objDatabaseCentralMgmtMirror.Hide()
}
#################  UPDATE ARCHIVING DATABASE ################## 
$error.clear()
$principalStates = Invoke-Expression "Get-CsDatabaseMirrorState -PoolFqdn $pool -DatabaseType Archiving -WarningAction silentlyContinue -ErrorAction silentlyContinue"
if($error -ne $Null)
{
	if($error -match "One of the following roles must exist on pool")
	{
		Write-Host "INFO (Archiving): The Archiving role is not present on the pool $pool" -foreground "Yellow"
		Write-Host ""
	}
	elseif($error -match "is not present on pool")
	{
		Write-Host "INFO (Archiving): The Archiving role is not present on the pool $pool" -foreground "Yellow"
		Write-Host ""
	}
	else
	{
		Write-Host "INFO (Archiving): $error" -foreground "Yellow"
		Write-Host ""
	}
}
if($principalStates -eq $Null)
{
	$objDatabaseArchivingPrincipal.Hide()
	$objDatabaseArchivingMirror.Hide()
}
else
{
foreach ($principalState in $principalStates)
{
	$databasename = $principalState.DatabaseName
	$statusPrimary = $principalState.MirroringStatusOnPrimary
	$statusMirror = $principalState.MirroringStatusOnMirror
	Write-Host "Archiving ($databasename) Primary: "  $principalState.StateOnPrimary " ($statusPrimary)"
	Write-Host "Archiving ($databasename) Mirror: "  $principalState.StateOnMirror " ($statusMirror)"
	Write-Host ""
	if($principalState.StateOnPrimary -eq "Principal")
	{
		$objDatabaseArchivingPrincipal.Checked = $true
		$script:physicalStateArchivingPrimary = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnMirror -eq "Principal")
	{
		$objDatabaseArchivingMirror.Checked = $true
		$script:physicalStateArchivingMirror = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnPrimary -eq "DatabaseInaccessibleOrMirroringNotEnabled" -or $principalState.StateOnMirror -eq "DatabaseInaccessibleOrMirroringNotEnabled")
	{
		$objDatabaseArchivingPrincipal.Hide()
		$objDatabaseArchivingMirror.Hide()
		$objDatabaseArchivingPrincipal.Checked = $false
		$objDatabaseArchivingMirror.Checked = $false
	}
}
if($objDatabaseArchivingPrincipal.Checked -and $objDatabaseArchivingMirror.Checked)
{
	$objDatabaseArchivingStatusLabel.Text = "Out of Sync"
	$objDatabaseOutOfSyncStatusLabel.Text = $OutOfSyncMessage
	$objDatabaseArchivingPrincipal.Checked = $true
	$objDatabaseArchivingMirror.Checked = $false
	$invokeButton.enabled = $true
}
}
#################  UPDATE MONITORING DATABASE ################## 
$error.clear()
$principalStates = Invoke-Expression "Get-CsDatabaseMirrorState -PoolFqdn $pool -DatabaseType Monitoring -WarningAction silentlyContinue -ErrorAction silentlyContinue"
if($error -ne $Null)
{
	
	if($error -match "One of the following roles must exist on pool")
	{
		Write-Host "INFO (Monitoring): The Monitoring role is not present on the pool $pool" -foreground "Yellow"
		Write-Host ""
	}
	elseif($error -match "is not present on pool")
	{
		Write-Host "INFO (Monitoring): The Monitoring role is not present on the pool $pool" -foreground "Yellow"
		Write-Host ""
	}
	else
	{
		Write-Host "INFO (Monitoring): $error" -foreground "Yellow"
		Write-Host ""
	}
}
if($principalStates -eq $Null)
{
	$objDatabaseMonitoringPrincipal.Hide()
	$objDatabaseMonitoringMirror.Hide()
}
else
{
foreach ($principalState in $principalStates)
{
	$databasename = $principalState.DatabaseName
	$statusPrimary = $principalState.MirroringStatusOnPrimary
	$statusMirror = $principalState.MirroringStatusOnMirror
	Write-Host "Monitoring ($databasename) Primary: "  $principalState.StateOnPrimary " ($statusPrimary)"
	Write-Host "Monitoring ($databasename) Mirror: "  $principalState.StateOnMirror " ($statusMirror)"
	Write-Host ""
	if($principalState.StateOnPrimary -eq "Principal")
	{
		$objDatabaseMonitoringPrincipal.Checked = $true
		$script:physicalStateMonitoringPrimary = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnMirror -eq "Principal")
	{
		$objDatabaseMonitoringMirror.Checked = $true
		$script:physicalStateMonitoringMirror = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnPrimary -eq "DatabaseInaccessibleOrMirroringNotEnabled" -or $principalState.StateOnMirror -eq "DatabaseInaccessibleOrMirroringNotEnabled")
	{
		$objDatabaseMonitoringPrincipal.Hide()
		$objDatabaseMonitoringMirror.Hide()
		$objDatabaseMonitoringPrincipal.Checked = $false
		$objDatabaseMonitoringMirror.Checked = $false
	}
}
if($objDatabaseMonitoringPrincipal.Checked -and $objDatabaseMonitoringMirror.Checked)
{
	$objDatabaseMonitoringStatusLabel.Text = "Out of Sync"
	$objDatabaseOutOfSyncStatusLabel.Text = $OutOfSyncMessage
	$objDatabaseMonitoringPrincipal.Checked = $true
	$objDatabaseMonitoringMirror.Checked = $false
	$invokeButton.enabled = $true
}
}
#################  UPDATE PERSISTENT CHAT DATABASE ################## 
$error.clear()
$principalStates = Invoke-Expression "Get-CsDatabaseMirrorState -PoolFqdn $pool -DatabaseType PersistentChat -WarningAction silentlyContinue -ErrorAction silentlyContinue"
if($error -ne $Null)
{
	if($error -match "is not present on pool")
	{
		Write-Host "INFO (PersistentChat): The PersistentChat role is not present on the pool $pool" -foreground "Yellow"
		Write-Host ""
	}
	else
	{
		Write-Host "INFO (PersistentChat): $error" -foreground "Yellow"
		Write-Host ""
	}
}
if($principalStates -eq $Null)
{
	$objDatabasePersistentChatPrincipal.Hide()
	$objDatabasePersistentChatMirror.Hide()
}
else
{
foreach ($principalState in $principalStates)
{
	$databasename = $principalState.DatabaseName
	$statusPrimary = $principalState.MirroringStatusOnPrimary
	$statusMirror = $principalState.MirroringStatusOnMirror
	Write-Host "PersistentChat ($databasename) Primary: "  $principalState.StateOnPrimary " ($statusPrimary)"
	Write-Host "PersistentChat ($databasename) Mirror: "  $principalState.StateOnMirror " ($statusMirror)"
	Write-Host ""
	if($principalState.StateOnPrimary -eq "Principal")
	{
		$objDatabasePersistentChatPrincipal.Checked = $true
		$script:physicalStatePersistentChatPrimary = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnMirror -eq "Principal")
	{
		$objDatabasePersistentChatMirror.Checked = $true
		$script:physicalStatePersistentChatMirror = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnPrimary -eq "DatabaseInaccessibleOrMirroringNotEnabled" -or $principalState.StateOnMirror -eq "DatabaseInaccessibleOrMirroringNotEnabled")
	{
		$objDatabasePersistentChatPrincipal.Hide()
		$objDatabasePersistentChatMirror.Hide()
		$objDatabasePersistentChatPrincipal.Checked = $false
		$objDatabasePersistentChatMirror.Checked = $false
	}
}
if($objDatabasePersistentChatPrincipal.Checked -and $objDatabasePersistentChatMirror.Checked)
{
	$objDatabasePersistentChatStatusLabel.Text = "Out of Sync"
	$objDatabaseOutOfSyncStatusLabel.Text = $OutOfSyncMessage
	$objDatabasePersistentChatPrincipal.Checked = $true
	$objDatabasePersistentChatMirror.Checked = $false
	$invokeButton.enabled = $true
}
}
#################  UPDATE PERSISTENT CHAT COMPLIENCE DATABASE ################## 
$error.clear()
$principalStates = Invoke-Expression "Get-CsDatabaseMirrorState -PoolFqdn $pool -DatabaseType PersistentChatCompliance -WarningAction silentlyContinue -ErrorAction silentlyContinue"
if($error -ne $Null)
{
	if($error -match "is not present on pool")
	{
		Write-Host "INFO (PersistentChatCompliance): The PersistentChatComplience role is not present on the pool $pool" -foreground "Yellow"
		Write-Host ""
	}
	else
	{
		Write-Host "INFO (PersistentChatCompliance): $error" -foreground "Yellow"
		Write-Host 
	}
}
if($principalStates -eq $Null)
{
	$objDatabasePersistentChatCompliancePrincipal.Hide()
	$objDatabasePersistentChatComplianceMirror.Hide()
}
else
{
foreach ($principalState in $principalStates)
{
	$databasename = $principalState.DatabaseName
	$statusPrimary = $principalState.MirroringStatusOnPrimary
	$statusMirror = $principalState.MirroringStatusOnMirror
	Write-Host "PersistentChatCompliance ($databasename) Primary: "  $principalState.StateOnPrimary " ($statusPrimary)"
	Write-Host "PersistentChatCompliance ($databasename) Mirror: "  $principalState.StateOnMirror " ($statusMirror)"
	Write-Host ""
	if($principalState.StateOnPrimary -eq "Principal")
	{
		$objDatabasePersistentChatCompliancePrincipal.Checked = $true
		$script:physicalStatePersistentChatCompliancePrimary = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnMirror -eq "Principal")
	{
		$objDatabasePersistentChatComplianceMirror.Checked = $true
		$script:physicalStatePersistentChatComplianceMirror = $true
		$invokeButton.enabled = $true
	}
	if($principalState.StateOnPrimary -eq "DatabaseInaccessibleOrMirroringNotEnabled" -or $principalState.StateOnMirror -eq "DatabaseInaccessibleOrMirroringNotEnabled")
	{
		$objDatabasePersistentChatCompliancePrincipal.Hide()
		$objDatabasePersistentChatComplianceMirror.Hide()
		$objDatabasePersistentChatCompliancePrincipal.Checked = $false
		$objDatabasePersistentChatComplianceMirror.Checked = $false
	}
}
if($objDatabasePersistentChatCompliancePrincipal.Checked -and $objDatabasePersistentComplianceChatMirror.Checked)
{
	$objDatabasePersistentChatComplianceStatusLabel.Text = "Out of Sync"
	$objDatabaseOutOfSyncStatusLabel.Text = $OutOfSyncMessage
	$objDatabasePersistentChatCompliancePrincipal.Checked = $true
	$objDatabasePersistentChatComplianceMirror.Checked = $false
	$invokeButton.enabled = $true
}
}
 
}
    
# Activate the form ============================================================
$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()



# SIG # Begin signature block
# MIIcXAYJKoZIhvcNAQcCoIIcTTCCHEkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUluodzlF/QReEFuRp+/PZ4IxG
# iiiggheLMIIFFDCCA/ygAwIBAgIQC7/jb7qrV/+uuRoaboA8vjANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE1MDYyMjAwMDAwMFoXDTE2MDgy
# NTEyMDAwMFowWzELMAkGA1UEBhMCQVUxDDAKBgNVBAgTA1ZJQzEQMA4GA1UEBxMH
# TWl0Y2hhbTEVMBMGA1UEChMMSmFtZXMgQ3Vzc2VuMRUwEwYDVQQDEwxKYW1lcyBD
# dXNzZW4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCoITj78CkXvlTw
# OquYWSDCpm4CxAgJfi4CdvJXtwnK4q/BeURGUi8AepOluIF12pQRrTAqLyfy+hJf
# kk2lE3n0Z5qaAmK3w3PjXf7yKem8vVttC1QknMpfkvW0Lu/k6TxcNKimSlVk86bs
# W5qw1Ql2mClLjRRL+5Nz9qM8F4QMzz1P1dH6oDWhhDetk2NLMd5JbrMUMj9QEsu5
# gh5zGBn4fdEcW9ujZSxU6bxGTzZVNtcCWcr+9r/MpDdFl+ExwpHl2iIqVdvO8OBI
# TZE5xNCkbUn4enWhJi1elhI0TMZbIfy9X729aSILz5+0KgHQLTzU6oYDoTeezgtU
# TO4CzhEvAgMBAAGjggG7MIIBtzAfBgNVHSMEGDAWgBRaxLl7KgqjpepxA8Bg+S32
# ZXUOWDAdBgNVHQ4EFgQUSuaSOXtLjdMP2pIoh+MLe/KqZX8wDgYDVR0PAQH/BAQD
# AgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGGL2h0dHA6
# Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMDWgM6Ax
# hi9odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNy
# bDBCBgNVHSAEOzA5MDcGCWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxodHRwczov
# L3d3dy5kaWdpY2VydC5jb20vQ1BTMIGEBggrBgEFBQcBAQR4MHYwJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBOBggrBgEFBQcwAoZCaHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRENvZGVT
# aWduaW5nQ0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEBANCV
# INu/j0Scmsg7BMcSIaQP07XH3PP20Z+U30L5/kmd7c8arjPqk1mavKmdYksixh3V
# RCneKVwalXit4FXPQKKx+teTh6tgkr6HlXLxIPBVVYRi71CAY4NyhsmNHg2ky9X9
# hNVzs2sG5215okFs6RI1rCb+iM6fSBxbmHGldzocw+uH8xHoOF3S2eVlsEvDPsgA
# W91+dKdgajFjb97HWdpzaku022HnHyCnqa9rD70S7gFhgu9AQK4VvhcIqZZqI8Ie
# CFaLPxP/2b2RN+QEJLw2foWRkPWRoWi/D8Xjqaneb9u1t+eZ1gDN+Wgj5W6sx1VF
# 1KThdJ7OKvUuFVfTFGkwggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7VvlVAIMA0G
# CSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0
# IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEwMjIxMjAw
# MDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNV
# BAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNz
# dXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx6nadBS63
# j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEjlpB3gvmh
# hCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJNYBi+qsSy
# rnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2DZDv5LVO
# pKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9hbFig3NB
# ggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNVHRMBAf8E
# CDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzB5
# BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0
# LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0
# cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNy
# bDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEF
# BQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgBhv1sAzAd
# BgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAUReuir/SS
# y4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi0RXILHwl
# KXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6ljlriXiSB
# ThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0kriTGxycq
# oSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/PQMtARKUT
# 8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d9gEgzpkx
# Yz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJmoecYpJpk
# Ue8wggZqMIIFUqADAgECAhADAZoCOv9YsWvW1ermF/BmMA0GCSqGSIb3DQEBBQUA
# MGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsT
# EHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQg
# Q0EtMTAeFw0xNDEwMjIwMDAwMDBaFw0yNDEwMjIwMDAwMDBaMEcxCzAJBgNVBAYT
# AlVTMREwDwYDVQQKEwhEaWdpQ2VydDElMCMGA1UEAxMcRGlnaUNlcnQgVGltZXN0
# YW1wIFJlc3BvbmRlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKNk
# Xfx8s+CCNeDg9sYq5kl1O8xu4FOpnx9kWeZ8a39rjJ1V+JLjntVaY1sCSVDZg85v
# Zu7dy4XpX6X51Id0iEQ7Gcnl9ZGfxhQ5rCTqqEsskYnMXij0ZLZQt/USs3OWCmej
# vmGfrvP9Enh1DqZbFP1FI46GRFV9GIYFjFWHeUhG98oOjafeTl/iqLYtWQJhiGFy
# GGi5uHzu5uc0LzF3gTAfuzYBje8n4/ea8EwxZI3j6/oZh6h+z+yMDDZbesF6uHjH
# yQYuRhDIjegEYNu8c3T6Ttj+qkDxss5wRoPp2kChWTrZFQlXmVYwk/PJYczQCMxr
# 7GJCkawCwO+k8IkRj3cCAwEAAaOCAzUwggMxMA4GA1UdDwEB/wQEAwIHgDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMIIBvwYDVR0gBIIBtjCC
# AbIwggGhBglghkgBhv1sBwEwggGSMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5k
# aWdpY2VydC5jb20vQ1BTMIIBZAYIKwYBBQUHAgIwggFWHoIBUgBBAG4AeQAgAHUA
# cwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQByAHQAaQBmAGkAYwBhAHQAZQAgAGMA
# bwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBjAGUAcAB0AGEAbgBjAGUAIABvAGYA
# IAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAgAEMAUAAvAEMAUABTACAAYQBuAGQA
# IAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQAGEAcgB0AHkAIABBAGcAcgBlAGUA
# bQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBtAGkAdAAgAGwAaQBhAGIAaQBsAGkA
# dAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBjAG8AcgBwAG8AcgBhAHQAZQBkACAA
# aABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBlAHIAZQBuAGMAZQAuMAsGCWCGSAGG
# /WwDFTAfBgNVHSMEGDAWgBQVABIrE5iymQftHt+ivlcNK2cCzTAdBgNVHQ4EFgQU
# YVpNJLZJMp1KKnkag0v0HonByn0wfQYDVR0fBHYwdDA4oDagNIYyaHR0cDovL2Ny
# bDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEQ0EtMS5jcmwwOKA2oDSG
# Mmh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEu
# Y3JsMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGln
# aWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNydDANBgkqhkiG9w0BAQUFAAOCAQEA
# nSV+GzNNsiaBXJuGziMgD4CH5Yj//7HUaiwx7ToXGXEXzakbvFoWOQCd42yE5FpA
# +94GAYw3+puxnSR+/iCkV61bt5qwYCbqaVchXTQvH3Gwg5QZBWs1kBCge5fH9j/n
# 4hFBpr1i2fAnPTgdKG86Ugnw7HBi02JLsOBzppLA044x2C/jbRcTBu7kA7YUq/OP
# Q6dxnSHdFMoVXZJB2vkPgdGZdA0mxA5/G7X1oPHGdwYoFenYk+VVFvC7Cqsc21xI
# J2bIo4sKHOWV2q7ELlmgYd3a822iYemKC23sEhi991VUQAOSK2vCUcIKSK+w1G7g
# 9BQKOhvjjz3Kr2qNe9zYRDCCBs0wggW1oAMCAQICEAb9+QOWA63qAArrPye7uhsw
# DQYJKoZIhvcNAQEFBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0
# IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNl
# cnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTIxMTExMDAw
# MDAwMFowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgQXNzdXJl
# ZCBJRCBDQS0xMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6IItmfnK
# wkKVpYBzQHDSnlZUXKnE0kEGj8kz/E1FkVyBn+0snPgWWd+etSQVwpi5tHdJ3InE
# Ctqvy15r7a2wcTHrzzpADEZNk+yLejYIA6sMNP4YSYL+x8cxSIB8HqIPkg5QycaH
# 6zY/2DDD/6b3+6LNb3Mj/qxWBZDwMiEWicZwiPkFl32jx0PdAug7Pe2xQaPtP77b
# lUjE7h6z8rwMK5nQxl0SQoHhg26Ccz8mSxSQrllmCsSNvtLOBq6thG9IhJtPQLnx
# TPKvmPv2zkBdXPao8S+v7Iki8msYZbHBc63X8djPHgp0XEK4aH631XcKJ1Z8D2Kk
# PzIUYJX9BwSiCQIDAQABo4IDejCCA3YwDgYDVR0PAQH/BAQDAgGGMDsGA1UdJQQ0
# MDIGCCsGAQUFBwMBBggrBgEFBQcDAgYIKwYBBQUHAwMGCCsGAQUFBwMEBggrBgEF
# BQcDCDCCAdIGA1UdIASCAckwggHFMIIBtAYKYIZIAYb9bAABBDCCAaQwOgYIKwYB
# BQUHAgEWLmh0dHA6Ly93d3cuZGlnaWNlcnQuY29tL3NzbC1jcHMtcmVwb3NpdG9y
# eS5odG0wggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYA
# IAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkA
# dAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAA
# RABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAA
# UgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAA
# dwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4A
# ZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkA
# bgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wCwYJYIZIAYb9bAMVMBIGA1Ud
# EwEB/wQIMAYBAf8CAQAweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1Ud
# HwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwHQYDVR0OBBYEFBUAEisTmLKZ
# B+0e36K+Vw0rZwLNMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0G
# CSqGSIb3DQEBBQUAA4IBAQBGUD7Jtygkpzgdtlspr1LPUukxR6tWXHvVDQtBs+/s
# dR90OPKyXGGinJXDUOSCuSPRujqGcq04eKx1XRcXNHJHhZRW0eu7NoR3zCSl8wQZ
# Vann4+erYs37iy2QwsDStZS9Xk+xBdIOPRqpFFumhjFiqKgz5Js5p8T1zh14dpQl
# c+Qqq8+cdkvtX8JLFuRLcEwAiR78xXm8TBJX/l/hHrwCXaj++wc4Tw3GXZG5D2dF
# zdaD7eeSDY2xaYxP+1ngIw/Sqq4AfO6cQg7PkdcntxbuD8O9fAqg7iwIVYUiuOsY
# Gk38KiGtSTGDR5V3cdyxG0tLHBCcdxTBnU8vWpUIKRAmMYIEOzCCBDcCAQEwgYYw
# cjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVk
# IElEIENvZGUgU2lnbmluZyBDQQIQC7/jb7qrV/+uuRoaboA8vjAJBgUrDgMCGgUA
# oHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0B
# CQQxFgQUUs0g93epc56LElYKwacuIhbra0QwDQYJKoZIhvcNAQEBBQAEggEAcBsD
# 1bvivIiPzyH4RX7qyk8JTHzvyYbrzdrOAM6rDtCjCQ2PVrp3TNJjEJ7maxCcHt5s
# rXQUBDL18ipPzhrmFWZh3Pfc+L40ZuuAhYQNZ2FP4/AghhPoF7eRt161W9532Qup
# hy+7FqidcZmh8NH1u+fd+z90eGRKu1cnLNKnK1hZw/iXyMlF0Uiw20/Ue1RVJsAC
# 67saFvswwAUFZE3/qerDqNJmnglwlKA5u1IlUo3mtYOg2jCYQk526m9rlPMEM5qJ
# qxPiYpLdV3MAolYiCZQ2OR4lV0rqn3jXTckwdPri1xJKWeYcURTLPqP/h0ECwtE4
# f5ImaTqwqRuNWO6my6GCAg8wggILBgkqhkiG9w0BCQYxggH8MIIB+AIBATB2MGIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0Et
# MQIQAwGaAjr/WLFr1tXq5hfwZjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsG
# CSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTYwMzIyMjIwNjI4WjAjBgkqhkiG
# 9w0BCQQxFgQUX9ejzSNSRBSiJKUYx/wGEBlTIccwDQYJKoZIhvcNAQEBBQAEggEA
# dCRCmHGaZIjqj8qscWKuyX3pazcmucqkBDKNgs82+Gc/62qOU892FEOd20Fm9grj
# edwZdJyxD/Ta1QC3pBMix0fiy401vtKB6iSuf/Ni0XmfDIDS8esNLeX/g96ZSjji
# qeHPh1emzr52ZNfAaf46GQhc3ckKGbsYkLEynkHvl0RU0FctDq6A0FxNjsYgaYM9
# aocTrcNjOl9TriCScQkpbf1wXWRYTc8EWjjKRnUry0C7qHgoht1QI4J5Ne5yipHx
# YjXhgdKoWTsGP95x26TFqY2Mkdmt0oSiZSW2/Ho9CQAwZlwfzcT957pItCJ6LCKT
# seCL7wbMZkRCLkJzJdGAUA==
# SIG # End signature block
