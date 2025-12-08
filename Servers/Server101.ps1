<#
.SYNOPSIS
    Server 101
.DESCRIPTION
    Server 101: A file server in 101 lines of pure PowerShell.
.EXAMPLE
    ./Server101.ps1 ($pwd | Split-Path)
#>
param(
<# The Root Directory. #> [string]$RootDirectory = $PSScriptRoot,

# The rootUrl of the server.  By default, a random loopback address.
[string]$RootUrl=
    "http://127.0.0.1:$(Get-Random -Minimum 4200 -Maximum 42000)/",

# The type map.  This determines how each extension will be served.
[Collections.IDictionary]
$TypeMap = [Ordered]@{
    ".html" = "text/html" ; ".css" = "text/css"  ; ".svg" = "image/svg+xml" ;
    ".png"  = "image/png" ; ".jpg" = "image/jpeg"; ".gif" = "image/gif"
    ".mp3"  = "audio/mpeg"; ".mp4" = "video/mp4"
    ".json" = "application/json"; ".xml"  = "application/xml" ; 
    ".js"   = "text/javascript" ; ".jsm" = "text/javascript" ;
    ".ps1" = "text/x-powershell"
})

$httpListener = [Net.HttpListener]::new()
$httpListener.Prefixes.Add($RootUrl)
Write-Warning "Listening on $RootUrl $($httpListener.Start())"

$io = [Ordered]@{ # Pack our job input into an IO dictionary
    HttpListener = $httpListener ; ServerRoot = $RootDirectory
    Files = [Ordered]@{}; ContentTypes = [Ordered]@{} 
}
# Then map each file into one or more /uris
foreach ($file in Get-ChildItem -File -Path $RootDirectory -Recurse) {
    $relativePath =
        $file.FullName.Substring($RootDirectory.Length) -replace '[\\/]', '/'
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
    $psvariable = $ExecutionContext.SessionState.PSVariable
    foreach ($key in $io.Keys) { # First, let's unpack
        if ($io[$key] -is [PSVariable]) { $psvariable.set($io[$key]) }
        else { $psvariable.set($key, $io[$key]) }
    } # and then declare a few filters to make code more readable.
    filter outputError([int]$Number) {
        $reply.StatusCode = $Number; $reply.Close(); continue nextRequest
    }
    filter outputHeader {
        $reply.Length=$file.Length; $reply.Close(); continue nextRequest
    }
    filter outputFile {
        $reply.ContentType = $contentTypes[$potentialPath]
        $fileStream = $file.OpenRead()
        $fileStream.CopyTo($reply.OutputStream)
        $fileStream.Close(); $fileStream.Dispose(); $reply.Close()
        continue nextRequest
    }
    # Listen for the next request
    :nextRequest while ($httpListener.IsListening) {     
        $getContext = $httpListener.GetContextAsync()
        while (-not $getContext.Wait(17)) { }
        $request, $reply = # and reply to it.
            $getContext.Result.Request, $getContext.Result.Response
        $method, $localPath = 
            $request.HttpMethod, $request.Url.LocalPath
        # If the method is not allowed, output error 405
        if ($method -notin 'get', 'head') { outputError 405 }
        # If the file does not exist, output error 404
        if (-not ($files -and $files[$localPath])) { outputError 404 }
        $file = $files[$request.Url.LocalPath]
        # If they asked for header information, output it.
        if ($request.httpMethod -eq 'head') { outputHeader }        
        outputFile # otherwise, output the file.
    }            
} -ThrottleLimit 100 -ArgumentList $IO -Name "$RootUrl" | # Output our job,
    Add-Member -NotePropertyMembers @{ # but attach a few properties first:
        HttpListener=$httpListener # * The listener (so we can stop it)
        IO=$IO # * The IO (so we can change it)
        Url="$RootUrl" # The URL (so we can easily access it).
    } -Force -PassThru # Pass all of that thru and return it to you.