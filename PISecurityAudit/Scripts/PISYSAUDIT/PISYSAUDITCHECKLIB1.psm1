# ***********************************************************************
# Validation library
# ***********************************************************************
# * Modulename:   PISYSAUDIT
# * Filename:     PISYSAUDITCHECKLIB1.psm1
# * Description:  Validation rules for machines.
# *
# * Copyright 2016 OSIsoft, LLC
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# * 
# *   <http://www.apache.org/licenses/LICENSE-2.0>
# * 
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# *
# * Modifications copyright (C) <YYYY> <Name>, <Org>
# * <Description of modification>
# *
# ************************************************************************
# Version History:
# ------------------------------------------------------------------------
# Version 1.0.0.8 Initial release on OSIsoft Users Community.
# Authors:  Jim Davidson, Bryan Owen and Mathieu Hamel from OSIsoft.
#
# ************************************************************************

# ........................................................................
# Internal Functions
# ........................................................................
function GetFunctionName
{ return (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name }

# ........................................................................
# Public Functions
# ........................................................................
function Get-PISysAudit_FunctionsFromLibrary1
{
<#  
.SYNOPSIS
Get functions from machine library.
#>
	# Form a list of all functions that need to be called to test
	# the machine compliance.
	[System.Collections.HashTable]$listOfFunctions = @{}	
	$listOfFunctions.Add("Get-PISysAudit_CheckDomainMemberShip", 1)
	$listOfFunctions.Add("Get-PISysAudit_CheckOSSKU", 1)
	$listOfFunctions.Add("Get-PISysAudit_CheckFirewallEnabled", 1)
	$listOfFunctions.Add("Get-PISysAudit_CheckAppLockerEnabled", 1)
	$listOfFunctions.Add("Get-PISysAudit_CheckUACEnabled", 1)
			
	# Return the list.
	return $listOfFunctions
}

function Get-PISysAudit_CheckDomainMemberShip
{
<#  
.SYNOPSIS
AU10001 - Domain Membership Check
.DESCRIPTION
VALIDATION: verifies that the machine is a member of an Active Directory Domain.<br/>  
COMPLIANCE: join the machine to an Active Directory Domain.  Use of a domain is 
encouraged as AD provides Kerberos authentication and is our best available technology 
for securing a PI System.  Furthermore, the implementation of transport security in the 
PI System relies on Windows Integrated Security and AD to automatically enable higher 
strength ciphers.
#>
[CmdletBinding(DefaultParameterSetName="Default", SupportsShouldProcess=$false)]     
param(							
		[parameter(Mandatory=$true, Position=0, ParameterSetName = "Default")]
		[alias("at")]
		[System.Collections.HashTable]
		$AuditTable,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("lc")]
		[boolean]
		$LocalComputer = $true,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("rcn")]
		[string]
		$RemoteComputerName = "",
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("dbgl")]
		[int]
		$DBGLevel = 0)
BEGIN {}
PROCESS
{					
	# Get and store the function Name.
	$fn = GetFunctionName	
	$msg = ""
	try
	{				
		# Read the registry key.
		$value = Get-PISysAudit_RegistryKeyValue "HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters" "Domain" `
									-lc $LocalComputer -rcn $RemoteComputerName -dbgl $DBGLevel
		
		# Compliance is to have computer belonging to a domain.
		# If the value is null or empty, it means it is not defined and the result of
		# the test is False (fail), otherwise it is true (pass).		
		if(($null -eq $value) -or ($value -eq "")) 
		{ 
			$result =  $false 
			$msg = "Machine is not a member of an AD Domain."
		} 
		else 
		{ 
			$result = $true 
			$msg = "Machine is a member of an AD Domain."
		}
	}
	catch
	{
		# Return the error message.
		$msg = "A problem occurred during the processing of the validation check."					
		Write-PISysAudit_LogMessage $msg "Error" $fn -eo $_									
		$result = "N/A"
	}
	
	# Define the results in the audit table	
	$AuditTable = New-PISysAuditObject -lc $LocalComputer -rcn $RemoteComputerName `
										-at $AuditTable "AU10001" `
										-ain "Domain Membership Check" -aiv $result `
										-aif $fn -msg $msg `
										-Group1 "Machine" -Group2 "Domain" `
										-Severity "Severe"																				 
}

END {}

#***************************
#End of exported function
#***************************
}

