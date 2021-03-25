function Write-Color([String[]]$Text, [ConsoleColor[]]$Color = "White", [int]$StartTab = 0, [int] $LinesBefore = 0,[int] $LinesAfter = 0, [string] $LogFile = "", $TimeFormat = "yyyy-MM-dd HH:mm:ss") {
    # version 0.2
    # - added logging to file
    # version 0.1
    # - first draft
    # 
    # Notes:
    # - TimeFormat https://msdn.microsoft.com/en-us/library/8kb3ddd4.aspx

    $DefaultColor = $Color[0]
    if ($LinesBefore -ne 0) {  for ($i = 0; $i -lt $LinesBefore; $i++) { Write-Host "`n" -NoNewline } } # Add empty line before
    if ($StartTab -ne 0) {  for ($i = 0; $i -lt $StartTab; $i++) { Write-Host "`t" -NoNewLine } }  # Add TABS before text
    if ($Color.Count -ge $Text.Count) {
        for ($i = 0; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -ForegroundColor $Color[$i] -NoNewLine } 
    } else {
        for ($i = 0; $i -lt $Color.Length ; $i++) { Write-Host $Text[$i] -ForegroundColor $Color[$i] -NoNewLine }
        for ($i = $Color.Length; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -ForegroundColor $DefaultColor -NoNewLine }
    }
    Write-Host
    if ($LinesAfter -ne 0) {  for ($i = 0; $i -lt $LinesAfter; $i++) { Write-Host "`n" } }  # Add empty line after
    if ($LogFile -ne "") {
        $TextToFile = ""
        for ($i = 0; $i -lt $Text.Length; $i++) {
            $TextToFile += $Text[$i]
        }
        Write-Output "[$([datetime]::Now.ToString($TimeFormat))]$TextToFile" | Out-File $LogFile -Encoding unicode -Append
    }
}

