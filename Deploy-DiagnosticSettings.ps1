
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
$policyTotal = 59

###------------Functions ---------------
function Write-Color([String[]]$Text, [ConsoleColor[]]$Color = "White", [int]$StartTab = 0, [int] $LinesBefore = 0,[int] $LinesAfter = 0, [string] $LogFile = "", $TimeFormat = "yyyy-MM-dd HH:mm:ss") {
    # version 0.2
    # - added logging to file
    # version 0.1
    # - first draft
    # 
    # Notes:
    # - TimeFormat https://msdn.microsoft.com/en-us/library/8kb3ddd4.aspx

    $DefaultColor = $Color[0]

    if ($LinesBefore -ne 0) {  
        for ($i = 0; $i -lt $LinesBefore; $i++) { 
            Write-Host "`n" -NoNewline 
        } 
    }

    if ($StartTab -ne 0) {  
        for ($i = 0; $i -lt $StartTab; $i++) { 
            Write-Host "`t" -NoNewLine 
        } 
    }

    if ($Color.Count -ge $Text.Count) {
        for ($i = 0; $i -lt $Text.Length; $i++) { 
            Write-Host $Text[$i] -ForegroundColor $Color[$i] -NoNewLine 
        } 
    } else {
        for ($i = 0; $i -lt $Color.Length ; $i++) { 
            Write-Host $Text[$i] -ForegroundColor $Color[$i] -NoNewLine 
        }
        for ($i = $Color.Length; $i -lt $Text.Length; $i++) { 
            Write-Host $Text[$i] -ForegroundColor $DefaultColor -NoNewLine 
        }
    }

    Write-Host

    if ($LinesAfter -ne 0) {  
        for ($i = 0; $i -lt $LinesAfter; $i++) { 
            Write-Host "`n" 
        } 
    }

    if ($LogFile -ne "") {
        $TextToFile = ""
        for ($i = 0; $i -lt $Text.Length; $i++) {
            $TextToFile += $Text[$i]
        }
        Write-Output "[$([datetime]::Now.ToString($TimeFormat))]$TextToFile" | Out-File $LogFile -Encoding unicode -Append
    }
}

