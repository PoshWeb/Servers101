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


## Server Samples

"@


foreach ($serverScript in Get-Servers101) {
    "* [$($serverScript.Name)]($($serverScript.FullName.Substring("$pwd".Length)))"
}



@"

## Using this module

This module has only one command, `Get-Servers101`.

It will return all of the sample servers in the module.

Each server will be self-contained in a single script.  

To start the server, simply run the script.

To learn about how each server works, read thru each script.
"@