function Deploy-DiagnosticSettingsPolicies {

    param (
        [string]
        $diagnosticSettingsType
    )

    try {
        Write-Host "`nConnecting to Github.com for Azure Policies..."
        $jsonWeb = Invoke-WebRequest ("https://github.com/paullizer/azurePolicies")
        Write-Host "`tConnected to Github.com" -ForegroundColor Green
    }
    catch{
        Write-Warning "Failed to connect to Github.com. Please validate access to internet and run process again."
        Break Script
    }
    
    for ($x = 1; $x -le $policyTotal; $x++){
        Write-Host ("`nProcessing JSON policy: " + $x + ".json") -ForegroundColor White
    
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
    
            }
    
            try {
                $purposeType = $jsonObject.policyRule.then.details.type.split(".")[$jsonObject.policyRule.then.details.type.split(".").count-1]
            }
            catch {
    
            }
    
            try {
                $purposeType = $purposeType.split("/")[1]
            }
            catch {
    
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
    
            }
    
            try {
                if ($displayName.endswith("-")){
                    $displayName = $displayName.substring(0,$displayName.length-1)
                }
            }
            catch {
                
            }
    
            try {
                if ($displayName.length -gt 62){
                    $displayName = $displayName.substring(0,62)
                }
            }
            catch {
                
            }
    
            $policy = $jsonObject.PolicyRule | ConvertTo-Json -Depth 64
    
            $parameters = $jsonObject.Parameters | ConvertTo-Json -Depth 64
    
            foreach ($managementGroup in $managementGroups){
    
                $boolCreatePolicy = $false
                $boolCreatAssignment = $false
                $definition = ""
                $assignment = ""
    
                $nameGUID = (new-guid).toString().replace("-","").substring(0,23)
                
                if ($diagnosticSettingsType -eq "logAnalyticWorkspace"){
                    $policyParameters = @{
                        'logAnalytics' = $logAnalyticWorkspaceResourceId
                        #'profileName' = "setbypolicy"
                    }
                } elseif ($diagnosticSettingsType -eq "storageAccount"){
                    $policyParameters = @{
                        'storageAccount' = $storageAccountResourceId
                        #'profileName' = "setbypolicy"
                    }
                } # elseif ($diagnosticSettingsType -eq "eventHub"){
                #     $policyParameters = @{
                #         'eventHub' = $storageAccountResourceId
                #         'profileName' = ("setbyPolicy_" + $nameGUID)
                #     }
                # }
    
                try {
                    Write-Host "`tEvaluating if Policy exists." -ForegroundColor White
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
                    Write-Host "`tEvaluating if Policy Assignment exists." -ForegroundColor White
                    $assignment = Get-AzPolicyAssignment -PolicyDefinitionId $definition.PolicyDefinitionId -Scope $managementGroup.Id -ErrorAction Stop
                    
                }
                catch {
                    $boolCreatAssignment = $true
                }
    
                if($assignment){
                    Write-Host "`t`tPolicy Assignment exists. Moving on to next policy." -ForegroundColor Green
                }
                else {
                    $boolCreatAssignment = $true
                }
    
                if ($boolCreatAssignment){
                    try {
                        $assignment = New-AzPolicyAssignment -Name $nameGUID -DisplayName ($displayName + "-Assignment") -Location 'eastus' -Scope $managementGroup.Id -PolicyDefinition $definition -PolicyParameterObject $policyParameters -AssignIdentity
                        Write-Host ("`t`tAssigned Azure Policy: " + $nameGUID + "/ " + ($displayName + "-Assignment") + " to management group: " + $managementGroup.Name) -ForegroundColor Green
    
                    }
                    catch {
                        Write-Warning ("Failed to Assign Azure Policy: " + $nameGUID + "/ " + ($displayName + "-Assignment") + " to management group: " + $managementGroup.Name)
                    }
    
                    $role1DefinitionId = [GUID]($definition.properties.policyRule.then.details.roleDefinitionIds[0] -split "/")[4]
                    $role2DefinitionId = [GUID]($definition.properties.policyRule.then.details.roleDefinitionIds[1] -split "/")[4]
                    $objectID = [GUID]($assignment.Identity.principalId)
    
                    try {            
                        Start-Sleep -s 2            
                        $null = New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $objectID -RoleDefinitionId $role1DefinitionId -ErrorAction Stop                    }
                    catch {
                        Start-Sleep -s 8
                        $null = New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $objectID -RoleDefinitionId $role1DefinitionId -ErrorAction Stop
                    }
    
                    Write-Host ("`t`tAssigned Role Permissions for Account: " + $role1DefinitionId) -ForegroundColor Green
    
                    try {       
                        Start-Sleep -s 1                 
                        $null = New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $objectID -RoleDefinitionId $role2DefinitionId -ErrorAction Stop
                    }
                    catch {
                        Start-Sleep -s 4
                        $null = New-AzRoleAssignment -Scope $managementGroup.Id -ObjectId $objectID -RoleDefinitionId $role2DefinitionId -ErrorAction Stop
                    }
    
                    Write-Host ("`t`tAssigned Role Permissions for Account: " + $role2DefinitionId) -ForegroundColor Green
                }
            }
        } else {
            Write-Warning "Failed to collect policy from Github.com after two attempts. Validate access to internet and to github.com. Process will review where it left off and will resume when restrated. Exiting process."
            Break Script
        }
    }
}

Clear-Host

Write-Host "`nThis process will deploy Azure Policies that enable the delivery of diagnostic settings to a Log Analytic Workspace and archive them to a Storage Account.`n" -ForegroundColor Cyan

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

$policyTotal = 58


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
    $azContext = Get-AzContext
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

$boolTryAgain = $true
$boolTenantFound = $false
while (!$boolTenantFound) {

    if ($boolTryAgain){
        $userInputTenantId = Read-Host "Please enter Tenant Id"
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
        Set-AzContext -TenantId $tenant.Id
    }
    catch {
        Write-Warning "Unable to set Azure Context. Please verify access to context. Existing process."
        Break Script
    }
}

Write-Host ("`tConnected to " + $tenant.name + " with Tenant ID " + $tenant.Id) -ForegroundColor Green