function Deploy-ManagementGroupPolicies {
    param (
        [Parameter(Mandatory=$true)]
        [string]$diagnosticSettingsType,
        [Parameter(Mandatory=$true)]
        $managementGroup
    )

    try {
        Write-Host "`nConnecting to Github.com for Azure '$diagnosticSettingsType' Policies..."
        $jsonWeb = Invoke-WebRequest ("https://github.com/paullizer/azurePolicies")
        Write-Host "`tConnected to Github.com" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to connect to Github.com. Please validate access to internet and run process again."
        Break Script
    }
    
    for ($x = 1; $x -le $policyTotal; $x++){
        Write-Host ("`nProcessing $diagnosticSettingsType policy: " + $x + ".json") -ForegroundColor Magenta

        $jsonPath = ("https://raw.githubusercontent.com/paullizer/azurePolicies/main/diagnosticSettings/" + $diagnosticSettingsType + "/" + $x +".json")
    
        try {
            $jsonWeb = Invoke-WebRequest $jsonPath
        }
        catch{
            Write-Warning "Failed to pull policy from Github.com. Waiting 5 seconds to attempt one more time."
            Start-Sleep -s 5
            $jsonWeb = Invoke-WebRequest $jsonPath
        }
    
        $jsonObject = $jsonWeb.Content | ConvertFrom-Json
    
        if ($jsonObject){
            try {
                $resourceType = ($jsonObject.policyRule.if.equals).split(".")[($jsonObject.policyRule.if.equals).split(".").count-1]
            }
            catch {
                try {
                    $subResourceType = "-" + $jsonObject.policyRule.then.details.deployment.properties.template.resources.properties.logs[0].category.substring(0,10)
                    $resourceType = ($jsonObject.policyRule.if.allof[0].equals).split(".")[($jsonObject.policyRule.if.allof[0].equals).split(".").count-1]
                    $resourceType += $subResourceType
                }
                catch {
                    Write-Warning "Failed to get resourceType from Json Object"
                }
            }
    
            try {
                $purposeType = $jsonObject.policyRule.then.details.type.split(".")[$jsonObject.policyRule.then.details.type.split(".").count-1]
                $purposeType = $purposeType.split("/")[1]
            }
            catch {
                Write-Warning "Failed to get purposeType from Json Object"
            }
            
            if ($diagnosticSettingsType -eq "logAnalyticWorkspace"){
                $displayName = $userInputPrepend + "-" + $purposeType + "-LAW-"
            } elseif ($diagnosticSettingsType -eq "storageAccount") {
                $displayName = $userInputPrepend + "-" + $purposeType + "-SA-"
            }
    
            try {
                if ($resourceType.contains("/")) {
                    foreach ($value in ($resourceType.split("/"))){
                        $displayName += $value + "-"
                    }
                }
            }
            catch {
                Write-Warning "Failed to add value to displayName"
            }
    
            try {
                if ($displayName.endswith("-")){
                    $displayName = $displayName.substring(0,$displayName.length-1)
                }
            }
            catch {
                Write-Warning "Failed to remove '-' from displayname"
            }
    
            try {
                if ($displayName.length -gt 62){
                    $displayName = $displayName.substring(0,62)
                }
            }
            catch {
                Write-Warning "Failed to reduce displayName to less than 63 characters"
            }
    
            $policy = $jsonObject.PolicyRule | ConvertTo-Json -Depth 64
            $parameters = $jsonObject.Parameters | ConvertTo-Json -Depth 64
    
                $boolCreatePolicy = $false
                $definition = ""
                $assignment = ""
    
                $nameGUID = (new-guid).toString().replace("-","").substring(0,23)
                
                if ($diagnosticSettingsType -eq "logAnalyticWorkspace"){
                    $policyParameters = @{
                        'logAnalytics' = $logAnalyticWorkspaceResourceId
                        'profileName' = ("setbyPolicy_" + $userInputPrepend)
                    }
                } elseif ($diagnosticSettingsType -eq "storageAccount"){
                    $policyParameters = @{
                        'storageAccount' = $storageAccountResourceId
                        'profileName' = ("setbyPolicy_" + $userInputPrepend)
                    }
                } # elseif ($diagnosticSettingsType -eq "eventHub"){
                #     $policyParameters = @{
                #         'eventHub' = $storageAccountResourceId
                #         'profileName' = ("setbyPolicy_" + $userInputPrepend)
                #     }
                # }
                
                Write-Host ("    Management Group: " + $managementGroup.Name) -ForegroundColor Cyan
                Write-Host ("      Policy: " + $displayName) -ForegroundColor DarkCyan
                try {
                    Write-Host "`tEvaluating if Policy exists." -ForegroundColor Gray
                    $definition = Get-AzPolicyDefinition -Name $displayName -ManagementGroupName $managementGroup.Name -ErrorAction Stop
                }
                catch {
                    $boolCreatePolicy = $true
                }
    
                if ($definition){
                    Write-Host "`t`tPolicy exists. Moving to assignment task." -ForegroundColor Green
                }
                else {
                    $boolCreatePolicy = $true
                }
    
                if ($boolCreatePolicy){
                    Write-Host "`tCreating Policy." -ForegroundColor White
                    try {
                        $definition = New-AzPolicyDefinition -Name $displayName -Policy $policy -Parameter $parameters -ManagementGroupName $managementGroup.Name  -ErrorAction Stop
                        Write-Host ("`t`tCreated Azure Policy: " + $displayName + ", for management group: " + $managementGroup.Name) -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "Failed to create policy. Exiting process."
                        Break Script
                    }
                }
    
                try {
                    Write-Host "`tEvaluating if Policy Assignment exists." -ForegroundColor Gray
                    $assignment = Get-AzPolicyAssignment -PolicyDefinitionId $definition.PolicyDefinitionId -Scope $managementGroup.Id -ErrorAction Stop
                }
                catch {
                    Write-Host "`tCreating Policy Assignment." -ForegroundColor White
                }
    
                if($assignment){
                    Write-Host "`t`tPolicy Assignment exists." -ForegroundColor Green
                }
                else {
                    try {
                        $assignment = New-AzPolicyAssignment -Name $nameGUID -DisplayName ($displayName + "-Assignment") -Location 'eastus' -Scope $managementGroup.Id -PolicyDefinition $definition -PolicyParameterObject $policyParameters -AssignIdentity
                        Write-Host ("`t`tAssigned Azure Policy: " + $nameGUID + "/ " + ($displayName + "-Assignment") + " to management group: " + $managementGroup.Name) -ForegroundColor Green
    
                    }
                    catch {
                        Write-Warning ("Failed to Assign Azure Policy: " + $nameGUID + "/ " + ($displayName + "-Assignment") + " to management group: " + $managementGroup.Name)
                    }
                }

                if ($assignment){
                    Write-Host "`tEvaluating if Role 'Monitoring Contributor' Permissions Exist." -ForegroundColor Gray
                    
                    $role1DefinitionId = [GUID]($definition.properties.policyRule.then.details.roleDefinitionIds[0] -split "/")[4]
                    $role2DefinitionId = [GUID]($definition.properties.policyRule.then.details.roleDefinitionIds[1] -split "/")[4]
                    $objectID = [GUID]($assignment.Identity.principalId)
                    
                    try {
                        $role = Get-AzRoleAssignment -scope $managementGroup.id -ObjectId $objectID -RoleDefinitionId $role1DefinitionId -ErrorAction Stop
                    }
                    catch {
                        Write-Host "`tCreating 'Monitoring Contributor' Role." -ForegroundColor White
                    }

                    if(!$role){
                        try {            
                            Start-Sleep -s 3           
                            $role = New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $objectID -RoleDefinitionId $role1DefinitionId -ErrorAction Stop             
                            Write-Host ("`t`tAssigned Role Permissions for Account: 'Monitoring Contributor'") -ForegroundColor Green       
                        }
                        catch {
                            try {
                                Start-Sleep -s 15
                                $role = New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $objectID -RoleDefinitionId $role1DefinitionId -ErrorAction Stop
                                Write-Host ("`t`tAssigned Role Permissions for Account: 'Monitoring Contributor'") -ForegroundColor Green
                            }
                            catch {
                                Write-Warning ("Failed to assign Role Permissions for Account: 'Monitoring Contributor'. Manually correct via Azure Portal")
                            }
                        }
                    } else {
                        Write-Host "`t`t'Monitoring Contributor' Role exists." -ForegroundColor Green
                    }
    
                    
                    if ($diagnosticSettingsType -eq "logAnalyticWorkspace"){
                        $roleName = "Log Analytics Contributor"
                    } elseif ($diagnosticSettingsType -eq "storageAccount") {
                        $roleName = "Storage Account Contributor"
                    }

                    Write-Host "`tEvaluating if Role '$roleName' Permissions Exist." -ForegroundColor Gray
                    
                    try {
                        $role = Get-AzRoleAssignment -scope $managementGroup.id -ObjectId $objectID -RoleDefinitionId $role2DefinitionId -ErrorAction Stop
                    }
                    catch {
                        Write-Host "`tCreating '$roleName' Role." -ForegroundColor White
                    }
                    
                    if(!$role){
                        try {       
                            Start-Sleep -s 1          
                            $null = New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $objectID -RoleDefinitionId $role2DefinitionId -ErrorAction Stop
                            Write-Host ("`t`tAssigned Role Permissions for Account: $roleName'") -ForegroundColor Green
                        }
                        catch {
                            try {       
                                Start-Sleep -s 15            
                                $null = New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $objectID -RoleDefinitionId $role2DefinitionId -ErrorAction Stop
                                Write-Host ("`t`tAssigned Role Permissions for Account: $roleName'") -ForegroundColor Green
                            }
                            catch {
                                Write-Warning ("Failed to assign Role Permissions for Account: '" + $roleName + "'. Manually correct via Azure Portal")
                            }
                        }
                    } else {
                        Write-Host "`t`t'$roleName' Role exists." -ForegroundColor Green
                    }

                    $remediation = ""

                    try {
                        Write-Host "`tEvaluating if Remediation Task exists." -ForegroundColor Gray
                        $remediation = Get-AzPolicyRemediation -Name ("Remediate-" + $displayName) -ManagementGroupName $managementGroup.Name -ErrorAction Stop
                    }
                    catch {
                        Write-Host ("`t`tCreating Remediation Task: Remediate-" + $displayName) -ForegroundColor White
                    }

                    if($remediation){
                        Write-Host ("`t`tRemediation Task exists.") -ForegroundColor Green
                    }
                    else {
                        try {
                            $remediation = Start-AzPolicyRemediation -Name ("Remediate-" + $displayName) -ManagementGroupName $managementGroup.Name -PolicyAssignmentId $assignment.PolicyAssignmentId
                            Write-Host ("`t`tCreated Remediation Task: Remediate " + $displayName) -ForegroundColor Gree
        
                        }
                        catch {
                            Write-Warning ("Failed to create remediation task. Manually create task via Azure Portal")
                        }
                    }
                }
        } else {
            Write-Warning "Failed to collect policy from Github.com after two attempts. Validate access to internet and to github.com. Process will review where it left off and will resume when restarted. Exiting process."
            Break Script
        }
    }
}

