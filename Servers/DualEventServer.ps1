<#
.SYNOPSIS
    Event Server
.DESCRIPTION
    A simple event driven server.

    Each request will generate an event, which will be responded to by a handler.
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
    HttpListener = $httpListener ; ServerRoot = $RootDirectory
    MainRunspace = [Runspace]::DefaultRunspace; SourceIdentifier = $RootUrl
    TypeMap = $TypeMap
}

# Our server is a thread job
Start-ThreadJob -ScriptBlock {param([Collections.IDictionary]$io)
    $psvariable = $ExecutionContext.SessionState.PSVariable
    foreach ($key in $io.Keys) { # First, let's unpack.
        if ($io[$key] -is [PSVariable]) { $psvariable.set($io[$key]) }
        else { $psvariable.set($key, $io[$key]) }
    }

    $thisRunspace = [Runspace]::DefaultRunspace

    # Because we are handling the event locally, the main thread can keep chugging.
    Register-EngineEvent -SourceIdentifier $SourceIdentifier -Action {
        try {
            $request = $event.MessageData.Request
            $reply = $event.MessageData.Reply
            
            $timeToRespond = [DateTime]::Now - $event.TimeGenerated
            $myReply = "$($request.HttpMethod) $($request.Url) $($timeToRespond)"
            $reply.Close($OutputEncoding.GetBytes($myReply), $false)
        } catch {
            Write-Error $_            
        }        
    }
    
    # Listen for the next request
    :nextRequest while ($httpListener.IsListening) {     
        $getContext = $httpListener.GetContextAsync()
        while (-not $getContext.Wait(17)) { }
        $request, $reply =
            $getContext.Result.Request, $getContext.Result.Response
        
        # Generate events for every request
        foreach ($runspace in $thisRunspace, $mainRunspace) {
            # by broadcasting to multiple runspaces, we can both reply and have a record.
            $runspace.Events.GenerateEvent(            
                $SourceIdentifier, $httpListener, @(
                    $getContext.Result, $request, $reply                    
                ), [Ordered]@{
                    Method = $Request.HttpMethod; Url = $request.Url
                    Request = $request; Reply = $reply; Response = $reply
                    ServerRoot = $ServerRoot; TypeMap = $TypeMap
                }
            )
        }        
    }            
} -ThrottleLimit 100 -ArgumentList $IO -Name "$RootUrl" | # Output our job,
    Add-Member -NotePropertyMembers @{ # but attach a few properties first:
        HttpListener=$httpListener # * The listener (so we can stop it)
        IO=$IO # * The IO (so we can change it)
        Url="$RootUrl" # The URL (so we can easily access it).
    } -Force -PassThru # Pass all of that thru and return it to you.