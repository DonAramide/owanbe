# Shared port preflight for Flutter web scripts.
# Usage: Ensure-FlutterWebPort -Port 3000 -Restart:$Restart
function Get-ListenersOnPort([int]$Port) {
    Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Sort-Object OwningProcess -Unique
}

function Ensure-FlutterWebPort {
    param(
        [Parameter(Mandatory = $true)][int]$Port,
        [switch]$Restart
    )

    $listeners = @(Get-ListenersOnPort $Port)
    if ($listeners.Count -eq 0) { return }

    $pids = $listeners | ForEach-Object { $_.OwningProcess } | Sort-Object -Unique
    $procs = foreach ($procId in $pids) {
        Get-Process -Id $procId -ErrorAction SilentlyContinue
    }
    $names = ($procs | ForEach-Object { "$($_.ProcessName) (PID $($_.Id))" }) -join ', '
    if (-not $names) { $names = "PID(s) $($pids -join ', ')" }

    $onlyDartVm = ($procs.Count -gt 0) -and (
        $procs | ForEach-Object { $_.ProcessName -eq 'dartvm' -or $_.ProcessName -eq 'dart' }
    ) -notcontains $false

    if ($Restart -and $onlyDartVm) {
        Write-Host "Port $Port is held by a stale Flutter web server ($names). Stopping it..."
        foreach ($procId in $pids) {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 1
        $still = @(Get-ListenersOnPort $Port)
        if ($still.Count -eq 0) { return }
        throw "Port $Port is still in use after Stop-Process. Close the other Flutter session (press q) and retry."
    }

    Write-Host @"
Port $Port is already in use by: $names

This is not a Flutter config error. A previous Customer/Admin web session is still running.

Fix:
  1. In that Flutter terminal, press q
  2. Or stop the process:  Stop-Process -Id $($pids -join ',') -Force
  3. Then re-run this script
  4. Or re-run with -Restart to stop a stale dartvm on this port only

"@
    exit 1
}