function Deploy-SubscriptionPolicies {
    param (
        [Parameter(Mandatory=$true)]
        [string]$diagnosticSettingsType,
        [Parameter(Mandatory=$true)]
        $subscriptionObject
    )

    try {
        Write-Host "`nConnecting to Github.com for Azure '$diagnosticSettingsType' Policies..."
        $jsonWeb = Invoke-WebRequest ("https://github.com/paullizer/azurePolicies")
        Write-Host "`tConnected to Github.com" -ForegroundColor Green
    }
    catch{
        Write-Warning "Failed to connect to Github.com. Please validate access to internet and run process again."
        Break Script
    }
    
    for ($x = 1; $x -le $policyTotal; $x++){
        Write-Host ("`nProcessing $diagnosticSettingsType policy: " + $x + ".json") -ForegroundColor Magenta
    
        $jsonPath = ("https://raw.githubusercontent.com/paullizer/azurePolicies/main/diagnosticSettings/" + $diagnosticSettingsType + "/" + $x +".json")
    
        try {
            $jsonWeb = Invoke-WebRequest $jsonPath
        }
        catch{
            Write-Warning "Failed to pull policy from Github.com. Waiting 5 seconds to attempt one more time."
            Start-Sleep -s 5
    
            $jsonWeb = Invoke-WebRequest $jsonPath
        }
    
        $jsonObject = $jsonWeb.Content | ConvertFrom-Json
    
        if ($jsonObject){
            try {
                $resourceType = ($jsonObject.policyRule.if.equals).split(".")[($jsonObject.policyRule.if.equals).split(".").count-1]
            }
            catch {
                try {
                    $subResourceType = "-" + $jsonObject.policyRule.then.details.deployment.properties.template.resources.properties.logs[0].category.substring(0,10)
                    $resourceType = ($jsonObject.policyRule.if.allof[0].equals).split(".")[($jsonObject.policyRule.if.allof[0].equals).split(".").count-1]
                    $resourceType += $subResourceType
                }
                catch {
                    Write-Warning "Failed to get resourceType from Json Object"
                }
            }
    
            try {
                $purposeType = $jsonObject.policyRule.then.details.type.split(".")[$jsonObject.policyRule.then.details.type.split(".").count-1]
                $purposeType = $purposeType.split("/")[1]
            }
            catch {
                Write-Warning "Failed to get purposeType from Json Object"
            }
            
            if ($diagnosticSettingsType -eq "logAnalyticWorkspace"){
                $displayName = $userInputPrepend + "-" + $purposeType + "-LAW-"
            } elseif ($diagnosticSettingsType -eq "storageAccount") {
                $displayName = $userInputPrepend + "-" + $purposeType + "-SA-"
            }
    
            try {
                if ($resourceType.contains("/")) {
                    foreach ($value in ($resourceType.split("/"))){
                        $displayName += $value + "-"
                    }
                }
            }
            catch {
                Write-Warning "Failed to add value to displayName"
            }
    
            try {
                if ($displayName.endswith("-")){
                    $displayName = $displayName.substring(0,$displayName.length-1)
                }
            }
            catch {
                Write-Warning "Failed to remove '-' from displayname"
            }
    
            try {
                if ($displayName.length -gt 62){
                    $displayName = $displayName.substring(0,62)
                }
            }
            catch {
                Write-Warning "Failed to reduce displayName to less than 63 characters"
            }
    
            $policy = $jsonObject.PolicyRule | ConvertTo-Json -Depth 64
    
            $parameters = $jsonObject.Parameters | ConvertTo-Json -Depth 64
    
            $boolCreatePolicy = $false
            $definition = ""
            $assignment = ""

            $nameGUID = (new-guid).toString().replace("-","").substring(0,23)
            
            if ($diagnosticSettingsType -eq "logAnalyticWorkspace"){
                $policyParameters = @{
                    'logAnalytics' = $logAnalyticWorkspaceResourceId
                    'profileName' = ("setbyPolicy_" + $userInputPrepend)
                }
            } elseif ($diagnosticSettingsType -eq "storageAccount"){
                $policyParameters = @{
                    'storageAccount' = $storageAccountResourceId
                    'profileName' = ("setbyPolicy_" + $userInputPrepend)
                }
            } # elseif ($diagnosticSettingsType -eq "eventHub"){
            #     $policyParameters = @{
            #         'eventHub' = $storageAccountResourceId
            #         'profileName' = ("setbyPolicy_" + $userInputPrepend)
            #     }
            # }
            
            try {
                Write-Host "`tEvaluating if Policy exists." -ForegroundColor Gray
                $definition = Get-AzPolicyDefinition -Name $displayName -SubscriptionId $subscriptionObject.Id -ErrorAction Stop
            }
            catch {
                $boolCreatePolicy = $true
            }

            if ($definition){
                Write-Host "`t`tPolicy exists. Moving to assignment task." -ForegroundColor Green
            }
            else {
                $boolCreatePolicy = $true
            }

            if ($boolCreatePolicy){
                Write-Host "`t`tCreating Policy." -ForegroundColor White
                try {
                    $definition = New-AzPolicyDefinition -Name $displayName -Policy $policy -Parameter $parameters -SubscriptionId $subscriptionObject.Id  -ErrorAction Stop
                    Write-Host ("`t`tCreated Azure Policy: " + $displayName + ", for subscription: " + $subscriptionObject.Name) -ForegroundColor Green
                }
                catch {
                    Write-Host ($_.Exception)
                    pause
                    Write-Warning ("Failed to create policy. Exiting process.")
                    #Break Script
                }
            }

            try {
                Write-Host "`tEvaluating if Policy Assignment exists." -ForegroundColor Gray
                $assignment = Get-AzPolicyAssignment -Scope "/subscriptions/$($subscriptionObject.Id)" -PolicyDefinitionId $definition.PolicyDefinitionId -ErrorAction Stop
                    
            }
            catch {
                Write-Host "`tCreating Policy Assignment." -ForegroundColor White
            }

            if($assignment){
                Write-Host "`t`tPolicy Assignment exists." -ForegroundColor Green
            }
            else {
                try {
                    $assignment = New-AzPolicyAssignment -Name $nameGUID -DisplayName ($displayName + "-Assignment") -Location 'eastus' -Scope "/subscriptions/$($subscriptionObject.Id)" -PolicyDefinition $definition -PolicyParameterObject $policyParameters -AssignIdentity
                    Write-Host ("`t`tAssigned Azure Policy: " + $nameGUID + "/ " + ($displayName + "-Assignment") + " to subscription: " + $subscriptionObject.Name) -ForegroundColor Green

                }
                catch {
                    Write-Warning ("Failed to Assign Azure Policy: " + $nameGUID + "/ " + ($displayName + "-Assignment") + " to subscription: " + $subscriptionObject.Name)
                }
            }

            if ($assignment){
                Write-Host "`tEvaluating if Role 'Monitoring Contributor' Permissions Exist." -ForegroundColor Gray
                
                $role1DefinitionId = [GUID]($definition.properties.policyRule.then.details.roleDefinitionIds[0] -split "/")[4]
                $role2DefinitionId = [GUID]($definition.properties.policyRule.then.details.roleDefinitionIds[1] -split "/")[4]
                $objectID = [GUID]($assignment.Identity.principalId)
                
                try {
                    $role = Get-AzRoleAssignment -scope "/subscriptions/$($subscriptionObject.Id)" -ObjectId $objectID -RoleDefinitionId $role1DefinitionId -ErrorAction Stop
                }
                catch {
                    Write-Host "`tCreating 'Monitoring Contributor' Role." -ForegroundColor White
                }

                if(!$role){
                    try {            
                        Start-Sleep -s 3           
                        $role = New-AzRoleAssignment -Scope "/subscriptions/$($subscriptionObject.Id)" -ObjectId $objectID -RoleDefinitionId $role1DefinitionId -ErrorAction Stop             
                        Write-Host ("`t`tAssigned Role Permissions for Account: 'Monitoring Contributor'") -ForegroundColor Green       
                    }
                    catch {
                        try {
                            Start-Sleep -s 15
                            $role = New-AzRoleAssignment -Scope "/subscriptions/$($subscriptionObject.Id)" -ObjectId $objectID -RoleDefinitionId $role1DefinitionId -ErrorAction Stop
                            Write-Host ("`t`tAssigned Role Permissions for Account: 'Monitoring Contributor'") -ForegroundColor Green
                        }
                        catch {
                            Write-Warning ("Failed to assign Role Permissions for Account: 'Monitoring Contributor'. Manually correct via Azure Portal")
                        }
                    }
                } else {
                    Write-Host ("`t`t'Monitoring Contributor' Role exists.") -ForegroundColor Green
                }

                
                if ($diagnosticSettingsType -eq "logAnalyticWorkspace"){
                    $roleName = "Log Analytics Contributor"
                } elseif ($diagnosticSettingsType -eq "storageAccount") {
                    $roleName = "Storage Account Contributor"
                }

                Write-Host "`tEvaluating if Role '$roleName' Permissions Exist." -ForegroundColor Gray
                
                try {
                    $role = Get-AzRoleAssignment -scope "/subscriptions/$($subscriptionObject.Id)" -ObjectId $objectID -RoleDefinitionId $role2DefinitionId -ErrorAction Stop
                }
                catch {
                    Write-Host ("`tCreating '$roleName' Role.") -ForegroundColor White
                }
                
                if(!$role){
                    try {       
                        Start-Sleep -s 1          
                        $null = New-AzRoleAssignment -Scope "/subscriptions/$($subscriptionObject.Id)" -ObjectId $objectID -RoleDefinitionId $role2DefinitionId -ErrorAction Stop
                        Write-Host ("`t`tAssigned Role Permissions for Account: $roleName'") -ForegroundColor Green
                    }
                    catch {
                        try {       
                            Start-Sleep -s 15            
                            $null = New-AzRoleAssignment -Scope "/subscriptions/$($subscriptionObject.Id)" -ObjectId $objectID -RoleDefinitionId $role2DefinitionId -ErrorAction Stop
                            Write-Host ("`t`tAssigned Role Permissions for Account: $roleName'") -ForegroundColor Green
                        }
                        catch {
                            Write-Warning ("Failed to assign Role Permissions for Account: '" + $roleName + "'. Manually correct via Azure Portal")
                        }
                    }
                } else {
                    Write-Host "`t`t'$roleName' Role exists." -ForegroundColor Green
                }

                $remediation = ""
                
                try {
                    Write-Host "`tEvaluating if Remediation Task exists." -ForegroundColor Gray
                    $remediation = Get-AzPolicyRemediation -Name ("Remediate-" + $displayName) -ErrorAction Stop
                }
                catch {
                    Write-Host ("`t`tCreating Remediation Task: Remediate-" + $displayName) -ForegroundColor White
                }

                if($remediation){
                    Write-Host ("`t`tRemediation Task exists.") -ForegroundColor Green
                }
                else {
                    try {
                        $remediation = Start-AzPolicyRemediation -PolicyAssignmentId $assignment.PolicyAssignmentId -Name ("Remediate-" + $displayName)
                        Write-Host ("`t`tCreated Remediation Task: Remediate " + $displayName) -ForegroundColor Gree
    
                    }
                    catch {
                        Write-Warning ("Failed to create remediation task. Manually create task via Azure Portal")
                    }
                }
            }
            
        } else {
            Write-Warning "Failed to collect policy from Github.com after two attempts. Validate access to internet and to github.com. Process will review where it left off and will resume when restarted. Exiting process."
            Break Script
        }
    }
}