function Get-PISysAudit_CheckOSSKU
{
<#  
.SYNOPSIS
AU10002 - Operating System SKU
.DESCRIPTION   
VALIDATION: verifies that the OS Stock Keeping Unit (SKU) is appropriate for 
production use.<br/>
COMPLIANCE: SKU should match one of the following: 12, 13, 14, 29, 39, 40, 41 or 42.
All SKU values are viewable here: <br/>
<a href="http://msdn.microsoft.com/en-us/library/ms724358.aspx">http://msdn.microsoft.com/en-us/library/ms724358.aspx</a><br/>  
These SKUs were chosen to highlight the reduced attack surface area of a core 
installation of Windows Server.  For more on the advantages of Windows Server Core, 
please see:<br/>
<a href="https://msdn.microsoft.com/en-us/library/hh846314(v=vs.85).aspx">https://msdn.microsoft.com/en-us/library/hh846314(v=vs.85).aspx </a>
#>
[CmdletBinding(DefaultParameterSetName="Default", SupportsShouldProcess=$false)]     
param(							
		[parameter(Mandatory=$true, Position=0, ParameterSetName = "Default")]
		[alias("at")]
		[System.Collections.HashTable]
		$AuditTable,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("lc")]
		[boolean]
		$LocalComputer = $true,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("rcn")]
		[string]
		$RemoteComputerName = "",
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("dbgl")]
		[int]
		$DBGLevel = 0)
