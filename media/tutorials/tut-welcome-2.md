# How it works

AppChk creates a local VPN tunnel to intercept all network connections. For each connection, AppChk looks into the DNS headers only, namely the domain names. 
These domain names are logged in the background while the VPN is active. That means, AppChk does not have to be active in the foreground. You can close the app and come back later to see the results.