###------------Execution ---------------

Clear-Host

Write-Host "`nThis process will deploy Azure Policies that enable the delivery of diagnostic settings to a Log Analytic Workspace and archive them to a Storage Account.`n" -ForegroundColor Cyan
Write-Host "`nValidating Azure PowerShell is installed`n"

try{
    $azureModuleObjects = Get-Module -ListAvailable -Name Az.*

    if (!$azureModuleObjects){
        Write-Warning "Azure PowerShell is not installed."
        Write-Host "Checking for elevated permissions..."

        if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
            [Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Warning "Insufficient permissions to install Azure PowerShell Module. Open the PowerShell console as an administrator and run this script again."
            Break
        }
        else {
            Write-Host "`t`tCode is running as administrator" -ForegroundColor Green
            Write-Host "`tAttempting to install Azure PowerShell..."
            Install-Module -Name Az -AllowClobber -Scope AllUsers
            Write-Host "`t`tAzure PowerShell Installed." -ForegroundColor Green
        }
    }
}
catch {
    Write-Warning "`tAzure PowerShell is not installed."
    Write-Host "`tChecking for elevated permissions..."

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "`tInsufficient permissions to install Azure PowerShell Module. Open the PowerShell console as an administrator and run this script again."
        Break
    } else {
        Write-Host "`t`tCode is running as administrator" -ForegroundColor Green
            Write-Host "`tAttempting to install Azure PowerShell..."
            Install-Module -Name Az -AllowClobber -Scope AllUsers
            Write-Host "`t`tAzure PowerShell Installed." -ForegroundColor Green
    }
}

