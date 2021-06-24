# PowerShell Deployed Azure Policies
Flexibility to deploy Azure Policies outside the Dev Ops process or the Enterprise Scale process.

The Enterprise Scale policies only deploy Log Analytic Workspace configuration for Diagnostic Settings. This set of Diagnostic Settings policies also configure Diagnostic Settings to archive logs and metrics to a Storage Account.

## Goals
- Deploy all _Enterprise Scale Policies_ via PowerShell to:
   - Management group(s) 
   - Subscription(s)
- Deploy _customized policies_ via PowerShell to:
   - Management group(s) 
   - Subscription(s)

## Policies Currently Supported
1. Diagnostic Settings
   1. Log Analytic Workspace (same as Enterprise Scale)
   2. Storage Account
   3. Event Hub (coming soon)

## Requirements
1. Tenant with at least one management group or subscription.
2. User has contributor or higher permissions to the management group or subscription where the policy is deployed.
3. User has contributor or higher permissions to the management group or subscription where the log analytic workspace, storage account, or event hub is deployed.
4. Log Analytic Workspace for that use case.
5. Storage Account for that use case.

## Process
1. Validates Azure PowerShell module installation.
   1. Installs if missing.
2. Validates Azure Tenant connection.
   1. If not connected, connects to user provided Tenant Id.
3. Requests which location to deploy policies (management groups and/or subscriptions).
4. Requests Management Group(s) selection.
5. Requests Subscriptions(s) selection.
6. User selects which diagnostic settings type to deploy (LAW, SA, or both).
7. Requests if user wants to perform compliance and remediation.
   1. If selected, compliance scan and remediation tasks will occur following deployment of all policies.
8. Validates Microsot.PolicyInsights resource provider is registered.
   1. If not registered, registers Microsot.PolicyInsights.
9. Validates Microsot.OperationalInsights resource provider is registered.
   1. If not registered, registers Microsot.OperationalInsights.
10. If selected, requests Log Analytic Workspace name for sending logs to the LAW.
11. If selected, requests Storage Account name for archiving logs to the SA.
12. Creates 59 Policy Definition per management group per diagnostic settings  type (LAW and/or SA).
13. Assigns each Policy Definitions per management group and/or subscription.
14. Applies Role Permissions for each Policy assignment.
    1. If Log Analytic Workspace or Storage Account is in a subscription different from where the policy is assigned
       1. Then the script will assign an additional role with permissions to the subscription where the LAW or SA resides
    2. If Log Analytic Workspace or Storage Account is in a management group different from where the policy is assigned
       1. Then the script will determine if the subscription where the LAW or SA resides is in the heirarchy of where the policy is assigned
          1. If it is not, then the script will assign an additional role with permissions to the subscription where the LAW or SA resides
15. [Optional] Perform Compliance scan.
16. [Optional] Creates Remediation Task for each non-compliant Policy.

## Future Updates
1. Include new set of policies for sending logs and metrics to Event Hub.
3. Create an Initiative and assign using Initiative.
3. Expand beyond diagnostic settings.

## Execution
### Diagnostic Settings Policy Types
Deploy-DiagnosticSettings.ps1

## Screen Shots
### Example of the deployment process
![2021-06-24_16-34-01](https://user-images.githubusercontent.com/34814295/123329267-a041fb00-d50a-11eb-8b39-55deb6fa1d1b.png)

### Example of the Compliance Scan and Remediation Task

![2021-06-24_16-35-51](https://user-images.githubusercontent.com/34814295/123329343-b2239e00-d50a-11eb-8a04-cc4156207d35.png)

### Example of the Policy Definition viewed in Azure Portal

![image](https://user-images.githubusercontent.com/34814295/112238093-5c450e80-8c1a-11eb-95e9-3672ed3311b6.png)

### Example of Policy Assignment viewed in Azure Portal
![image](https://user-images.githubusercontent.com/34814295/112238115-67983a00-8c1a-11eb-94c1-4cf96151da17.png)

### Example of the Policy in Action
Each diagnostic settings type is deployed on its own, the name of the setting is based on the Policy Assignment Id to simplify troubleshooting and tracking
![image](https://user-images.githubusercontent.com/34814295/112683012-554f1380-8e47-11eb-83b7-56303d035fa5.png)

