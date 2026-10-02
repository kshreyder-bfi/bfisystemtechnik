# ============================================
#  Netzwerkinformationen anzeigen und speichern
# ============================================

$hostname = [System.Net.Dns]::GetHostName()
$datum    = Get-Date -Format "dd.MM.yyyy HH:mm"
$ausgabe  = @()   # sammelt alle Zeilen für die Textdatei

# Zeile am Bildschirm zeigen UND für die Datei merken
function Zeile {
    param([string]$Text = "", [string]$Farbe = "White")
    Write-Host $Text -ForegroundColor $Farbe
    $script:ausgabe += $Text
}

# Subnetzmaske in Kurzform umrechnen (255.255.255.0 -> /24)
function Get-CIDR {
    param([string]$Maske)
    $bits = 0
    foreach ($teil in $Maske.Split('.')) {
        $bits += ([Convert]::ToString([int]$teil, 2) -replace '0', '').Length
    }
    return "/$bits"
}

# Ping-Test mit grün/rot
function Test-Ziel {
    param([string]$Name, [string]$Ziel)
    if (Test-Connection -ComputerName $Ziel -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        Zeile "  $Name $Ziel : erreichbar" "Green"
    } else {
        Zeile "  $Name $Ziel : NICHT erreichbar" "Red"
    }
}

$ipv4Muster   = '^\d{1,3}(\.\d{1,3}){3}$'
$adapterListe = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True"

Zeile "=== NETZWERKINFORMATIONEN FÜR: $hostname ===" "Cyan"
Zeile "Erstellt am: $datum" "Cyan"
Zeile

foreach ($adapter in $adapterListe) {

    $istVirtuell = $adapter.Description -match 'Hyper-V|Virtual|VMware|VirtualBox|WSL|Loopback'
    $gateways    = @($adapter.DefaultIPGateway | Where-Object { $_ -match $ipv4Muster })
    $hatGateway  = $gateways.Count -gt 0

    # Überschrift: Hauptverbindung grün, virtuell grau, Rest gelb
    if ($hatGateway)      { Zeile "Adapter: $($adapter.Description)  [HAUPTVERBINDUNG]" "Green" }
    elseif ($istVirtuell) { Zeile "Adapter: $($adapter.Description)  [virtuell]" "DarkGray" }
    else                  { Zeile "Adapter: $($adapter.Description)" "Yellow" }
    Zeile "--------------------------------------------------"

    # MAC-Adresse
    Zeile "MAC-Adresse:  $($adapter.MACAddress)"

    # Geschwindigkeit (Speed)
    $nic = Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "Index = $($adapter.Index)"
    if ($nic.Speed -and [double]$nic.Speed -lt 1e12) {
        Zeile "Speed:        $([math]::Round([double]$nic.Speed / 1e6)) Mbit/s"
    } else {
        Zeile "Speed:        unbekannt"
    }

    # IPv4-Adresse und passende Subnetzmaske
    for ($i = 0; $i -lt $adapter.IPAddress.Count; $i++) {
        if ($adapter.IPAddress[$i] -match $ipv4Muster) {
            $maske = $adapter.IPSubnet[$i]
            Zeile "IP-Adresse:   $($adapter.IPAddress[$i])"
            Zeile "Subnetzmaske: $maske ($(Get-CIDR $maske))"
            break
        }
    }

    # Gateway
    $gwText = if ($hatGateway) { $gateways -join ", " } else { "Nicht zugewiesen" }
    Zeile "Gateway:      $gwText"

    # DNS
    $dnsListe = @($adapter.DNSServerSearchOrder | Where-Object { $_ })
    $dnsText  = if ($dnsListe.Count -gt 0) { $dnsListe -join ", " } else { "Nicht zugewiesen" }
    Zeile "DNS-Server:   $dnsText"

    # DHCP mit Server und Ablaufzeit
    if ($adapter.DHCPEnabled) {
        Zeile "DHCP aktiv:   Ja (automatisch)"
        Zeile "DHCP-Server:  $($adapter.DHCPServer)"
        if ($adapter.DHCPLeaseExpires) {
            Zeile "Gültig bis:   $($adapter.DHCPLeaseExpires.ToString('dd.MM.yyyy HH:mm'))"
        }
    } else {
        Zeile "DHCP aktiv:   Nein (statische IP)"
    }

    # Verbindungstest nur für die Hauptverbindung
    if ($hatGateway) {
        Zeile
        Zeile "Verbindungstest:" "Cyan"
        foreach ($gw in $gateways) { Test-Ziel "Gateway" $gw }
        foreach ($d in $dnsListe)  { Test-Ziel "DNS    " $d }
        Test-Ziel "Internet" "8.8.8.8"

        # DNS-Test: kann der Name google.at in eine IP übersetzt werden?
        try {
            $ip = [System.Net.Dns]::GetHostAddresses("google.at") |
                  Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                  Select-Object -First 1
            Zeile "  DNS-Test google.at -> $ip : funktioniert" "Green"
        } catch {
            Zeile "  DNS-Test google.at : funktioniert NICHT" "Red"
        }
    }

    Zeile
}

# Öffentliche IP (Adresse, unter der dich das Internet sieht)
Zeile "=== INTERNET ===" "Cyan"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5
    Zeile "Öffentliche IP: $publicIP" "Green"
} catch {
    Zeile "Öffentliche IP: nicht abrufbar (kein Internet?)" "Red"
}
Zeile

# Ergebnis als Textdatei auf dem Desktop speichern
$datei = Join-Path ([Environment]::GetFolderPath("Desktop")) "Netzwerkinfo_$hostname.txt"
$ausgabe | Out-File -FilePath $datei -Encoding UTF8
Write-Host "Gespeichert unter: $datei" -ForegroundColor Cyan
