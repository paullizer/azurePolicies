# Customized Azure Policies
Flexibility to deploy Azure Policies outside the Dev Ops process.

This initial configuration of Diagnostic Settings policies is a modification of the Enterprise Scale Diagnostic Settings. The Enterprise Scale policies only deploy Log Analytic Workspace configuration for Diagnostic Settings. This set of Diagnostic Settings policies also configure Diagnostic Settings to archive logs and metrics to a Storage Account.

## Requirements
1. Tenant with at least one management group.
2. User has contributor or higher permissions to the management group.
3. Log Analytic Workspace for that use case
4. Storage Account for that use case

## Process
1. Validates Azure PowerShell module installation
   1. Installs if missing
2. Validates Azure Tenant connection
   1. Connects if not connected and sets to user provided Tenant Id
3. Requests Management Group(s) selection
4. User selects which diagnostic settings type to deploy (LAW, SA, or both)
5. If selected, requests Log Analytic Workspace name for sending logs to the LAW
6. If selected, requests Storage Account name for archiving logs to the SA
7. Creates 58 Policy Definition per management group per diagnostic settings  type (LAW and/or SA)
8. Assigns each Policy Definitions per management group
9. Applies Role Permissions for each Policy assignment

## Future Updates
1. Include new set of policies for sending logs and metrics to Event Hub
5. Expand beyond diagnostic settings
3. Create an Initiative and assign using Initiative

## Execution
Deploy-DiagnosticSettings.ps1

## Screen Shots
Example of the deployment process
![image](https://user-images.githubusercontent.com/34814295/112682854-1325d200-8e47-11eb-9372-2cbc565d18eb.png)

Example of the Policy Definition viewed in Azure Portal
![image](https://user-images.githubusercontent.com/34814295/112238093-5c450e80-8c1a-11eb-95e9-3672ed3311b6.png)

Example of Policy Assignment viewed in Azure Portal
![image](https://user-images.githubusercontent.com/34814295/112238115-67983a00-8c1a-11eb-94c1-4cf96151da17.png)

Example of the Policy in Action
Each diagnostic settings type is deployed on its own, the name of the setting is based on the Policy Assignment Id to simplify troubleshooting and tracking
![image](https://user-images.githubusercontent.com/34814295/112683012-554f1380-8e47-11eb-83b7-56303d035fa5.png)


