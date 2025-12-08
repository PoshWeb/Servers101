$commandsPath = Join-Path $PSScriptRoot Commands
foreach ($file in Get-ChildItem -File -Recurse -Path $commandsPath) {
    if ($file.Extension -ne '.ps1') { continue }
    if ($file.Name -like '*.*.ps1') { continue }
    . $file.FullName
}