try {
    $azContext = Get-AzContext -ListAvailable
}
catch {
    Write-Warning "Not connected to Azure Account. Attempting connection, please following Browser Prompts."
}

if (!$azContext){
    try {
        Connect-AzAccount
    }
    catch {
        Write-Warning "Failed to connect to Azure. Please verify access to internet or permissions to Azure. Existing process."
        Break Script
    }
}
else {
    $boolTryAgain = $false
    $boolAccountFound = $false

    while (!$boolAccountFound) {
        Write-Host ("Connected to Accounts: `n") -ForegroundColor Gray

        foreach ($az in $azContext){
            Write-Host ("`t`t" + $az.name.split("(")[0] + ", " + $az.Account.Id)
        }

        $userInputTryAgain = Read-Host ("`n`tDo you want to connect to any additional accounts? [Y or Yes, N or No]")

        switch ($userInputTryAgain.ToLower()) {
            "n" {
                $boolAccountFound = $true
            }
            "no" { 
                $boolAccountFound = $true
            }
            "y" { $boolTryAgain = $true }
            "yes" { $boolTryAgain = $true }
            Default { 
                Write-Warning "Incorrect value. Please enter [Y or Yes, N or No]" 
                $boolTryAgain = $false
            }
        }

        if ($boolTryAgain){
            Connect-AzAccount
            $azContext = Get-AzContext -ListAvailable
        }  
    }
}


$boolTryAgain = $true
$boolTenantFound = $false

while (!$boolTenantFound) {
    if ($boolTryAgain){
        $userInputTenantId = Read-Host "`nPlease enter Tenant Id"
    }

    $tenant = Get-AzTenant $userInputTenantId
    
    if ($tenant){
        $boolTenantFound = $true
    } else {
        Write-Warning "Unable to find Tenant, please enter valid name or confirm your access to resource."
    
        $userInputTryAgain = Read-Host "Do you want to try again? [Y or Yes, N or No]"

        switch ($userInputTryAgain.ToLower()) {
            "n" {
                Break Script
            }
            "no" { 
                Break Script
            }
            "y" { $boolTryAgain = $true }
            "yes" { $boolTryAgain = $true }
            Default { 
                Write-Warning "Incorrect value. Please enter [Y or Yes, N or No]" 
                $boolTryAgain = $false
            }
        }
    }
}

if ($azContext.Tenant.Id -ne $tenant.Id){
    try {
        Set-AzContext -TenantId $tenant.Id | Out-Null
    }
    catch {
        Write-Warning "Unable to set Azure Context. Please verify access to context. Existing process."
        Break Script
    }
}

Write-Host ("`tConnected to " + $tenant.name + " with Tenant ID " + $tenant.Id) -ForegroundColor Green

