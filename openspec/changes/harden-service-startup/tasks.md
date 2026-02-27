# Tasks: Harden Service Startup

- [x] Add `Wait-ServiceRunning` helper function with polling loop and timeout
- [x] Replace `Start-Sleep -Seconds 2` after `Start-Service` (line ~119) with `Wait-ServiceRunning`
- [x] Replace `Start-Sleep -Seconds 2` after `Restart-Service` (line ~137) with `Wait-ServiceRunning`
- [x] Replace `Start-Sleep -Seconds 2` after lfsvc `Start-Service` (line ~212) with `Wait-ServiceRunning`
- [x] Add `$LASTEXITCODE` check after `sc.exe create` and set `$remediationSuccess = $false` on failure
