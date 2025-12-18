<#
.SYNOPSIS
    Switch -RegEx Server
.DESCRIPTION
    A simple server implemented in a single switch -regex.

    Any match can provide results.
.EXAMPLE
    ./SwitchRegexServer.ps1
#>
param(
# The rootUrl of the server.  By default, a random loopback address.
[string]$RootUrl=
    "http://127.0.0.1:$(Get-Random -Minimum 4200 -Maximum 42000)/",

[Collections.IDictionary]
$Dictionary = [Ordered]@{
    "/" = @{ContentType='text/html';Content='<h1>Hello World</h1>'}
}
)

$httpListener = [Net.HttpListener]::new()
$httpListener.Prefixes.Add($RootUrl)
Write-Warning "Listening on $RootUrl $($httpListener.Start())"

$io = [Ordered]@{ # Pack our job input into an IO dictionary
    HttpListener = $httpListener ;
}

# Our server is a thread job
Start-ThreadJob -ScriptBlock {param([Collections.IDictionary]$io)
    $psvariable = $ExecutionContext.SessionState.PSVariable
    foreach ($key in $io.Keys) { # First, let's unpack.
        if ($io[$key] -is [PSVariable]) { $psvariable.set($io[$key]) }
        else { $psvariable.set($key, $io[$key]) }
    }
    
    # Listen for the next request
    :nextRequest while ($httpListener.IsListening) {     
        $getContext = $httpListener.GetContextAsync()
        while (-not $getContext.Wait(17)) { }
        $time = [DateTime]::Now
        $request, $reply =
            $getContext.Result.Request, $getContext.Result.Response
        $result = $null
        $result =
            switch -regex ($request.Url.LocalPath) {
                '/' {
                    "<h1>Home Sweet Home</h1>"                    
                }
                '/Hello/?' {
                    "<h1>Hello World</h1>"
                }
                '/(?<d1>[\d\.]+)x(?<d2>[\d\.]+)/?' {
                    ($matches.d1 -as [double]) * ($matches.d2 -as [double])
                }
                default {
                    $timeToRespond = [DateTime]::Now - $time
                    "$($request.HttpMethod) $($request.Url) $($timeToRespond)"
                }
            }
        if ($result) {
            $reply.Close($OutputEncoding.GetBytes("$result"), $false)
        } else {
            $reply.StatusCode = 404
            $reply.Close()
        }
    }            
} -ThrottleLimit 100 -ArgumentList $IO -Name "$RootUrl" | # Output our job,
    Add-Member -NotePropertyMembers @{ # but attach a few properties first:
        HttpListener=$httpListener # * The listener (so we can stop it)
        IO=$IO # * The IO (so we can change it)
        Url="$RootUrl" # The URL (so we can easily access it).
    } -Force -PassThru # Pass all of that thru and return it to you.