BEGIN {}
PROCESS
{					
	# Get and store the function Name.
	$fn = GetFunctionName
	$msg = ""
	try
	{				
		# Get the value from the WMI Query
		$sku = Get-PISysAudit_OSSKU -lc $LocalComputer -rcn $RemoteComputerName -dbgl $DBGLevel
		$productTranscription = ""
		# This link (http://msdn.microsoft.com/en-us/library/ms724358.aspx) contains all the possible sku.
		switch ($sku)
		{
			0   { $productTranscription = "An unknown product"; break; }
			1   { $productTranscription = "Ultimate"; break; }
			2   { $productTranscription = "Home Basic"; break; }
			3   { $productTranscription = "Home Premium"; break; }
			4   { $productTranscription = "Enterprise"; break; }
			5   { $productTranscription = "Home Basic N"; break; }
			6   { $productTranscription = "Business"; break; }
			7   { $productTranscription = "Server Standard"; break; }
			8   { $productTranscription = "Server Datacenter (full installation)"; break; }
			9   { $productTranscription = "Windows Small Business Server"; break; }
			10  { $productTranscription = "Server Enterprise (full installation)"; break; }
			11  { $productTranscription = "Starter"; break; }
			12  { $productTranscription = "Server Datacenter (core installation)"; break; }
			13  { $productTranscription = "Server Standard (core installation)"; break; }
			14  { $productTranscription = "Server Enterprise (core installation)"; break; }
			15  { $productTranscription = "Server Enterprise for Itanium-based Systems"; break; }
			16  { $productTranscription = "Business N"; break; }
			17  { $productTranscription = "Web Server (full installation)"; break; }
			18  { $productTranscription = "HPC Edition"; break; }
			19  { $productTranscription = "Windows Storage Server 2008 R2 Essentials"; break; }
			20  { $productTranscription = "Storage Server Express"; break; }
			21  { $productTranscription = "Storage Server Standard"; break; }
			22  { $productTranscription = "Storage Server Workgroup"; break; }
			23  { $productTranscription = "Storage Server Enterprise"; break; }
			24  { $productTranscription = "Windows Server 2008 for Windows Essential Server Solutions"; break; }
			25  { $productTranscription = "Small Business Server Premium"; break; }
			26  { $productTranscription = "Home Premium N"; break; }
			27  { $productTranscription = "Enterprise N"; break; }
			28  { $productTranscription = "Ultimate N"; break; }
			29  { $productTranscription = "Web Server (core installation)"; break; }
			30  { $productTranscription = "Windows Essential Business Server Management Server"; break; }
			31  { $productTranscription = "Windows Essential Business Server Security Server"; break; }
			32  { $productTranscription = "Windows Essential Business Server Messaging Server"; break; }
			33  { $productTranscription = "Server Foundation"; break; }
			34  { $productTranscription = "Windows Home Server 2011"; break; }
			35  { $productTranscription = "Windows Server 2008 without Hyper-V for Windows Essential Server
				   Solutions"; break; }
			36  { $productTranscription = "Server Standard without Hyper-V"; break; }
			37  { $productTranscription = "Server Datacenter without Hyper-V (full installation)"; break; }
			38  { $productTranscription = "Server Enterprise without Hyper-V (full installation)"; break; }
			39  { $productTranscription = "Server Datacenter without Hyper-V (core installation)"; break; }
			40  { $productTranscription = "Server Standard without Hyper-V (core installation)"; break; }
			41  { $productTranscription = "Server Enterprise without Hyper-V (core installation)"; break; }
			42  { $productTranscription = "Microsoft Hyper-V Server"; break; }
			43  { $productTranscription = "Storage Server Express (core installation)"; break; }
			44  { $productTranscription = "Storage Server Standard (core installation)"; break; }
			45  { $productTranscription = "Storage Server Workgroup (core installation)"; break; }
			46  { $productTranscription = "Storage Server Enterprise (core installation)"; break; }
			46  { $productTranscription = "Storage Server Enterprise (core installation)"; break; }
			47  { $productTranscription = "Starter N"; break; }
			48  { $productTranscription = "Professional"; break; }
			49  { $productTranscription = "Professional N"; break; }
			50  { $productTranscription = "Windows Small Business Server 2011 Essentials"; break; }
			51  { $productTranscription = "Server For SB Solutions"; break; }
			52  { $productTranscription = "Server Solutions Premium"; break; }
			53  { $productTranscription = "Server Solutions Premium (core installation)"; break; }
			54  { $productTranscription = "Server For SB Solutions EM"; break; }
			55  { $productTranscription = "Server For SB Solutions EM"; break; }
			56  { $productTranscription = "Windows MultiPoint Server"; break; }
			59  { $productTranscription = "Windows Essential Server Solution Management"; break; }
			60  { $productTranscription = "Windows Essential Server Solution Additional"; break; }
			61  { $productTranscription = "Windows Essential Server Solution Management SVC"; break; }
			62  { $productTranscription = "Windows Essential Server Solution Additional SVC"; break; }
			63  { $productTranscription = "Small Business Server Premium (core installation)"; break; }
			64  { $productTranscription = "Server Hyper Core V"; break; }
			72  { $productTranscription = "Server Enterprise (evaluation installation)"; break; }
			76  { $productTranscription = "Windows MultiPoint Server Standard (full installation)"; break; }
			77  { $productTranscription = "Windows MultiPoint Server Premium (full installation)"; break; }
			79  { $productTranscription = "Server Standard (evaluation installation)"; break; }
			80  { $productTranscription = "Server Datacenter (evaluation installation)"; break; }
			84  { $productTranscription = "Enterprise N (evaluation installation)"; break; }
			95  { $productTranscription = "Storage Server Workgroup (evaluation installation)"; break; }
			96  { $productTranscription = "Storage Server Standard (evaluation installation)"; break; }
			98  { $productTranscription = "Windows 8 N"; break; }
			99  { $productTranscription = "Windows 8 China"; break; }
			100 { $productTranscription = "Windows 8 Single Language"; break; }
			101 { $productTranscription = "Windows 8"; break; }
			103 { $productTranscription = "Professional with Media Center"; break; }

			default {$productTranscription = "Unknown: " + $sku }
		}

		# Check if the value is from one in the list			
		if($sku -match "12|13|14|29|39|40|41|42") { $result =  $true } else { $result = $false }

		# Set a message to return with the audit object.
		$msgTemplate = "The following product is used: {0}"
		$msg = [string]::Format($msgTemplate, $productTranscription)

	}
	catch
	{
		# Return the error message.
		$msg = "A problem occurred during the processing of the validation check."					
		Write-PISysAudit_LogMessage $msg "Error" $fn -eo $_									
		$result = "N/A"
	}
	
	# Define the results in the audit table													
	$AuditTable = New-PISysAuditObject -lc $LocalComputer -rcn $RemoteComputerName `
										-at $AuditTable "AU10002" `
										-ain "Operating System SKU" -aiv $result `
										-aif $fn -msg $msg `
										-Group1 "Machine" -Group2 "Operating System" `
										-Severity "Severe"													
}

END {}

#***************************
#End of exported function
#***************************
}

function Get-PISysAudit_CheckFirewallEnabled
{
<#  
.SYNOPSIS
AU10003 - Firewall Enabled
.DESCRIPTION
VALIDATION: verifies that the Windows host based firewall is enabled.<br/> 
COMPLIANCE: enable the Windows firewall for Domain, Private and Public Scope.  
A firewall's effectiveness is heavily dependent on the configuration.  
For PI specific port requirements, please see:<br/> 
<a href="https://techsupport.osisoft.com/Troubleshooting/KB/KB01162"> https://techsupport.osisoft.com/Troubleshooting/KB/KB01162 </a> <br/>
For more general information on the Windows firewall, see "Windows Firewall with 
Advanced Security Overview" on TechNet: <br/>
<a href="https://technet.microsoft.com/en-us/library/hh831365(v=ws.11).aspx">https://technet.microsoft.com/en-us/library/hh831365(v=ws.11).aspx </a>
#>
[CmdletBinding(DefaultParameterSetName="Default", SupportsShouldProcess=$false)]     
param(							
		[parameter(Mandatory=$true, Position=0, ParameterSetName = "Default")]
		[alias("at")]
		[System.Collections.HashTable]
		$AuditTable,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("lc")]
		[boolean]
		$LocalComputer = $true,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("rcn")]
		[string]
		$RemoteComputerName = "",
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("dbgl")]
		[int]
		$DBGLevel = 0)
BEGIN {}
PROCESS
{					
	# Get and store the function Name.
	$fn = GetFunctionName
	$msg = ""
	try
	{				
		# Read the registry key.
		$outputFileContent = Get-PISysAudit_FirewallState -lc $LocalComputer -rcn $RemoteComputerName -dbgl $DBGLevel
		
		# Read each line to find the state of each profile.	
		$result = $false		
		$validationCounter = 0
		
		foreach($line in $OutputFileContent)
		{														
			if($line.ToLower().Contains("state"))
			{								
				if($line.ToLower().Contains("on")) { $validationCounter++ }				
			}					
		}
		
		# Check if the counter is 3 = compliant, 2 or less it is not compliant
		if($validationCounter -eq 3) 
		{ 
			$result = $true 
			$msg = "Firewall enabled."
		} 
		else 
		{ 
			$result = $false 
			$msg = "Firewall not enabled."
		}							
	}
	catch
	{
		# Return the error message.
		$msg = "A problem occurred during the processing of the validation check."					
		Write-PISysAudit_LogMessage $msg "Error" $fn -eo $_									
		$result = "N/A"
	}
	
	# Define the results in the audit table	
	$AuditTable = New-PISysAuditObject -lc $LocalComputer -rcn $RemoteComputerName `
										-at $AuditTable "AU10003" `
										-ain "Firewall Enabled" -aiv $result `
										-aif $fn -msg $msg `
										-Group1 "Machine" -Group2 "Policy" `
										-Severity "Moderate"																				 
}

END {}

#***************************
#End of exported function
#***************************
}

