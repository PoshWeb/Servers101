<#
.SYNOPSIS
    Math Server
.DESCRIPTION
    A simple math server.

    Each first request segment must map to a static method on the `[Math]` class
.EXAMPLE
    ./MathServer.ps1
#>
param(
# The rootUrl of the server.  By default, a random loopback address.
[string]$RootUrl=
    "http://127.0.0.1:$(Get-Random -Minimum 4200 -Maximum 42000)/"
)

$httpListener = [Net.HttpListener]::new()
$httpListener.Prefixes.Add($RootUrl)
Write-Warning "Listening on $RootUrl $($httpListener.Start())"

$io = [Ordered]@{ # Pack our job input into an IO dictionary
    HttpListener = $httpListener 
}

# Our server is a thread job
Start-ThreadJob -ScriptBlock {param([Collections.IDictionary]$io)
    $psvariable = $ExecutionContext.SessionState.PSVariable
    foreach ($key in $io.Keys) { # First, let's unpack.
        if ($io[$key] -is [PSVariable]) { $psvariable.set($io[$key]) }
        else { $psvariable.set($key, $io[$key]) }
    }
    $staticMembers = [Math] | Get-Member -Static 
    # Listen for the next request
    :nextRequest while ($httpListener.IsListening) {     
        $getContext = $httpListener.GetContextAsync()
        while (-not $getContext.Wait(17)) { }
        $request, $reply =
            $getContext.Result.Request, $getContext.Result.Response
        
        $segments = @($request.Url.Segments)
        if ($segments.Length -le 1) {            
            $reply.ContentType = 'text/html'
            $memberList = @(
                "<ul>"
                foreach ($staticMember in $staticMembers) {
                    "<li>"
                    "<a href='/$($staticMember.name)'>$(
                        $staticMember.name
                    )</a>"
                    "</li>"
                }
                "</ul>"
            ) -join [Environment]::NewLine
            $reply.Close($OutputEncoding.GetBytes($memberList), $false)                        
            continue nextRequest
        } else {
            $firstSegment = $segments[1] -replace '/'
            $mathMember = [Math]::$firstSegment
            if ($null -eq $mathMember) {
                $reply.StatusCode = 404                
                $reply.Close()
                continue nextRequest
            }
        }

        if ($mathMember.Invoke) {
            $mathArgs = 
                if ($segments.Length -ge 3) {
                    @(for ($segmentNumber = 2; $segmentNumber -lt $segments.Length; $segmentNumber++) {
                        $segments[$segmentNumber] -replace '/' -as [double]
                    })
                } else {
                    $Reply.Close($OutputEncoding.GetBytes("$(
                        $mathMember.OverloadDefinitions -join [Environment]::NewLine
                    )"), $false)    
                }            
            try {
                $result = $mathMember.Invoke($mathArgs)
                $Reply.Close($OutputEncoding.GetBytes("$result"), $false)
            } catch {
                $Reply.Close($OutputEncoding.GetBytes("$($_ | Out-String)"), $false)
            }
        } else {
            $Reply.Close($OutputEncoding.GetBytes("$mathMember"), $false)
        }
    }            
} -ThrottleLimit 100 -ArgumentList $IO -Name "$RootUrl" | # Output our job,
    Add-Member -NotePropertyMembers @{ # but attach a few properties first:
        HttpListener=$httpListener # * The listener (so we can stop it)
        IO=$IO # * The IO (so we can change it)
        Url="$RootUrl" # The URL (so we can easily access it).
    } -Force -PassThru # Pass all of that thru and return it to you.