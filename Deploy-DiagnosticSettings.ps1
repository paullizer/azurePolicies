function Deploy-DiagnosticSettings {

    Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

    Write-Host

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

    $boolTenantFound = $false
    while (!$boolTenantFound) {
        $userInputTenantId = Read-Host "Please enter Tenant Id"

        $tenant = Get-AzTenant $userInputTenantId
        
        if ($tenant){
            $boolTenantFound = $true
        }
        else {
            Write-Warning "Unable to find Tenant, please enter valid name or confirm your access to resource."

            $userInputTryAgain = Read-Host "Do you want to try again? [Y or Yes, N or No]"

            if (($userInputTryAgain.ToLower() -eq "n") -or ($userInputTryAgain.ToLower() -eq "no")){
                Break Script 
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

    Write-Host ("Connected to " + $tenant.name + " with Tenant ID " + $tenant.Id) -ForegroundColor Green

    [System.Collections.ArrayList]$userInputManagementGroupName = @()
    [System.Collections.ArrayList]$userInputManagementGroupId = @()
    
    $boolMoreManagementGroups = $true
    while ($boolMoreManagementGroups) {
        $userInputManagementGroupName.Add((Read-Host "Please enter Management Group")) | Out-Null
        $userInputAddAnotherMG = Read-Host "Do you want to enter another Management Group? [Y or Yes, N or No]"
        if (($userInputAddAnotherMG.ToLower() -eq "n") -or ($userInputAddAnotherMG.ToLower() -eq "no")){
            $boolMoreManagementGroups = $false 
        }
    }

    foreach ($managementGroupName in $userInputManagementGroupName){
        try{
            $managementGroup = Get-AzManagementGroup $managementGroupName
        }
        catch {
            Write-Warning "Unable to collect management group information. Please verify access to internet and permissions to resource. Existing process."
            Break Script
        }

        if ($managementGroup){
            $userInputManagementGroupId.Add($managementGroup.Id) | Out-Null
        }
        else {
            $userInputManagementGroupId.Add($mgTest.Id) | Out-Null
        }
    }

    $boolLAWFound = $false
    while (!$boolLAWFound) {
        $userInputLAWName = Read-Host "Please enter Log Analytics Workspace Name"

        $logAnalyticWorkspaceObject = Get-AzResource -name $userInputLAWName
        $logAnalyticWorkspaceResourceId = $logAnalyticWorkspaceObject.ResourceId

        if ($logAnalyticWorkspaceObject){
            $boolLAWFound = $true
        }
        else {
            Write-Host "Unable to find Log Analytics Workspace, please enter valid name or confirm your access to resource."

            $userInputTryAgain = Read-Host "Do you want to try again? [Y or Yes, N or No]"

            if (($userInputTryAgain.ToLower() -eq "n") -or ($userInputTryAgain.ToLower() -eq "no")){
                Exit 
            }
        }
    }

    $boolSAFound = $false
    while (!$boolSAFound) {
        $userInputSAName = Read-Host "Please enter Storage Account Name"

        $storageAccountObject = Get-AzResource -name $userInputSAName
        $storageAccountResourceId = $storageAccountObject.ResourceId

        if ($storageAccountObject){
            $boolSAFound = $true
        }
        else {
            Write-Host "Unable to find Storage Account, please enter valid name or confirm your access to resource."

            $userInputTryAgain = Read-Host "Do you want to try again? [Y or Yes, N or No]"

            if (($userInputTryAgain.ToLower() -eq "n") -or ($userInputTryAgain.ToLower() -eq "no")){
                Exit 
            }
        }
    }

    Write-Host ("Processing JSON policy.") -ForegroundColor White

    for ($x = 1; $x -le 3; $x++){

        $jsonObject = ""

        $jsonPath = ("https://raw.githubusercontent.com/paullizer/azurePolicies/main/diagnosticSettings/storageAccount/" + $x +".json")

        try {

            $jsonWeb = Invoke-WebRequest $jsonPath
        

        }
        catch{
            Write-Warning "Failed to pull policy from Github.com. Waiting 10 seconds to attempt one more time."

            Start-Sleep -s 10

            $jsonWeb = Invoke-WebRequest $jsonPath

        }

        $jsonObject = $jsonWeb.Content | ConvertFrom-Json

        if ($jsonObject){

            $resourceType = ($jsonObject.policyRule.if.equals).split(".")[($jsonObject.policyRule.if.equals).split(".").count-1]

            $purposeType = $jsonObject.policyRule.then.details.type.split(".")[$jsonObject.policyRule.then.details.type.split(".").count-1]
            $purposeType = $purposeType.split("/")[1]


            $displayName = "TEST-" + $purposeType + "-"

            if ($resourceType.contains("/")) {
                foreach ($value in ($resourceType.split("/"))){
                    $displayName += $value + "-"
                }
            }

            if ($displayName.endswith("-")){
                $displayName = $displayName.substring(0,$displayName.length-1)
            }

            if ($displayName.length -gt 62){
                $displayName = $displayName.substring(0,62)
            }

           
            $policy = $jsonObject.PolicyRule | ConvertTo-Json -Depth 64

            $parameters = $jsonObject.Parameters | ConvertTo-Json -Depth 64

        
            foreach ($managementGroupName in $userInputManagementGroupName){

                $boolCreatePolicy = $false

                try {
                    Write-Host "`tEvaluating if Policy exists." -ForegroundColor White
                    $definition = Get-AzPolicyDefinition -Name $displayName ManagementGroupName $managementGroupName -ErrorAction Stop
                    Write-Host "`t`tPolicy exists. Moving to assignment task." -ForegroundColor Green
                }
                catch {
                    $boolCreatePolicy = $true
                }

                if ($boolCreatePolicy){
                    Write-Host "`tCreating Policy." -ForegroundColor White
                    try {
                        $definition = New-AzPolicyDefinition -Name $displayName -Policy $policy -Parameter $parameters -ManagementGroupName $managementGroupName  -ErrorAction Stop
                        Write-Host ("`t`tCreated Azure Policy: " + $displayName + ", for management group: " + $managementGroupName) -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "Failed to create policy. Exiting process."
                        Break Script
                    }
                    
                }
            }
        
            foreach ($managementGroupId in $userInputManagementGroupId){

                $nameGUID = (new-guid).toString().replace("-","").substring(0,23)

                $profileName = "setbyPolicy_" + $nameGUID

                $policyParameters = @{
                    'logAnalytics' = $logAnalyticWorkspaceResourceId
                    'storageAccount' = $storageAccountResourceId
                    'profileName' = $profileName
                }
                
                $boolCreatAssignment = $false

                try {
                    Write-Host "`tEvaluating if Policy Assignment exists." -ForegroundColor White
                    $definition = Get-AzPolicyAssignment -Name $nameGUID -Scope $managementGroupId -ErrorAction Stop
                    Write-Host "`t`tPolicy Assignment exists. Moving on to next policy." -ForegroundColor Green
                }
                catch {
                    $boolCreatAssignment = $true
                }

                if ($boolCreatAssignment){
                    $assignment = New-AzPolicyAssignment -Name $nameGUID -DisplayName ($displayName + "-Assignment") -Location 'eastus' -Scope $managementGroupId -PolicyDefinition $definition -PolicyParameterObject $policyParameters -AssignIdentity  -ErrorAction Stop
                    Write-Host ("`tAssigned Azure Policy: " + $nameGUID + "/ " + ($displayName + "-Assignment") + ", for management group: " + $managementGroupName) -ForegroundColor Green

                    $role1DefinitionId = [GUID]($definition.properties.policyRule.then.details.roleDefinitionIds[0] -split "/")[4]
                    $role2DefinitionId = [GUID]($definition.properties.policyRule.then.details.roleDefinitionIds[1] -split "/")[4]
                    $objectID = [GUID]($assignment.Identity.principalId)

                    Start-Sleep -s 10
                    New-AzRoleAssignment -Scope $managementGroupId -ObjectId $objectID -RoleDefinitionId $role1DefinitionId | Out-Null
                    Start-Sleep -s 2
                    New-AzRoleAssignment -Scope $managementGroupId -ObjectId $objectID -RoleDefinitionId $role2DefinitionId | Out-Null
                    
                    Write-Host ("`t`tAssigned Role Permissions to Azure Policy Assignment.") -ForegroundColor Green
                }
            }
        }
        else {
            Write-Warning "Failed to collect policy from Github.com after two attempts. Validate access to internet and to github.com. Process will review where it left off and will resume when restrated. Exiting process."
            Break Script
        }
    }

    Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "false"
}