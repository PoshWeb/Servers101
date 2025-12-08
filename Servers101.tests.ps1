<#
.SYNOPSIS
    Servers 101 Tests
.DESCRIPTION
    Tests for the Server 101 module.
#>

$scriptName =  $MyInvocation.MyCommand.Name
$scriptFileContent = Get-Content -Raw $MyInvocation.MyCommand.ScriptBlock.File

describe Servers101 {
    it 'Gets a list of demo servers' {
        Servers101
    }

    it 'Can get a specific demo server' {
        Servers101 -Name Server101
    }

    it 'Has a working file server' {
        $job = . (Servers101 -Name Server101) -RootDirectory $pwd
        Write-Warning "$($job.Url)$($scriptName)"
        $myResponse = Invoke-RestMethod -Uri "$($job.Url)$($scriptName)"
        "$myResponse".Trim() | Should -Be "$scriptFileContent".Trim()
        $job.HttpListener.Stop()
    }

}
