# PSWebHost

## Purpose

This project started out as a what if and has been in interesting learning opportunuty.  I started it about 10 years ago and I have learned a ton from moving through this process.  I'm going to make this public and if anyon wants to geek on this ans finish solveing this puzzle with me just reach out.  

## Why

For security purposes, I held the beliefe that if PowerShell is interacting with HTTPListener or smoe other framework that accepts incomeing web requests, I could implement parsing of incoming get query and post/put/delete/etc data easy and secure since there will be no command-line execution untill data is fully parsed and transformed in PowerShell.

Pros:
 1. PowerShell is easy to write.
 2. PowerShell offers great parameter parsing and I want to be able to implement a script so that a FORM implemented by 
 3. PowerShell is pretty decent as an ETL lanquage.
 4. PowerShell can be used to ensure unexpected charagters are not part of requests by using -match '[regex]' or -replace '[regex]'.
 5. Powershell can querry SQL servers and have data transformations performed there
 6. Since Powershell is ubiquitous in windows environments.

Cons:
 1. PowerShell executions can generate a TON of traffic if auditing is turned on.
   - Workarrounds might be needed to be implemented in environments where Splunk forwarders send directly to Splunk and not CRIBL where these logs can be filtered to prevent extra expense for ingest.
   - PowerShell logging might need to be disabled or otherwise attenuated for the server that is running this module.
 2. It might be better to use Python, but if you have a team that is Windows and MS centric, learning python vs PowerShell can be a bit of a distraction.

## Design Goals

 - Require HTTPS and WSS over insecure traffic always.
 - Test in windows powershell and PowerShell Core
   - If a Windows Powershell function is missing in core, write a wrapper and NEVER use "Windows PowerShell Compatibility" if at all possible as more sessions are created in the background and that can get out of hand.
 - Test on Linux versions and develop compatability strategies. (lower priority for non-breaking features).
 - Pick a web framework for client side single page goodness.

## How it works 

I would like to have an async processing of incoming requests so that the web application can scale to host APIs written in PowerShell.  There are alternative ways to achieve this, but this project has greatly expanded what can be done with PowerShell.  

Flow:

  Listener -->
  Runspace -->
  Router -->
  Launcher -->
    Return HTML or Handle JSON
  
