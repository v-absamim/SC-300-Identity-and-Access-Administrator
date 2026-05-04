#Requires -Version 5.1
<#
Splits all uncommitted lab edits on branch `lab1-fixes` into one branch + PR per lab (Lab_00 .. Lab_28).
Strategy:
  1. Commit (locally) all current uncommitted changes onto branch `lab1-fixes` as a snapshot.
  2. For each lab, branch from master, restore only that lab's files from the snapshot, commit, push, open PR.
#>

$ErrorActionPreference = 'Stop'

# Ensure we're at repo root
Set-Location -LiteralPath $PSScriptRoot

# Upstream and fork (PRs go from fork branch -> upstream master)
$Upstream = 'MicrosoftLearning/SC-300-Identity-and-Access-Administrator'
$ForkOwner = 'v-absamim'

# Lab definitions: number (zero-padded), title, modified files, deleted files
$labs = @(
    @{ N='00'; Title='Lab Environment Setup';
       Modified=@('Instructions/Labs/Lab_00_SetUpLabResources.md');
       Deleted=@('Instructions/Labs/image.png','Instructions/Labs/image-1.png') },
    @{ N='01'; Title='Manage user roles';
       Modified=@('Instructions/Labs/Lab_01_ManageUserRoles.md'); Deleted=@() },
    @{ N='02'; Title='Working with tenant properties';
       Modified=@('Instructions/Labs/Lab_02_WorkingWithTenantProperties.md'); Deleted=@() },
    @{ N='03'; Title='Assigning licenses using group membership';
       Modified=@('Instructions/Labs/Lab_03_AssignLicensesToUsersByGroupMembershipAAD.md'); Deleted=@() },
    @{ N='04'; Title='Configure external collaboration settings';
       Modified=@('Instructions/Labs/Lab_04_ConfigureExternalCollaborationSettings.md'); Deleted=@() },
    @{ N='05'; Title='Add guest users to the directory';
       Modified=@('Instructions/Labs/Lab_05_AddGuestUsersToTheDirectory.md'); Deleted=@() },
    @{ N='06'; Title='Add a federated identity provider';
       Modified=@('Instructions/Labs/Lab_06_AddFederatedIdentityProvider.md'); Deleted=@() },
    @{ N='07'; Title='Add Hybrid Identity with Microsoft Entra Connect';
       Modified=@('Instructions/Labs/Lab_07_AddHybridIdentityWithAzureADConnect.md'); Deleted=@() },
    @{ N='08'; Title='Enable multi-factor authentication';
       Modified=@('Instructions/Labs/Lab_08_EnableAzureADMultiFactorAuthentication.md',
                  'Instructions/Labs/media/lp2-mod1-set-additional-mfa-settings.png');
       Deleted=@() },
    @{ N='09'; Title='Configure and deploy self-service password reset';
       Modified=@('Instructions/Labs/Lab_09_ConfigureAndDeploySelfServicePasswordReset.md'); Deleted=@() },
    @{ N='10'; Title='Microsoft Entra Authentication for Windows and Linux VMs';
       Modified=@('Instructions/Labs/Lab_10_AzureADAuthenticationForWindowsAndLinuxVM.md'); Deleted=@() },
    @{ N='11'; Title='Assign Azure resource roles in Privileged Identity Management';
       Modified=@('Instructions/Labs/Lab_11_AssignAzureResourceRolesInPrivilegedIdentityManagement.md'); Deleted=@() },
    @{ N='12'; Title='Manage Microsoft Entra smart lockout values';
       Modified=@('Instructions/Labs/Lab_12_ManageAzureADSmartLockoutValues.md'); Deleted=@() },
    @{ N='13'; Title='Implement and test a conditional access policy';
       Modified=@('Instructions/Labs/Lab_13_ImplementAndTestAConditionalAccessPolicy.md',
                  'Instructions/Labs/media/lp2-mod1-conditional-access-new-policy.png');
       Deleted=@() },
    @{ N='14'; Title='Enable sign-in and user risk policies';
       Modified=@('Instructions/Labs/Lab_14_EnableSignRiskPolicy.md'); Deleted=@() },
    @{ N='15'; Title='Configure a multi-factor authentication registration policy';
       Modified=@('Instructions/Labs/Lab_15_ConfigureAAD_MultiFactorAuthRegPolicy.md');
       Deleted=@('Instructions/Labs/media/lp2-mod4-browse-to-mfa-registration-policy.png') },
    @{ N='16'; Title='Using Azure Key Vault for Managed Identities';
       Modified=@('Instructions/Labs/Lab_16_UsingAzureKeyVaultForManagedIdentities.md'); Deleted=@() },
    @{ N='17'; Title='Defender for Cloud Apps application discovery and restrictions';
       Modified=@('Instructions/Labs/Lab_17_DefenderForCloudAppsDiscoveryAndRestrictions.md'); Deleted=@() },
    @{ N='18'; Title='Defender for Cloud Apps access and session policies';
       Modified=@('Instructions/Labs/Lab_18_DefenderForCloudAppsAccessPolicies.md'); Deleted=@() },
    @{ N='19'; Title='Register an application';
       Modified=@('Instructions/Labs/Lab_19_RegisterAnApplication.md',
                  'Instructions/Labs/media/configure-platforms.png',
                  'Instructions/Labs/media/lp3-mod1-new-custom-role.png',
                  'Instructions/Labs/media/portal-02-expose-api.png');
       Deleted=@() },
    @{ N='20'; Title='Implement access management for apps';
       Modified=@('Instructions/Labs/Lab_20_ImplementAccessManagementForApps.md'); Deleted=@() },
    @{ N='21'; Title='Grant tenant-wide admin consent to an application';
       Modified=@('Instructions/Labs/Lab_21_GrantTenantWideAdminConsentToAnApplication.md'); Deleted=@() },
    @{ N='22'; Title='Create and manage a catalog of resources in Microsoft Entra entitlement management';
       Modified=@('Instructions/Labs/Lab_22_CreateAndManageACatalogOfResourcesInAADEntitlementManagement.md',
                  'Instructions/Labs/media/lp4-mod1-identity-governance-new-catalog.png');
       Deleted=@() },
    @{ N='23'; Title='Add terms of use and acceptance reporting';
       Modified=@('Instructions/Labs/Lab_23_AddTermsOfUseAcceptanceReporting.md'); Deleted=@() },
    @{ N='24'; Title='Manage the lifecycle of external users in Microsoft Entra Identity Governance';
       Modified=@('Instructions/Labs/Lab_24_ManageTheLifecycleOfExternalUsersInAADIdentityGovernanceSettings .md');
       Deleted=@() },
    @{ N='25'; Title='Creating Access Reviews for internal and external users';
       Modified=@('Instructions/Labs/Lab_25_CreatingAccessReviewsForUsers.md'); Deleted=@() },
    @{ N='26'; Title='Configure Privileged Identity Management for Microsoft Entra roles';
       Modified=@('Instructions/Labs/Lab_26_ConfigurePrivilegedIdentityManagementForAADRoles.md'); Deleted=@() },
    @{ N='27'; Title='Microsoft Sentinel Kusto Queries for Microsoft Entra data sources';
       Modified=@('Instructions/Labs/Lab_27_MicrosoftSentinelKustoQueries.md'); Deleted=@() },
    @{ N='28'; Title='Monitor and manage security posture with Identity Secure Score';
       Modified=@('Instructions/Labs/Lab_28_MonitorIdentitySecureScore.md'); Deleted=@() }
)

