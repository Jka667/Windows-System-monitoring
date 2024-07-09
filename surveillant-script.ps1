# Variables
$InactiveDays = 90
$ReportPath = "C:\mardi\SecurityReport.txt" # À modifier pour indiquer l'emplacement voulu
$EventLogDays = 30

# Fonction pour obtenir les comptes utilisateurs inactifs
function Get-InactiveUsers {
    $limit = (Get-Date).AddDays(-$InactiveDays)
    $users = Get-LocalUser | Where-Object { $_.LastLogon -lt $limit }
    return $users
}

# Fonction pour obtenir les tentatives de connexion échouées
function Get-FailedLogonAttempts {
    $limit = (Get-Date).AddDays(-$EventLogDays)
    $events = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=$limit} | Select-Object TimeCreated, @{Name='UserName'; Expression={$_.Properties[5].Value}}, Message
    return $events
}

# Fonction pour obtenir l'utilisation du CPU
function Get-CPUUsage {
    $cpu = Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average
    return $cpu.Average
}

# Fonction pour obtenir l'utilisation de la mémoire
function Get-MemoryUsage {
    $memory = Get-WmiObject Win32_OperatingSystem
    return [math]::round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
}

# Fonction pour obtenir l'utilisation du disque
function Get-DiskUsage {
    $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"
    $diskUsage = @()
    foreach ($disk in $disks) {
        $usage = [math]::round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
        $diskUsage += "$($disk.DeviceID): $usage%"
    }
    return $diskUsage -join ", "
}

# Générer le rapport de sécurité
$inactiveUsers = Get-InactiveUsers
$failedLogonAttempts = Get-FailedLogonAttempts

$securityReport = @"
Rapport de sécurité
===================

Comptes utilisateurs inactifs (depuis plus de $InactiveDays jours) :
-------------------------------------
$($inactiveUsers | Format-Table -Property Name, LastLogon -AutoSize | Out-String)

Tentatives de connexion échouées (au cours des $EventLogDays derniers jours) :
-------------------------------------
$($failedLogonAttempts | Format-Table -Property TimeCreated, UserName, Message -AutoSize | Out-String)

Généré le : $(Get-Date)
"@

# Générer le rapport d'utilisation du système
$cpuUsage = Get-CPUUsage
$memoryUsage = Get-MemoryUsage
$diskUsage = Get-DiskUsage

$systemReport = @"
Rapport d'utilisation du système
===============================

Utilisation du CPU : $cpuUsage %
Utilisation de la mémoire : $memoryUsage %
Utilisation du disque : $diskUsage

Généré le : $(Get-Date)
"@

# Sauvegarder le rapport
$finalReport = $securityReport + $systemReport
$finalReport | Out-File -FilePath $ReportPath
Write-Host "Rapport généré et sauvegardé à $ReportPath"