[System.Collections.ArrayList]$userInputManagementGroupName = @()
[System.Collections.ArrayList]$managementGroups = @()

$boolTryAgain = $true

$boolMoreManagementGroups = $true
while ($boolMoreManagementGroups) {
    if ($boolTryAgain){
        $userInputManagementGroupName.Add((Read-Host "`nPlease enter Management Group")) | Out-Null
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
        Write-Warning "Unable to collect management group information. Please verify access to internet and permissions to resource. Existing process."
        Break Script
    }

    if ($managementGroupObject){
        $managementGroups.Add($managementGroupObject) | Out-Null
    } else {

    }
}

$boolDiagnsoticSettingsSelected = $false

$greenCheck = @{
    Object = [Char]8730
    ForegroundColor = 'Green'
    NoNewLine = $true
    }

$boolAddOption = $false

$boolDeployLogAnalyticWorkspaceSettings = $false
$boolDeployStorageAccountSettings = $false
#$boolDeployEventHubSettings = $false

do
 {

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

    if ($boolDeployLogAnalyticWorkspaceSettings -or $boolDeployStorageAccountSettings){
        Write-Color "4.  ", "Press ", "'4'", " or", " 'D(d)'", " to Complete Policy Selection" -Color Gray, White, Cyan, White, Cyan, White -LinesBefore 1

        $userInput = Read-Host "`nPlease select a menu option:"
    } else {
        $userInput = Read-Host "`nPlease select a policy to deploy:"
    }

    switch ($userInput.ToLower()) {
        "l" {
            $boolDeployLogAnalyticWorkspaceSettings = $true
        }
        "1" {
            $boolDeployLogAnalyticWorkspaceSettings = $true
        }
        "2" {
            $boolDeployStorageAccountSettings = $true
        }
        "s" {
            $boolDeployStorageAccountSettings = $true
        }
        # "3" {
        #     $boolDeployEventHubSettings = $true
        # }
        # "e" {
        #     $boolDeployEventHubSettings = $true
        # }
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
    
    $array = @('~', '!', '@', '#', '$', '%', '^', '&', '\(', '\)', '-', '.+', '=', '}', '{', '\\', '/', '|', ';', ',', ':', '<', '>', '\?', '"', '\*')
    $boolContainsSpecial = $false

    $userInputPrepend = Read-Host "`nEnter characters to prepend Azure Policy Display name [1-4 characters, e.g. 0001, TEST, or 11AB; NO special characters]"

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
                Write-Host "`tAzure Policies will start with '$userInputPrepend'" -ForegroundColor Green
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

    $boolLAWFound = $false
    while (!$boolLAWFound) {
        $userInputLAWName = Read-Host "`nPlease enter Log Analytics Workspace Name"

        $logAnalyticWorkspaceObject = Get-AzResource -name $userInputLAWName
        $logAnalyticWorkspaceResourceId = $logAnalyticWorkspaceObject.ResourceId

        if ($logAnalyticWorkspaceObject){
            $boolLAWFound = $true
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
    $userInputSAName = Read-Host "`nPlease enter Storage Account Name"

    $storageAccountObject = Get-AzResource -name $userInputSAName
    $storageAccountResourceId = $storageAccountObject.ResourceId


    if ($storageAccountObject){
        
    }
    else {
        Write-Warning "Unable to find Storage Account, please enter valid name or confirm your access to resource."

        $userInputTryAgain = Read-Host "`tDo you want to try again? [Y or Yes, N or No]"

        if (($userInputTryAgain.ToLower() -eq "n") -or ($userInputTryAgain.ToLower() -eq "no")){
            Exit 
        }
    }
}


if ($boolDeployLogAnalyticWorkspaceSettings ){

    Deploy-DiagnosticSettingsPolicies "logAnalyticWorkspace" 
}


if ($boolDeployStorageAccountSettings){

    Deploy-DiagnosticSettingsPolicies "storageAccount"
}



Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "false"

Write-Host "`nPolicy Deployment Complete." -ForegroundColor Green