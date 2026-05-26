#Requires -Version 5.1
<#
Updates per-lab PRs with latest changes on `lab1-fixes`.
- For labs whose PR is still OPEN: update existing labNN-fixes branch and push (PR updates automatically).
- For Lab 28 (PR already merged): create new branch lab28-fixes-v2 and open a new PR.
- Skips labs that have no changes in the current snapshot.
#>

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$Upstream  = 'MicrosoftLearning/SC-300-Identity-and-Access-Administrator'
$ForkOwner = 'v-absamim'

# Map: lab number => @{ Branch, Title, Files (modified), Deleted, NewPr (bool) }
$labs = @(
    @{ N='01'; Branch='lab01-fixes'; Title='Manage user roles';
       Files=@('Instructions/Labs/Lab_01_ManageUserRoles.md'); Deleted=@(); NewPr=$false },
    @{ N='02'; Branch='lab02-fixes'; Title='Working with tenant properties';
       Files=@('Instructions/Labs/Lab_02_WorkingWithTenantProperties.md'); Deleted=@(); NewPr=$false },
    @{ N='03'; Branch='lab03-fixes'; Title='Assigning licenses using group membership';
       Files=@('Instructions/Labs/Lab_03_AssignLicensesToUsersByGroupMembershipAAD.md'); Deleted=@(); NewPr=$false },
    @{ N='04'; Branch='lab04-fixes'; Title='Configure external collaboration settings';
       Files=@('Instructions/Labs/Lab_04_ConfigureExternalCollaborationSettings.md'); Deleted=@(); NewPr=$false },
    @{ N='05'; Branch='lab05-fixes'; Title='Add guest users to the directory';
       Files=@('Instructions/Labs/Lab_05_AddGuestUsersToTheDirectory.md'); Deleted=@(); NewPr=$false },
    @{ N='06'; Branch='lab06-fixes'; Title='Add a federated identity provider';
       Files=@('Instructions/Labs/Lab_06_AddFederatedIdentityProvider.md'); Deleted=@(); NewPr=$false },
    @{ N='08'; Branch='lab08-fixes'; Title='Enable multi-factor authentication';
       Files=@('Instructions/Labs/Lab_08_EnableAzureADMultiFactorAuthentication.md',
               'Instructions/Labs/media/lp2-mod1-conditional-access-new-policy-complete.png');
       Deleted=@(); NewPr=$false },
    @{ N='09'; Branch='lab09-fixes'; Title='Configure and deploy self-service password reset';
       Files=@('Instructions/Labs/Lab_09_ConfigureAndDeploySelfServicePasswordReset.md'); Deleted=@(); NewPr=$false },
    @{ N='11'; Branch='lab11-fixes'; Title='Assign Azure resource roles in Privileged Identity Management';
       Files=@('Instructions/Labs/Lab_11_AssignAzureResourceRolesInPrivilegedIdentityManagement.md'); Deleted=@(); NewPr=$false },
    @{ N='12'; Branch='lab12-fixes'; Title='Manage Microsoft Entra smart lockout values';
       Files=@('Instructions/Labs/Lab_12_ManageAzureADSmartLockoutValues.md'); Deleted=@(); NewPr=$false },
    @{ N='13'; Branch='lab13-fixes'; Title='Implement and test a conditional access policy';
       Files=@('Instructions/Labs/Lab_13_ImplementAndTestAConditionalAccessPolicy.md'); Deleted=@(); NewPr=$false },
    @{ N='14'; Branch='lab14-fixes'; Title='Enable sign-in and user risk policies';
       Files=@('Instructions/Labs/Lab_14_EnableSignRiskPolicy.md'); Deleted=@(); NewPr=$false },
    @{ N='15'; Branch='lab15-fixes'; Title='Configure a multi-factor authentication registration policy';
       Files=@('Instructions/Labs/Lab_15_ConfigureAAD_MultiFactorAuthRegPolicy.md'); Deleted=@(); NewPr=$false },
    @{ N='17'; Branch='lab17-fixes'; Title='Defender for Cloud Apps application discovery and restrictions';
       Files=@('Instructions/Labs/Lab_17_DefenderForCloudAppsDiscoveryAndRestrictions.md'); Deleted=@(); NewPr=$false },
    @{ N='18'; Branch='lab18-fixes'; Title='Defender for Cloud Apps access and session policies';
       Files=@('Instructions/Labs/Lab_18_DefenderForCloudAppsAccessPolicies.md'); Deleted=@(); NewPr=$false },
    @{ N='19'; Branch='lab19-fixes'; Title='Register an application';
       Files=@('Instructions/Labs/Lab_19_RegisterAnApplication.md'); Deleted=@(); NewPr=$false },
    @{ N='20'; Branch='lab20-fixes'; Title='Implement access management for apps';
       Files=@('Instructions/Labs/Lab_20_ImplementAccessManagementForApps.md'); Deleted=@(); NewPr=$false },
    @{ N='21'; Branch='lab21-fixes'; Title='Grant tenant-wide admin consent to an application';
       Files=@('Instructions/Labs/Lab_21_GrantTenantWideAdminConsentToAnApplication.md'); Deleted=@(); NewPr=$false },
    @{ N='22'; Branch='lab22-fixes'; Title='Create and manage a catalog of resources in Microsoft Entra entitlement management';
       Files=@('Instructions/Labs/Lab_22_CreateAndManageACatalogOfResourcesInAADEntitlementManagement.md'); Deleted=@(); NewPr=$false },
    @{ N='23'; Branch='lab23-fixes'; Title='Add terms of use and acceptance reporting';
       Files=@('Instructions/Labs/Lab_23_AddTermsOfUseAcceptanceReporting.md'); Deleted=@(); NewPr=$false },
    @{ N='24'; Branch='lab24-fixes'; Title='Manage the lifecycle of external users in Microsoft Entra Identity Governance';
       Files=@('Instructions/Labs/Lab_24_ManageTheLifecycleOfExternalUsersInAADIdentityGovernanceSettings .md',
               'Instructions/Labs/media/lp4-mod1-manage-lifcycle-of-ext-users.png');
       Deleted=@(); NewPr=$false },
    @{ N='25'; Branch='lab25-fixes'; Title='Creating Access Reviews for internal and external users';
       Files=@('Instructions/Labs/Lab_25_CreatingAccessReviewsForUsers.md'); Deleted=@(); NewPr=$false },
    @{ N='26'; Branch='lab26-fixes'; Title='Configure Privileged Identity Management for Microsoft Entra roles';
       Files=@('Instructions/Labs/Lab_26_ConfigurePrivilegedIdentityManagementForAADRoles.md'); Deleted=@(); NewPr=$false },
    @{ N='28'; Branch='lab28-fixes-v2'; Title='Monitor and manage security posture with Identity Secure Score';
       Files=@('Instructions/Labs/Lab_28_MonitorIdentitySecureScore.md'); Deleted=@(); NewPr=$true }
)