function Get-PISysAudit_CheckAppLockerEnabled
{
<#  
.SYNOPSIS
AU10004 - AppLocker Enabled
.DESCRIPTION
VALIDATION: verifies that AppLocker is enabled. <br/>  
COMPLIANCE: set AppLocker to Enforce mode after establishing a policy.  For a 
primer on running AppLocker on a PI Data Archive, see: <br/>
<a href="https://techsupport.osisoft.com/Troubleshooting/KB/KB00994">https://techsupport.osisoft.com/Troubleshooting/KB/KB00994</a>
#>
[CmdletBinding(DefaultParameterSetName="Default", SupportsShouldProcess=$false)]     
param(							
		[parameter(Mandatory=$true, Position=0, ParameterSetName = "Default")]
		[alias("at")]
		[System.Collections.HashTable]
		$AuditTable,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("lc")]
		[boolean]
		$LocalComputer = $true,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("rcn")]
		[string]
		$RemoteComputerName = "",
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("dbgl")]
		[int]
		$DBGLevel = 0)
BEGIN {}
PROCESS
{					
	# Get and store the function Name.
	$fn = GetFunctionName
	
	try
	{				
		$result = $false
		# Read the AppLocker policy.
		[xml] $appLockerPolicy = Get-PISysAudit_AppLockerState -lc $LocalComputer -rcn $RemoteComputerName -dbgl $DBGLevel
		if($null -ne $appLockerPolicy)
		{
			if($(Select-Xml -xml $appLockerPolicy -XPath "//RuleCollection[@Type='Exe']").Node.EnforcementMode -eq "Enabled" -and `
				$(Select-Xml -xml $appLockerPolicy -XPath "//RuleCollection[@Type='Msi']").Node.EnforcementMode -eq "Enabled")
			{
				$result = $true
				$msg = "AppLocker is configured to enforce."
			}
			else
			{
				$msg = "AppLocker is not configured to enforce."
			}
		}
		else
		{
			$msg = "No AppLocker policy returned."
		}
	}
	catch
	{
		# Return the error message.
		$msg = "A problem occurred during the processing of the validation check."					
		Write-PISysAudit_LogMessage $msg "Error" $fn -eo $_									
		$result = "N/A"
	}
	
	# Define the results in the audit table	
	$AuditTable = New-PISysAuditObject -lc $LocalComputer -rcn $RemoteComputerName `
										-at $AuditTable "AU10004" `
										-ain "AppLocker Enabled" -aiv $result `
										-aif $fn -msg $msg `
										-Group1 "Machine" -Group2 "Policy" `
										-Severity "Moderate"																				 
}

END {}

#***************************
#End of exported function
#***************************
}

function Get-PISysAudit_CheckUACEnabled
{
<#  
.SYNOPSIS
AU10005 - UAC Enabled
.DESCRIPTION
VALIDATION: verifies that UAC is enabled.  More precisely, it verifies the 
following default features: EnableLUA, ConsentPromptBehaviorAdmin, 
EnableInstallerDetection, PromptOnSecureDesktop and EnableSecureUIAPaths.
Additionally, a check is performed for the feature ValidateAdminCodeSignatures.  
Lower severity is assigned if this is the only feature disabled.<br/>
COMPLIANCE: enable the flagged UAC features through Local Security Policy.  
For more information on specific UAC features, see: <br/>
<a href="https://technet.microsoft.com/en-us/library/dd835564(v=ws.10).aspx">https://technet.microsoft.com/en-us/library/dd835564(v=ws.10).aspx </a>
#>
[CmdletBinding(DefaultParameterSetName="Default", SupportsShouldProcess=$false)]     
param(							
		[parameter(Mandatory=$true, Position=0, ParameterSetName = "Default")]
		[alias("at")]
		[System.Collections.HashTable]
		$AuditTable,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("lc")]
		[boolean]
		$LocalComputer = $true,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("rcn")]
		[string]
		$RemoteComputerName = "",
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("dbgl")]
		[int]
		$DBGLevel = 0)
