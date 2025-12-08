function Get-Servers101
{
    <#
    .SYNOPSIS
        Servers101
    .DESCRIPTION
        Gets the list of example servers included in Servers101.

        Each server is a self-contained PowerShell script.
    .EXAMPLE
        Get-Servers101
    .EXAMPLE
        Servers101
    #>
    [Alias('Servers101')]
    param(
    # The name of the server.  If no name is provided, all servers will be returned.
    [SupportsWildcards()]
    [string]
    $Name
    )

    begin {
        $myModuleRoot = $PSScriptRoot | Split-Path
        Update-TypeData -TypeName Servers101 -DefaultDisplayPropertySet Name,
            Synopsis, Description -Force
    }
    process {   
        Get-ChildItem -File -Path $myModuleRoot -Recurse |
            Where-Object {
                $_.Name -match 'server?[^\.]{0,}\.ps1$' -and 
                $_.Name -notmatch '-Server' -and (
                    (-not $Name) -or ($_.Name -like "$name*")
                )
            } |            
            ForEach-Object {
                $file = $_
                $help = Get-Help -Name $file.FullName -ErrorAction Ignore
                $file.pstypenames.clear()
                $file.pstypenames.insert(0,'Servers101')
                $file |                    
                    Add-Member NoteProperty Synopsis $help.Synopsis -Force -PassThru |
                    Add-Member NoteProperty Description (
                        $help.Description.text -join [Environment]::NewLine
                    ) -Force -PassThru
            }
    }   
}