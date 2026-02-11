param(
  [Parameter(Position=0)]
  [string]$PortName = "COM3",

    [Parameter(Position=1)]
  [string]$Phone = "+639762903345",

  [Parameter(Position=2)]
  [string]$Message = "Hello from PowerShell!"

)

$baud = 115200

$sp = New-Object System.IO.Ports.SerialPort $PortName,$baud,'None',8,'One'
$sp.NewLine = "`r"
$sp.ReadTimeout = 1000
$sp.Open()

function Send-AT($cmd, $waitMs = 300) {
  $sp.Write($cmd + "`r")
  Start-Sleep -Milliseconds $waitMs
  try { return $sp.ReadExisting() } catch { return "" }
}

# Ensure network registration
Send-AT "AT+COPS=0" | Out-Null
$reg = ""
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline) {
  $reg = Send-AT "AT+CREG?"
  if ($reg -match "0,1|0,5") { break }
  Start-Sleep -Seconds 2
}
if ($reg -notmatch "0,1|0,5") { throw "Not registered: $reg" }

# Send SMS
Send-AT "AT+CMGF=1" | Out-Null
$buf = Send-AT ('AT+CMGS="'+$Phone+'"') 300
$deadline = (Get-Date).AddSeconds(10)
while ($buf -notmatch ">" -and (Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 200
  try { $buf += $sp.ReadExisting() } catch {}
}
if ($buf -notmatch ">") { throw "No '>' prompt: $buf" }

$sp.Write($Message)
$sp.Write([char]26)

Start-Sleep -Seconds 5
$final = $sp.ReadExisting()
$sp.Close()
$final