$boolDeploy2Subscription = $false
$boolDeploy2ManagementGroup = $false
do {
    Write-Color "`n-------------------", " Policy Deployment Location Selection ", "-------------------" -Color Gray, White, Gray

    if ($boolDeploy2Subscription){
        Write-Color "[", ([Char]8730).tostring(), "]", " Deploying Policies to Subscription(s)." -Color White, Green, White, White
    } else {
        Write-Color "1.  ", "Press ", "'1'", " or", " 'S(s)'", " to Deploy Policies to Subscription(s)." -Color Gray, White, Cyan, White, Cyan, White
    }

    if ($boolDeploy2ManagementGroup){
        Write-Color "[", ([Char]8730).tostring(), "]", " Deploying Policies to Management Group(s)." -Color White, Green, White, White
    } else {
        Write-Color "2.  ", "Press ", "'2'", " or", " 'M(m)'", " to Deploy Policies to Management Group(s)." -Color Gray, White, Cyan, White, Cyan, White
    }
    
    if ($boolDeploy2Subscription -and $boolDeploy2ManagementGroup){
        $userInput = "3"
    } else {
        if ($boolDeploy2Subscription -or $boolDeploy2ManagementGroup){
            Write-Color "3.  ", "Press ", "'3'", " or", " 'D(d)'", " to Complete Policy Deployment Location Selection." -Color Gray, White, Cyan, White, Cyan, White -LinesBefore 1
            $userInput = Read-Host "`nPlease select a menu option:"
        } else {
            $userInput = Read-Host "`nPlease select a location to deploy the policies:"
        }
    }

    switch ($userInput.ToLower()) {
        "s" {
            if ($boolDeploy2Subscription){
                $boolDeploy2Subscription = $false
            } else {
                $boolDeploy2Subscription = $true
            }
        }
        "1" {
            if ($boolDeploy2Subscription){
                $boolDeploy2Subscription = $false
            } else {
                $boolDeploy2Subscription = $true
            }
        }
        "m" {
            if ($boolDeploy2ManagementGroup){
                $boolDeploy2ManagementGroup = $false
            } else {
                $boolDeploy2ManagementGroup = $true
            }
        }
        "2" {
            if ($boolDeploy2ManagementGroup){
                $boolDeploy2ManagementGroup = $false
            } else {
                $boolDeploy2ManagementGroup = $true
            }
        }
        "3" {
        }
        "d" {
        }
        Default { 
            Write-Warning "Incorrect selection." 
        }
    }
}
until (($userInput -eq '3') -or ($userInput.ToLower() -eq 'd'))


[System.Collections.ArrayList]$userInputSubscriptionId = @()
[System.Collections.ArrayList]$subscriptionObjects = @()
$boolTryAgain = $true

if ($boolDeploy2Subscription){
    $boolMoreSubscriptions = $true
    while ($boolMoreSubscriptions) {
        if ($boolTryAgain){
            $userInputSubscriptionId.Add((Read-Host "`nPlease enter Subscription Id")) | Out-Null
        }

        $userInputAddAnotherSub = Read-Host "`tDo you want to enter another Subscription? [Y or Yes, N or No]"

        switch ($userInputAddAnotherSub.ToLower()) {
            "n" { 
                $boolMoreSubscriptions = $false

            }
            "no" { 
                $boolMoreSubscriptions = $false 

            }
            "y" {  
                $boolTryAgain = $true
            }
            "yes" { 
                $boolTryAgain = $true
                }
            Default { 
                Write-Warning "Incorrect value. Please enter [Y or Yes, N or No]" 
                $boolTryAgain = $false
            }
        }
    }

    foreach ($subscriptionId in $userInputSubscriptionId){
        try{
            $subscriptionObject = Get-AzSubscription -SubscriptionId $subscriptionId -ErrorAction Stop
        }
        catch {
            Write-Warning "Unable to collect Subscription information. Please verify access to internet and permissions to resource. Exiting process."
            Break Script
        }

        if ($subscriptionObject){
            $subscriptionObjects.Add($subscriptionObject) | Out-Null
        }
    }
}

[System.Collections.ArrayList]$userInputManagementGroupName = @()
[System.Collections.ArrayList]$managementGroups = @()
$boolTryAgain = $true

if ($boolDeploy2ManagementGroup){
    $boolMoreManagementGroups = $true

    while ($boolMoreManagementGroups) {
        if ($boolTryAgain){
            $userInputManagementGroupName.Add((Read-Host "`nPlease enter Management Group Id")) | Out-Null
        }

        $userInputAddAnotherMG = Read-Host "`tDo you want to enter another Management Group? [Y or Yes, N or No]"

        switch ($userInputAddAnotherMG.ToLower()) {
            "n" { 
                $boolMoreManagementGroups = $false
            }
            "no" { 
                $boolMoreManagementGroups = $false 
            }
            "y" {  
                $boolTryAgain = $true
            }
            "yes" { 
                $boolTryAgain = $true
                }
            Default { 
                Write-Warning "Incorrect value. Please enter [Y or Yes, N or No]" 
                $boolTryAgain = $false
            }
        }
    }

    foreach ($managementGroupName in $userInputManagementGroupName){
        try{
            $managementGroupObject = Get-AzManagementGroup $managementGroupName
        }
        catch {
            Write-Warning "Unable to collect Management Group information. Please verify access to internet and permissions to resource. Exiting process."
            Break Script
        }

        if ($managementGroupObject){
            $managementGroups.Add($managementGroupObject) | Out-Null
        }
    }
}

$boolDeployLogAnalyticWorkspaceSettings = $false
$boolDeployStorageAccountSettings = $false
#$boolDeployEventHubSettings = $false

