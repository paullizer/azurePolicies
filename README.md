# Customized Azure Policies
Flexibility to deploy Azure Policies outside the Dev Ops process.

This initial configuration of Diagnostic Settings policies is a modification of the Enterprise Scale Diagnostic Settings. The Enterprise Scale policies only deploy Log Analytic Workspace configuration for Diagnostic Settings. This set of Diagnostic Settings policies also configure Diagnostic Settings to archive logs and metrics to a Storage Account.

## Requirements
1. Tenant a minimum of a management group.
2. User has contributor or higher permissions to the management group.
3. Log Analytic Workspace
4. Storage Account

## Process
1. Azure PowerShell module installation (if necessary)
2. Azure Tenant connection
3. Management Group(s) selection
4. Log Analytic Workspace 
5. Storage Account
6. Creates 59 Policy Definition per management group
7. Assigns 59 Policy Definitions per management group

## Future Updates
1. Create an Initiative and assign using Initiative
2. Use Initiative parameters for user input instead of hard coded requests for Log Analytive Workspace (LAW) or Storage Account (SA) Name
3. Seperate LAW policies from SA for two Initiatives to provide greater flexibility
4. Include new set of policies for sending logs and metrics to Event Hub
5. Expand beyond diagnostic settings

## Execution
Deploy-DiagnosticSettings.ps1

## Screen Shots
Example of the deployment process
![image](https://user-images.githubusercontent.com/34814295/112237903-007a8580-8c1a-11eb-8cba-08e77657d524.png)

Example of the Policy Definition viewed in Azure Portal
![image](https://user-images.githubusercontent.com/34814295/112238093-5c450e80-8c1a-11eb-95e9-3672ed3311b6.png)

Example of Policy Assignment viewed in Azure Portal
![image](https://user-images.githubusercontent.com/34814295/112238115-67983a00-8c1a-11eb-94c1-4cf96151da17.png)


