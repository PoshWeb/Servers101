@"
# Servers 101

Servers are pretty simple.

You listen and then you reply.

That's Servers 101.

## Simple Servers

Frameworks often abstract this away.

This can make the basics of servers harder to learn.

To avoid reliance on the framework flavor of the week, it's good to learn how to build a simple server.

This is a collection of simple servers in PowerShell.

Feel free to [contribute](contributing.md) and add your own.

## Sample Servers

"@


foreach ($serverScript in Get-Servers101) {
    "* [$($serverScript.Name)]($($serverScript.FullName.Substring("$pwd".Length)))"
}


@"

## Installing

You can install Servers101 from the [PowerShell Gallery](https://powershellgallery.com)

~~~PowerShell
Install-Module Servers101
~~~

Once installed, you can import it:

~~~PowerShell
Import-Module Servers101 -PassThru
~~~

## Using this module

This module has only one command, `Get-Servers101`.

It will return all of the sample servers in the module.

Each server will be self-contained in a single script.  

To start the server, simply run the script.

To learn about how each server works, read thru each script.
"@


@"

## Streaming Server101

Because each server is contained within a single file, the servers can be streamed to a file

For example, to start a local file server, we can run:

~~~PowerShell
Invoke-RestMethod https://cdn.jsdelivr.net/gh/PoshWeb/Servers101@latest/Servers/Server101.ps1 > ./server.ps1; 
./server.ps1
~~~

For some servers it is also possible to run with Invoke-Expression.

You should never Invoke-Expression code you cannot trust and verify.

To stream a local file server, we can run:

~~~PowerShell
irm https://cdn.jsdelivr.net/gh/PoshWeb/Servers101@latest/Servers/Server101.ps1 | iex
~~~
"@