do {
    Write-Color "`n-------------------", " Diagnostic Policy Selection ", "-------------------" -Color Gray, White, Gray

    if ($boolDeployLogAnalyticWorkspaceSettings){
        Write-Color "[", ([Char]8730).tostring(), "]", " Deploying Log Analytic Diagnostic Policies" -Color White, Green, White, White
    } else {
        Write-Color "1.  ", "Press ", "'1'", " or", " 'L(l)'", " to Deploy Log Analytic Diagnostic Policies" -Color Gray, White, Cyan, White, Cyan, White
    }

    if ($boolDeployStorageAccountSettings){
        Write-Color "[", ([Char]8730).tostring(), "]", " Deploying Storage Account Policies" -Color White, Green, White, White
    } else {
        Write-Color "2.  ", "Press ", "'2'", " or", " 'S(s)'", " to Deploy Storage Account Policies" -Color Gray, White, Cyan, White, Cyan, White
    }

    # if ($boolDeployEventHubSettings){
    #     Write-Color "[", ([Char]8730).tostring(), "]", " Deploying Event Hub Policies" -Color White, Green, White, White
    # } else {
    #     Write-Color "3.  ", "Press ", "'3'", " or", " 'E(e)'", " to Deploy Event Hub Policies" -Color Gray, White, Cyan, White, Cyan, White
    # }
    
    if ($boolDeployLogAnalyticWorkspaceSettings -and $boolDeployStorageAccountSettings){
        $userInput = "4"
    } else {
        if ($boolDeployLogAnalyticWorkspaceSettings -or $boolDeployStorageAccountSettings){
            Write-Color "4.  ", "Press ", "'4'", " or", " 'D(d)'", " to Complete Policy Selection" -Color Gray, White, Cyan, White, Cyan, White -LinesBefore 1
            $userInput = Read-Host "`nPlease select a menu option:"
        } else {
            $userInput = Read-Host "`nPlease select a policy to deploy:"
        }
    }

    switch ($userInput.ToLower()) {
        "l" {
            if ($boolDeployLogAnalyticWorkspaceSettings){
                $boolDeployLogAnalyticWorkspaceSettings = $false
            } else {
                $boolDeployLogAnalyticWorkspaceSettings = $true
            }
        }
        "1" {
            if ($boolDeployLogAnalyticWorkspaceSettings){
                $boolDeployLogAnalyticWorkspaceSettings = $false
            } else {
                $boolDeployLogAnalyticWorkspaceSettings = $true
            }
        }
        "2" {
            if ($boolDeployStorageAccountSettings){
                $boolDeployStorageAccountSettings = $false
            } else {
                $boolDeployStorageAccountSettings = $true
            }
        }
        "s" {
            if ($boolDeployStorageAccountSettings){
                $boolDeployStorageAccountSettings = $false
            } else {
                $boolDeployStorageAccountSettings = $true
            }
        }
        "4" {
        }
        "d" {
        }
        Default { 
            Write-Warning "Incorrect selection." 
        }
    }
}
until (($userInput -eq '4') -or ($userInput.ToLower() -eq 'd'))

$boolCorrectUserInput = $true

while ($boolCorrectUserInput) {
    $userInputPrepend = Read-Host "`nEnter characters to prepend Azure Policy Display name [1-4 characters, e.g. 0001, TEST, or 11AB; NO special characters]"

    $array = @('~', '!', '@', '#', '$', '%', '^', '&', '\(', '\)', '-', '.+', '=', '}', '{', '\\', '/', '|', ';', ',', ':', '<', '>', '\?', '"', '\*')
    $boolContainsSpecial = $false

    switch ($userInputPrepend.Length) {
        {1..4 -contains $_} { 
            foreach($char in $array){
                if($userInputPrepend.contains( $char )){
                    Write-Warning "Contains Special characters. Please enter [1-4 characters, e.g. 0001, TEST, or 11AB; NO special characters]" 
                    $boolContainsSpecial = $true
                    Break
                }
            }

            if (!$boolContainsSpecial){
                Write-Host "`tAzure Policies will start with '$userInputPrepend'`n" -ForegroundColor Green
                $boolCorrectUserInput = $false
            }
        }
        {$_ -gt 4} { 
            Write-Warning "Too many characters. Please enter [1-4 characters, e.g. 0001, TEST, or 11AB; NO special characters]" 
        }
        Default { 
            Write-Warning "No characters entered. Please enter [1-4 characters, e.g. 0001, TEST, or 11AB; NO special characters]" 
        }
    }
}

if ($boolDeployLogAnalyticWorkspaceSettings ){
    $subs = Get-AzSubscription -TenantId $tenant.Id
    $boolLAWFound = $false

    while (!$boolLAWFound) {
        $userInputLAWName = Read-Host "`nPlease enter Log Analytics Workspace Name"

        for ($x = 0; $x -lt $subs.count; $x++){

            if(!$boolLAWFound){
                Write-Host ("`tSubscription: " + $subs[$x].Name) -ForegroundColor Cyan

                try {
                    #Write-Host "`tSelecting Subscription." -ForegroundColor White
                    Select-AzSubscription -Subscription $subs[$x].Name | Out-Null
                    #Write-Host "`t`tSubscription selected." -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to select Subscription. Exiting process."
                    Break Script
        
                }

                try {
                    Write-Host "`tSearching..." -ForegroundColor White
                    $logAnalyticWorkspaceObject = Get-AzResource -name $userInputLAWName -ErrorAction Stop
                }
                catch {
                    
                }

                if ($logAnalyticWorkspaceObject){
                    Write-Host "`t`tFound." -ForegroundColor Green
                    $x = $subs.count
                    $boolLAWFound = $true
                }
                else {
                    Write-Host "`t`tDid not find. Moving to next subscription." -ForegroundColor White
                }
            }
        }

        if ($logAnalyticWorkspaceObject){
            $logAnalyticWorkspaceResourceId = $logAnalyticWorkspaceObject.ResourceId
        } else {
            Write-Warning "Unable to find Log Analytics Workspace, please enter valid name or confirm your access to resource."

            $userInputTryAgain = Read-Host "`tDo you want to try again? [Y or Yes, N or No]"

            if (($userInputTryAgain.ToLower() -eq "n") -or ($userInputTryAgain.ToLower() -eq "no")){
                Exit 
            }
        }
    }
}


