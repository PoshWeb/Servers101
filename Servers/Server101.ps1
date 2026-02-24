<#
.SYNOPSIS
    Server 101
.DESCRIPTION
    Server 101: A file server in 101 lines of pure PowerShell.
.EXAMPLE
    ./Server101.ps1 ($pwd | Split-Path)
#>
param(
# The Root Directory
[Alias('RootDirectory')][string]$RootPath =
    $(if ($PSScriptRoot) {$PSScriptRoot } else { $pwd }),

# The rootUrl of the server.  By default, a random loopback address.
[string]$RootUrl="http://127.0.0.1:$(Get-Random -Minimum 4kb -Maximum 42kb)/",

# The type map.  This determines how each extension will be served.
[Collections.IDictionary]$TypeMap = [Ordered]@{
    ".html" = "text/html" ; ".css" = "text/css"   ; ".svg" = "image/svg+xml"
    ".png"  = "image/png" ; ".jpg" = "image/jpeg" ; ".gif" = "image/gif"
    ".oog"  = "audio/oog" ; ".mp3"  = "audio/mpeg"; ".mp4" = "video/mp4"
    ".json" = "application/json"; ".xml"  = "application/xml" ; 
    ".js"   = "text/javascript" ; ".jsm" = "text/javascript" ;
    ".ps1" = "text/x-powershell"
})

$httpListener = [Net.HttpListener]::new();$httpListener.Prefixes.Add($RootUrl)
Write-Warning "Listening on $RootUrl $($httpListener.Start())"
# Pack our job input into an IO dictionary
$io = [Ordered]@{
    HttpListener = $httpListener ; ServerRoot = $RootPath
    Files = [Ordered]@{}; ContentTypes = [Ordered]@{}
}
# Then map each file into one or more /uris
foreach ($file in Get-ChildItem -File -Path $RootPath -Recurse) {
    $relativePath =
        $file.FullName.Substring($RootPath.Length) -replace '[\\/]', '/'
    $fileUris = @($relativePath) + @(
        foreach ($indexFile in 'index.html', 'readme.html') {
            $indexPattern = [Regex]::Escape($indexFile) + '$'
            if ($file.Name -eq $indexFile -and -not $IO.Files[
                $relativePath -replace $indexPattern
            ]) {
                $relativePath -replace $indexPattern
                $relativePath -replace "[\\/]$indexPattern"
            }
        }
    )
    foreach ($fileUri in $fileUris) {
        $io.ContentTypes[$fileUri] = # and map content types now
            $TypeMap[$file.Extension] ? # so we don't have to later.
                $TypeMap[$file.Extension] :
                    'text/plain'
        $io.Files[$fileUri] = $file
    }    
}

# Our server is a thread job
Start-ThreadJob -ScriptBlock {param([Collections.IDictionary]$io)
    $psvar = $ExecutionContext.SessionState.PSVariable
    foreach ($k in $io.Keys) { $psvar.set($k, $io[$k]) }
    filter outputError([int]$N) {
        $re.StatusCode = $N
        $localPath = "/$N.html";$file = $files[$LocalPath]
        if ($file) {outputFile} else { $re.Close() }
        continue next
    }
    filter outputHeader {
        $re.Length=$files[$localPath].Length
        $re.Close()
        continue next
    }
    filter outputFile {
        $reply.ContentType = $contentTypes[$localPath]
        $fileStream = $file.OpenRead()
        $fileStream.CopyTo($reply.OutputStream)
        $fileStream.Close(), $fileStream.Dispose()
        $reply.Close()
        continue next
    }
    # Listen for the next request and reply to it.
    :next while ($httpListener.IsListening) {     
        $getContext = $httpListener.GetContextAsync()
        while (-not $getContext.Wait(17)) { }
        $rq = $request = $getContext.Result.Request
        $re = $reply   = $getContext.Result.Response
        $method, $localPath = $rq.HttpMethod, $rq.Url.LocalPath
        # If the method is not allowed, output error 405
        if ($method -notin 'get', 'head') { outputError 405 }
        # If the file does not exist, output error 404
        if (-not ($files -and $files[$localPath])) { outputError 404 }
        $file = $files[$localPath]
        # If they asked for header information, output it.
        if ($method -eq 'head') { outputHeader }        
        outputFile # otherwise, output the file.
    }            
} -ThrottleLimit 100 -ArgumentList $IO -Name "$RootUrl" | # Output our job,
    Add-Member -NotePropertyMembers @{ # and attach a few properties:
        # `.HttpListener`, `.IO`, `.URL`
        HttpListener=$httpListener; IO=$IO; Url="$RootUrl"
    } -Force -PassThru # Pass all of that thru and return it to you.