function Invoke-Git {
    # Use a non-conflicting parameter name and stop PowerShell from interpreting dashed args.
    $gitArgs = @($args)
    & git.exe @gitArgs
    if ($LASTEXITCODE -ne 0) { throw "git $($gitArgs -join ' ') failed (exit $LASTEXITCODE)" }
}

# 1. Make sure we're on lab1-fixes and commit all pending edits as a snapshot
Write-Host "==> Committing snapshot on lab1-fixes" -ForegroundColor Cyan
Invoke-Git checkout lab1-fixes
Invoke-Git add -A
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "Nothing to commit on lab1-fixes (already snapshot?)" -ForegroundColor Yellow
} else {
    Invoke-Git commit -m "Snapshot: all lab fixes (to be split into per-lab PRs)"
}
$snapshotSha = (git rev-parse HEAD).Trim()
Write-Host "Snapshot SHA: $snapshotSha" -ForegroundColor Green

# Make sure master is up to date
Invoke-Git fetch origin
Invoke-Git checkout master
Invoke-Git pull --ff-only origin master

foreach ($lab in $labs) {
    $n = $lab.N
    $title = $lab.Title
    $branch = "lab$n-fixes"
    $msg = "Fix Lab $n`: $title"
    Write-Host "`n==> Processing $branch" -ForegroundColor Cyan

    # Create branch from current master
    Invoke-Git checkout master
    # Delete branch locally if exists (idempotent re-runs)
    git rev-parse --verify --quiet "refs/heads/$branch" *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Branch $branch exists locally; deleting." -ForegroundColor Yellow
        Invoke-Git branch -D $branch
    }
    Invoke-Git checkout -b $branch

    # Restore modified files from snapshot
    foreach ($f in $lab.Modified) {
        Invoke-Git checkout $snapshotSha -- $f
    }
    # Stage deletions
    foreach ($f in $lab.Deleted) {
        if (Test-Path -LiteralPath $f) {
            Invoke-Git rm -- $f
        } else {
            # Already gone in working tree; ensure index reflects deletion vs master
            Invoke-Git rm --cached -- $f 2>$null
        }
    }

    # Commit
    $cached = git diff --cached --name-only
    if ([string]::IsNullOrWhiteSpace($cached)) {
        Write-Host "No staged changes for Lab $n; skipping." -ForegroundColor Yellow
        continue
    }
    Invoke-Git commit -m $msg

    # Push (force, since re-runs may recreate the local branch)
    Invoke-Git push -u origin $branch --force

    # Create PR against upstream (skip if one already exists for this fork branch)
    $headRef = "${ForkOwner}:${branch}"
    $existingPr = gh pr list --repo $Upstream --head $headRef --state open --json number --jq '.[0].number' 2>$null
    if ([string]::IsNullOrWhiteSpace($existingPr)) {
        $body = "Per-lab fix split out from ``lab1-fixes``.`n`nScope: Lab $n - $title."
        gh pr create --repo $Upstream --base master --head $headRef --title $msg --body $body
        if ($LASTEXITCODE -ne 0) { throw "gh pr create failed for $branch" }
    } else {
        Write-Host "PR #$existingPr already open for $branch; skipping create." -ForegroundColor Yellow
    }
}

# Return to lab1-fixes
Invoke-Git checkout lab1-fixes
Write-Host "`nDone. All per-lab branches and PRs created." -ForegroundColor Green
