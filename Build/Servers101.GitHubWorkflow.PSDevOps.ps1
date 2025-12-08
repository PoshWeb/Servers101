#requires -Module PSDevOps
Import-BuildStep -SourcePath (
    Join-Path $PSScriptRoot 'GitHub'
) -BuildSystem GitHubWorkflow

Push-Location ($PSScriptRoot | Split-Path)

New-GitHubWorkflow -Name "Build Module" -On Push,
    PullRequest, 
    Demand -Job  TestPowerShellOnLinux, TagReleaseAndPublish -OutputPath ./.github/workflows/BuildServers101.yml

Pop-Location