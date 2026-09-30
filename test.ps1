# Computername (Hostname) ermitteln
$hostname = [System.Net.Dns]::GetHostName()

# Alle aktiven Netzwerkadapter mit IPv4-Adresse abrufen
$networkInterfaces = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True"

Write-Host "=== NETZWERKINFORMATIONEN FÜR: $hostname ===" -ForegroundColor Cyan
Write-Host ""

foreach ($adapter in $networkInterfaces) {
    Write-Host "Adapter: $($adapter.Description)" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------"
    
    # IPv4-Adresse und Subnetzmaske filtern
    $ipv4Index = 0
    foreach ($ip in $adapter.IPAddress) {
        if ($ip -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            Write-Host "IP-Adresse:   $ip"
            Write-Host "Subnetzmaske: $($adapter.IPSubnet[$ipv4Index])"
            break
        }
        $ipv4Index++
    }
    
    # Standardgateway (Gateway)
    $gateway = if ($adapter.DefaultIPGateway) { $adapter.DefaultIPGateway -join ", " } else { "Nicht zugewiesen" }
    Write-Host "Gateway:      $gateway"
    
    # DNS-Server
    $dns = if ($adapter.DNSServerSearchOrder) { $adapter.DNSServerSearchOrder -join ", " } else { "Nicht zugewiesen" }
    Write-Host "DNS-Server:   $dns"
    
    # DHCP-Status
    $dhcpStatus = if ($adapter.DHCPEnabled) { "Ja (Aktiv)" } else { "Nein (Statische IP)" }
    Write-Host "DHCP aktiv:   $dhcpStatus"
    
    Write-Host ""
}