BEGIN {}
PROCESS
{					
	# Get and store the function Name.
	$fn = GetFunctionName
	$severity = "Unknown"

	try
	{				
		$result = $true
		$uacKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system"
		$defaultEnabledUACFeatures = "EnableLUA", "ConsentPromptBehaviorAdmin", "EnableInstallerDetection", "PromptOnSecureDesktop", "EnableSecureUIAPaths"
		
		# Loop through key default enabled UAC features
		$tmpmsg = "Some default UAC features are disabled: "
		foreach ($uacFeature in $defaultEnabledUACFeatures) 
		{
			if ($(Get-PISysAudit_RegistryKeyValue -lc $LocalComputer -rcn $RemoteComputerName -dbgl $DBGLevel -RegKeyPath $uacKeyPath -Attribute $uacFeature) -eq 0)
			{
				$result = $false
				$severity = "Moderate"
				$tmpmsg += $uacFeature + "; "
			}
		}
		
		# If the default features are enabled, check for additional feature for added security.
		if($result) 
		{
			# Assigning lower severity since the default features are in place.
			$severity = "Low"
			$additionalUACFeature = "ValidateAdminCodeSignatures"
			if ($(Get-PISysAudit_RegistryKeyValue -lc $LocalComputer -rcn $RemoteComputerName -dbgl $DBGLevel -RegKeyPath $uacKeyPath -Attribute $additionalUACFeature) -eq 0)
			{
				$result = $false
				$msg = "Recommended UAC feature {0} disabled."
				$msg = [string]::Format($msg, $additionalUACFeature)
			}	
			else {$msg = "UAC features enabled."}
		}
		else
		{$msg = $tmpmsg}	
	}
	catch
	{
		# Return the error message.
		$msg = "A problem occurred during the processing of the validation check."					
		Write-PISysAudit_LogMessage $msg "Error" $fn -eo $_									
		$result = "N/A"
	}	
	
	# Define the results in the audit table	
	$AuditTable = New-PISysAuditObject -lc $LocalComputer -rcn $RemoteComputerName `
										-at $AuditTable "AU10005" `
										-ain "UAC Enabled" -aiv $result `
										-aif $fn -msg $msg `
										-Group1 "Machine" -Group2 "Policy" `
										-Severity $severity																				 
}

END {}

#***************************
#End of exported function
#***************************
}

# ........................................................................
# Add your cmdlet after this section. Don't forget to add an intruction
# to export them at the bottom of this script.
# ........................................................................
function Get-PISysAudit_TemplateAU1xxxx
{
<#  
.SYNOPSIS
AU1xxxx - <Name>
.DESCRIPTION
VERIFICATION: <Enter what the verification checks>
COMPLIANCE: <Enter what it needs to be compliant>
#>
[CmdletBinding(DefaultParameterSetName="Default", SupportsShouldProcess=$false)]     
param(							
		[parameter(Mandatory=$true, Position=0, ParameterSetName = "Default")]
		[alias("at")]
		[System.Collections.HashTable]
		$AuditTable,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("lc")]
		[boolean]
		$LocalComputer = $true,
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("rcn")]
		[string]
		$RemoteComputerName = "",
		[parameter(Mandatory=$false, ParameterSetName = "Default")]
		[alias("dbgl")]
		[int]
		$DBGLevel = 0)		
BEGIN {}
PROCESS
{		
	# Get and store the function Name.
	$fn = GetFunctionName
	$msg = ""
	try
	{		
		# Enter routine.			
	}
	catch
	{
		# Return the error message.
		$msg = "A problem occurred during the processing of the validation check."					
		Write-PISysAudit_LogMessage $msg "Error" $fn -eo $_									
		$result = "N/A"
	}
	
	# Define the results in the audit table	
	$AuditTable = New-PISysAuditObject -lc $LocalComputer -rcn $RemoteComputerName `
									-at $AuditTable "AU1xxxx" `
									-ain "<Name>" -aiv $result `
									-aif $fn -msg $msg `
									-Group1 "<Category 1>" -Group2 "<Category 2>" `
									-Group3 "<Category 3>" -Group4 "<Category 4>" `
									-Severity "<Severity>"																																																
}

END {}

#***************************
#End of exported function
#***************************
}

# ........................................................................
# Export Module Member
# ........................................................................
# <Do not remove>
Export-ModuleMember Get-PISysAudit_FunctionsFromLibrary1
Export-ModuleMember Get-PISysAudit_CheckDomainMemberShip
Export-ModuleMember Get-PISysAudit_CheckOSSKU
Export-ModuleMember Get-PISysAudit_CheckFirewallEnabled
Export-ModuleMember Get-PISysAudit_CheckAppLockerEnabled
Export-ModuleMember Get-PISysAudit_CheckUACEnabled
# </Do not remove>

# ........................................................................
# Add your new Export-ModuleMember instruction after this section.
# Replace the Get-PISysAudit_TemplateAU1xxxx with the name of your
# function.
# ........................................................................
# Export-ModuleMember Get-PISysAudit_TemplateAU1xxxx