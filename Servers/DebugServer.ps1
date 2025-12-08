<#
.SYNOPSIS
    A debug server.
.DESCRIPTION
    A server that runs on the current thread, so you can debug it.

    You can run this with -AsJob, but then you cannot debug in PowerShell.
.NOTES
    A few notes:

    1. This will effectively lock the current thread (CTRL+C works).
    2. Because of the way requests are processed, you may need to refresh to hit the breakpoint.
    3. Be aware that browsers will request a `favicon.ico` first.
#>
param(
# The rootUrl of the server.  By default, a random loopback address.
[string]$RootUrl=
    "http://127.0.0.1:$(Get-Random -Minimum 4200 -Maximum 42000)/",

# If set, will run in a background job.
[switch]
$AsJob
)

$httpListener = [Net.HttpListener]::new()
$httpListener.Prefixes.add($RootUrl)
$httpListener.Start()
Write-Warning "Listening on $rootUrl"

$listenScript = {
    param([Net.HttpListener]$httpListener)
    # Listen for the next request
    :nextRequest while ($httpListener.IsListening) {     
        $getContext = $httpListener.GetContextAsync()
        
        while (-not $getContext.Wait(17)) { }            

        $context = $getContext.Result
        $requestTime = [DateTime]::Now
        $request, $reply = $context.Request, $context.Response
        $debugObject = $request |
            Select-Object HttpMethod, Url, Is* |
            Add-Member NoteProperty Headers ([Ordered]@{}) -Force  -passThru |
            Add-Member NoteProperty Query ([Ordered]@{}) -Force  -passThru

        foreach ($headerName in $request.Headers) {
            $debugObject.headers[$headerName] = $request.Headers[$headerName]
        }
        if ($request.Url.Query) {            
            
            foreach ($chunk in $request.Url.Query -split '&') {
                $parsedQuery =
                    [Web.HttpUtility]::ParseQueryString($chunk)
                $key = @($parsedQuery.Keys)[0]
                if ($debugObject.Query[$key]) {
                    $debugObject.Query[$key] = @(
                        $debugObject.Query[$key]
                    ) + $parsedQuery[$key]
                } else {
                    $debugObject.Query[$key] = $parsedQuery[$key]
                } 
            }
        }
        $reply.ContentType = 'application/json'
        $reply.Close(        
            $OutputEncoding.GetBytes(    
                ($debugObject |  ConvertTo-Json -Depth 5)
                    ), $false)
        "Responded to $($Request.Url) in $([DateTime]::Now - $requestTime)"
    }
}

if ($AsJob) {
    Start-ThreadJob -ScriptBlock $listenerScript -ArgumentList $httpListener
} else {
    . $listenScript $httpListener
}