if ($boolDeployStorageAccountSettings){
    $subs = Get-AzSubscription -TenantId $tenant.Id
    $boolLAWFound = $false

    while (!$boolSAFound) {
        $userInputSAName = Read-Host "`nPlease enter Storage Account Name"

        for ($x = 0; $x -lt $subs.count; $x++){

            if(!$boolSAFound){
                Write-Host ("`tSubscription: " + $subs[$x].Name) -ForegroundColor Cyan

                try {
                    #Write-Host "`tSelecting Subscription." -ForegroundColor White
                    Select-AzSubscription -Subscription $subs[$x].Name | Out-Null
                    #Write-Host "`t`tSubscription selected." -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to select Subscription. Exiting process."
                    Break Script
        
                }

                try {
                    Write-Host "`tSearching..." -ForegroundColor White
                    $storageAccountObject = Get-AzResource -name $userInputSAName -ErrorAction Stop
                }
                catch {
                    
                }

                if ($storageAccountObject){
                    Write-Host "`t`tFound." -ForegroundColor Green
                    $x = $subs.count
                    $boolSAFound = $true
                }
                else {
                    Write-Host "`t`tDid not find. Moving to next subscription." -ForegroundColor White
                }
            }
        }

        if ($storageAccountObject){
            $storageAccountResourceId = $storageAccountObject.ResourceId
        } else {
            Write-Warning "Unable to find Storage Account, please enter valid name or confirm your access to resource."

            $userInputTryAgain = Read-Host "`tDo you want to try again? [Y or Yes, N or No]"

            if (($userInputTryAgain.ToLower() -eq "n") -or ($userInputTryAgain.ToLower() -eq "no")){
                Exit 
            }
        }
    }
}

if ($boolDeploy2Subscription){
    foreach ($subscriptionObject in $subscriptionObjects){
        try {
            Write-Host "`nEvalauting if Resource Provider Microsot.PolicyInsights is Registered." -ForegroundColor Gray
            $policyInsights = Get-AzResourceProvider -ProviderNamespace "Microsoft.PolicyInsights" -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to collect Resource Provider status. Exiting process."
            Break Script
        }

        if ($policyInsights){
            foreach ($pi in $policyInsights) {
                if ($pi.RegistrationState -eq "NotRegistered"){
                    try {
                        Write-Host "`tMicrosot.PolicyInsights is NOT Registered. Attempting to Register." -ForegroundColor White
                        Register-AzResourceProvider -ProviderNamespace "Microsoft.PolicyInsights" | Out-Null
                        Write-Host "`t`tRegistered Microsot.PolicyInsights" -ForegroundColor Green
                        Break
                    }
                    catch {
                        Write-Warning "Failed to register Microsot.PolicyInsights. Exiting process."
                        Break Script
                    }
                }

                if ($pi.RegistrationState -eq "Registered"){
                    Write-Host "`tMicrosot.PolicyInsights is registered." -ForegroundColor White
                    Break
                }
            }
        }

        try {
            Write-Host "`nEvalauting if Resource Provider Microsoft.OperationalInsights is Registered." -ForegroundColor Gray
            $operationalInsights = Get-AzResourceProvider -ProviderNamespace "Microsoft.OperationalInsights" -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to collect Resource Provider status. Exiting process."
            Break Script
        }

        if ($operationalInsights){
            foreach ($oi in $operationalInsights) {
                if ($oi.RegistrationState -eq "NotRegistered"){
                    try {
                        Write-Host "`tMicrosot.OperationalInsights is NOT Registered. Attempting to Register." -ForegroundColor White
                        Register-AzResourceProvider -ProviderNamespace "Microsoft.OperationalInsights" | Out-Null
                        Write-Host "`t`tRegistered Microsot.OperationalInsights" -ForegroundColor Green
                        Break
                    }
                    catch {
                        Write-Warning "Failed to register Microsot.OperationalInsights. Exiting process."
                        Break Script
                    }
                }

                if ($oi.RegistrationState -eq "Registered"){
                    Write-Host "`tMicrosot.OperationalInsights is registered." -ForegroundColor White
                    Break
                }
            }
        }
    }
}

if ($boolDeployLogAnalyticWorkspaceSettings ){
    if ($boolDeploy2Subscription){
        foreach ($subscriptionObject in $subscriptionObjects){
            Write-Host ("`nDeploying policies. " + $subscriptionObject.Name) -ForegroundColor Gray
            Write-Host ("`tSubscription: " + $subscriptionObject.Name) -ForegroundColor Cyan

            try {
                Write-Host "`t`tSelecting Subscription." -ForegroundColor White
                Select-AzSubscription -Subscription $subscriptionObject.Name | Out-Null
                Write-Host "`t`t`tSubscription selected." -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to select Subscription. Exiting process."
                Break Script

            }
            Deploy-SubscriptionPolicies "logAnalyticWorkspace" $subscriptionObject
        }
    }

    if ($boolDeploy2ManagementGroup){
        foreach ($managementGroup in $managementGroups){
            Deploy-ManagementGroupPolicies "logAnalyticWorkspace" $managementGroup
        }
    }
}

if ($boolDeployStorageAccountSettings){
    if ($boolDeploy2Subscription){
        foreach ($subscriptionObject in $subscriptionObjects){
            Write-Host ("`nDeploying policies. " + $subscriptionObject.Name) -ForegroundColor Gray
            Write-Host ("`tSubscription: " + $subscriptionObject.Name) -ForegroundColor Cyan

            try {
                Write-Host "`t`tSelecting Subscription." -ForegroundColor White
                Select-AzSubscription -Subscription $subscriptionObject.Name | Out-Null
                Write-Host "`t`t`tSubscription selected." -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to select Subscription. Exiting process."
                Break Script

            }

            Deploy-SubscriptionPolicies "storageAccount" $subscriptionObject 
        }
    }

    if ($boolDeploy2ManagementGroup){
        foreach ($managementGroup in $managementGroups){
            Deploy-ManagementGroupPolicies "storageAccount" $managementGroup
        }
    }
}

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "false"

Write-Host "`nPolicy Deployment Complete." -ForegroundColor Green