param(
    [Parameter(Position=0)]
    [string]$PortName,
    [Parameter(Position=1)]
    [string]$Phone,
    [Parameter(Position=2)]
    [string]$Message
)

$baud    = 115200
$sp      = New-Object System.IO.Ports.SerialPort $PortName,$baud,'None',8,'One'
$sp.NewLine = "`r"
$sp.ReadTimeout = 1000

function Send-AT($cmd, $waitMs = 300) {
    $sp.Write($cmd + "`r")
    Start-Sleep -Milliseconds $waitMs
    try { return $sp.ReadExisting() } catch { return "" }
}

try {
    $sp.Open()

    # Flush stale data
    try { while ($sp.BytesToRead) { $null = $sp.ReadExisting() } } catch {}

    # Ensure network registration
    Send-AT "AT+COPS=0" | Out-Null
    $reg = ""
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        $reg = Send-AT "AT+CREG?"
        Write-Host "CREG response: $reg"
        if ($reg -match "\+CREG: 0,[15]") { break }
        Start-Sleep -Seconds 2
    }
    if ($reg -notmatch "\+CREG: 0,[15]") { 
        throw "Not registered: $reg" 
    }

    # Set SMS mode to text
    Send-AT "AT+CMGF=1" | Out-Null

    # Prepare to send SMS
    $buf = Send-AT ('AT+CMGS="' + $Phone + '"') 300
    $deadline = (Get-Date).AddSeconds(10)
    while ($buf -notmatch ">" -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200
        try { $buf += $sp.ReadExisting() } catch {}
    }
    if ($buf -notmatch ">") { throw "No '>' prompt: $buf" }

    # Send the SMS message
    $sp.Write($Message)
    $sp.Write([char]26)  # Ctrl+Z to send
    Start-Sleep -Seconds 5
    $final = $sp.ReadExisting()
    $final
}
finally {
    if ($sp.IsOpen) { $sp.Close() }
}