function Invoke-Git {
    $gitArgs = @($args)
    & git.exe @gitArgs
    if ($LASTEXITCODE -ne 0) { throw "git $($gitArgs -join ' ') failed (exit $LASTEXITCODE)" }
}

# 1. Snapshot current uncommitted changes on lab1-fixes
Write-Host "==> Snapshotting lab1-fixes" -ForegroundColor Cyan
Invoke-Git checkout lab1-fixes
Invoke-Git add -A
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "Working tree clean; using current HEAD as snapshot." -ForegroundColor Yellow
} else {
    Invoke-Git commit -m "Snapshot: latest per-lab updates"
}
$snapshotSha = (git rev-parse HEAD).Trim()
Write-Host "Snapshot SHA: $snapshotSha" -ForegroundColor Green

Invoke-Git fetch origin
Invoke-Git checkout master
Invoke-Git pull --ff-only origin master

$summary = @()

foreach ($lab in $labs) {
    $n = $lab.N; $branch = $lab.Branch; $title = $lab.Title
    $msg = "Fix Lab $n`: $title"
    Write-Host "`n==> Lab $n -> $branch" -ForegroundColor Cyan

    Invoke-Git checkout master

    # Local branch handling
    git rev-parse --verify --quiet "refs/heads/$branch" *> $null
    $hasLocal = ($LASTEXITCODE -eq 0)
    # Remote branch handling
    git ls-remote --exit-code --heads origin $branch *> $null
    $hasRemote = ($LASTEXITCODE -eq 0)

    if ($lab.NewPr) {
        # Create fresh branch from master
        if ($hasLocal) { Invoke-Git branch -D $branch }
        Invoke-Git checkout -b $branch
    } else {
        if ($hasRemote) {
            if ($hasLocal) { Invoke-Git branch -D $branch }
            Invoke-Git checkout -b $branch "origin/$branch"
        } else {
            throw "Expected remote branch origin/$branch to exist for Lab $n"
        }
    }

    # Apply files from snapshot
    foreach ($f in $lab.Files) {
        Invoke-Git checkout $snapshotSha -- $f
    }
    foreach ($f in $lab.Deleted) {
        if (Test-Path -LiteralPath $f) { Invoke-Git rm -- $f }
    }

    # Stage and check diff vs HEAD of branch
    Invoke-Git add -A
    $cached = git diff --cached --name-only
    if ([string]::IsNullOrWhiteSpace($cached)) {
        Write-Host "No changes for Lab $n vs $branch HEAD; skipping." -ForegroundColor Yellow
        $summary += [pscustomobject]@{ Lab=$n; Branch=$branch; Action='no-op' }
        continue
    }
    Invoke-Git commit -m $msg
    Invoke-Git push -u origin $branch

    if ($lab.NewPr) {
        $headRef = "${ForkOwner}:${branch}"
        $body = "Per-lab fix split out from ``lab1-fixes``.`n`nScope: Lab $n - $title."
        gh pr create --repo $Upstream --base master --head $headRef --title $msg --body $body
        if ($LASTEXITCODE -ne 0) { throw "gh pr create failed for $branch" }
        $summary += [pscustomobject]@{ Lab=$n; Branch=$branch; Action='new-PR' }
    } else {
        $summary += [pscustomobject]@{ Lab=$n; Branch=$branch; Action='updated' }
    }
}

Invoke-Git checkout lab1-fixes
Write-Host "`n==== Summary ====" -ForegroundColor Green
$summary | Format-Table -AutoSize
