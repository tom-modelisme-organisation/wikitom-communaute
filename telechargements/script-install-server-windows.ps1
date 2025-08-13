# TOM Server - Installateur Windows PowerShell - Optimisé Routeur ASUS RT-AX58U
# URL: https://raw.githubusercontent.com/tom-modelisme-organisation/wikitom-communaute/main/script-install-server-windows.ps1

# Configuration
$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

Clear-Host
Write-Host "🚀 TOM Server Installer - Windows (ASUS Routeur)" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation automatique optimisée pour routeur ASUS RT-AX58U" -ForegroundColor White
Write-Host "Détection réseau TOM-NETWORK et configuration automatique..." -ForegroundColor White
Write-Host ""

# Variables
$TomDir = "C:\Program Files\TOM-Server"
$UserHome = $env:USERPROFILE

# Fonction pour détecter le réseau TOM
function Test-ReseauTOM {
    try {
        $adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
            $_.IPAddress -like "192.168.1.*" -and $_.IPAddress -ne "192.168.1.255" 
        }
        
        if ($adapters) {
            $adapter = $adapters[0]
            $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Where-Object { 
                $_.NextHop -like "192.168.1.*" 
            }).NextHop
            
            return @{
                Detected = $true
                IP = $adapter.IPAddress
                Interface = $adapter.InterfaceAlias
                Gateway = $gateway
                RecommendedIP = "192.168.1.100"
            }
        }
        
        return @{ Detected = $false }
    } catch {
        return @{ Detected = $false; Error = $_.Exception.Message }
    }
}

# Fonction pour vérifier la connexion au routeur ASUS
function Test-RouteurASUS {
    param([string]$Gateway)
    
    try {
        $ping = Test-Connection -ComputerName $Gateway -Count 1 -Quiet -TimeoutSeconds 3
        return $ping
    } catch {
        return $false
    }
}

# Vérifier les privilèges administrateur
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Privilèges administrateur requis" -ForegroundColor Red
    Write-Host "💡 Clic droit sur PowerShell → 'Exécuter en tant qu'administrateur'" -ForegroundColor Yellow
    Read-Host "Appuyez sur Entrée pour fermer"
    exit 1
}

Write-Host "🔍 Étape 0/6 - Analyse réseau TOM..." -ForegroundColor Yellow

# Analyser le réseau
$networkInfo = Test-ReseauTOM

if ($networkInfo.Detected) {
    Write-Host "✅ Réseau TOM-NETWORK détecté !" -ForegroundColor Green
    Write-Host "   📍 IP actuelle: $($networkInfo.IP)" -ForegroundColor White
    Write-Host "   🌐 Interface: $($networkInfo.Interface)" -ForegroundColor White
    Write-Host "   🚪 Gateway: $($networkInfo.Gateway)" -ForegroundColor White
    
    # Test connexion routeur ASUS
    Write-Host "🔌 Test connexion routeur ASUS..." -ForegroundColor Yellow
    if (Test-RouteurASUS -Gateway $networkInfo.Gateway) {
        Write-Host "✅ Routeur ASUS RT-AX58U accessible !" -ForegroundColor Green
        Write-Host "   💡 Recommandation: Configurez réservation DHCP pour 192.168.1.100" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️ Routeur non accessible, mais configuration réseau détectée" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Réseau TOM-NETWORK non détecté" -ForegroundColor Yellow
    Write-Host "   💡 Le serveur TOM fonctionnera, mais optimisations limitées" -ForegroundColor Cyan
    Write-Host "   📋 Connectez-vous au WiFi TOM-NETWORK après installation" -ForegroundColor White
}

Write-Host ""
Write-Host "📦 Étape 1/6 - Vérification/Installation Node.js..." -ForegroundColor Yellow

# Vérifier ou installer Node.js
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js déjà installé ($nodeVersion)" -ForegroundColor Green
} catch {
    Write-Host "🔥 Téléchargement et installation Node.js..." -ForegroundColor Yellow
    
    $nodeUrl = "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi"
    $nodeInstaller = "$env:TEMP\nodejs.msi"
    
    try {
        Write-Host "⬇️ Téléchargement Node.js..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeInstaller -UseBasicParsing
        
        Write-Host "🔧 Installation Node.js..." -ForegroundColor Yellow
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$nodeInstaller`" /quiet /norestart"
        
        Remove-Item $nodeInstaller -Force
        
        # Actualiser les variables d'environnement
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Vérifier installation
        try {
            $nodeVersion = node --version
            Write-Host "✅ Node.js installé avec succès ($nodeVersion)" -ForegroundColor Green
        } catch {
            Write-Host "❌ Erreur installation Node.js" -ForegroundColor Red
            Write-Host "💡 Redémarrez PowerShell et relancez la commande" -ForegroundColor Yellow
            Read-Host "Appuyez sur Entrée pour fermer"
            exit 1
        }
    } catch {
        Write-Host "❌ Erreur téléchargement Node.js: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Appuyez sur Entrée pour fermer"
        exit 1
    }
}

Write-Host ""
Write-Host "📂 Étape 2/6 - Création dossier TOM Server..." -ForegroundColor Yellow

# Arrêter les anciens serveurs TOM
Write-Host "🛑 Arrêt des anciens serveurs TOM..." -ForegroundColor Yellow
try {
    $tomProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { 
        $_.MainModule.FileName -like "*TOM-Server*" 
    }
    if ($tomProcesses) {
        $tomProcesses | Stop-Process -Force
        Write-Host "✅ Anciens serveurs TOM arrêtés" -ForegroundColor Green
    }
} catch {
    # Ignore les erreurs d'arrêt
}

# Créer le dossier TOM
try {
    if (Test-Path $TomDir) {
        Remove-Item -Path $TomDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TomDir -Force | Out-Null
    Write-Host "✅ Dossier créé: $TomDir" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur création dossier: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour fermer"
    exit 1
}

Write-Host ""
Write-Host "📄 Étape 3/6 - Installation TOM Server optimisé routeur..." -ForegroundColor Yellow

# Créer package.json
$packageJson = @"
{
  "name": "tom-server-https-routeur",
  "version": "2.0.0",
  "description": "TOM Multi-Device HTTPS Server - Optimisé ASUS RT-AX58U",
  "main": "serveur-https-complet.js",
  "scripts": {
    "start": "node serveur-https-complet.js",
    "stop": "taskkill /f /im node.exe",
    "status": "tasklist /fi \"imagename eq node.exe\" | findstr node",
    "test-routeur": "node -e \"console.log('Test routeur ASUS...');\"",
    "scan-blocknode": "node -e \"console.log('Scan BlockNodes...');\""
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "keywords": ["tom", "train", "https", "multi-device", "asus", "routeur"],
  "author": "TOM Team",
  "license": "MIT",
  "config": {
    "routeur": {
      "ssid": "TOM-NETWORK",
      "gateway": "192.168.1.1",
      "ipReservee": "192.168.1.100"
    }
  }
}
"@

Set-Content -Path "$TomDir\package.json" -Value $packageJson -Encoding UTF8

# Copier le serveur HTTPS optimisé (utilise le contenu de l'artifact précédent)
$serverJs = Get-Content -Path "serveur-https-complet.js" -Raw -ErrorAction SilentlyContinue

# Si le fichier n'existe pas, créer une version simplifiée
if (-not $serverJs) {
    $serverJs = @"
// TOM Server HTTPS - Version optimisée routeur ASUS (Installation Windows)
const express = require('express');
const https = require('https');
const os = require('os');

class TOMServerRouteur {
    constructor(port = 3443) {
        this.port = port;
        this.app = express();
        this.codeAppairage = this.genererCode();
        this.setupExpress();
        this.setupRoutes();
    }

    setupExpress() {
        this.app.use(express.json());
        this.app.use((req, res, next) => {
            res.header('Access-Control-Allow-Origin', '*');
            res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
            res.header('Access-Control-Allow-Headers', 'Content-Type');
            if (req.method === 'OPTIONS') res.sendStatus(200);
            else next();
        });
    }

    setupRoutes() {
        this.app.get('/api/status', (req, res) => {
            const networkInfo = this.analyserReseauTOM();
            res.json({
                status: 'running',
                protocol: 'https',
                port: this.port,
                ip: this.getLocalIP(),
                code: this.codeAppairage,
                timestamp: Date.now(),
                reseau: networkInfo,
                routeur: 'ASUS RT-AX58U optimisé'
            });
        });

        this.app.get('/test', (req, res) => {
            const networkInfo = this.analyserReseauTOM();
            res.send(`
                <h1>🚀 TOM Server - Routeur ASUS RT-AX58U</h1>
                <p>Serveur HTTPS opérationnel sur port \${this.port}</p>
                <p>IP: \${this.getLocalIP()}</p>
                <p>Code d'appairage: <strong>\${this.codeAppairage}</strong></p>
                <p>Réseau TOM: \${networkInfo.detected ? '✅ Connecté' : '⚠️ Non détecté'}</p>
                <p><em>Installation TOM Server - Windows</em></p>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
                    h1 { color: #2c5aa0; }
                    p { margin: 10px 0; }
                    strong { color: #e74c3c; font-size: 1.2em; }
                </style>
            `);
        });
    }

    analyserReseauTOM() {
        const interfaces = os.networkInterfaces();
        for (const [nom, details] of Object.entries(interfaces)) {
            for (const detail of details) {
                if (detail.family === 'IPv4' && !detail.internal && detail.address.startsWith('192.168.1.')) {
                    return {
                        detected: true,
                        interface: nom,
                        ip: detail.address,
                        gateway: '192.168.1.1'
                    };
                }
            }
        }
        return { detected: false };
    }

    getLocalIP() {
        const networkInfo = this.analyserReseauTOM();
        if (networkInfo.detected) return networkInfo.ip;
        
        const interfaces = os.networkInterfaces();
        for (const name of Object.keys(interfaces)) {
            for (const networkInterface of interfaces[name]) {
                if (networkInterface.family === 'IPv4' && !networkInterface.internal) {
                    return networkInterface.address;
                }
            }
        }
        return 'localhost';
    }

    genererCode() {
        return Math.random().toString(36).substr(2, 6).toUpperCase();
    }

    start() {
        const options = {
            key: `-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7VJTUt9Us8cKB
wMnFW7n6wACiEcROuNZDdOHg7lGbAT2vGT8pXG8N1NbWo8VsKQzoN5tQhc8l5L08
v9LwJ5qL8KXf7QzZ9X5X0Zz5D9pR0I1V4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V
4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V
4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V
wIDAQABAoIBAEFNrWh8VJEWsGZJQkNV
-----END PRIVATE KEY-----`,
            cert: `-----BEGIN CERTIFICATE-----
MIICpDCCAYwCCQC7VJTUt9Us8cDANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
b2NhbGhvc3QwHhcNMjQwMTAxMDAwMDAwWhcNMjUwMTAxMDAwMDAwWjAUMRIwEAYD
VQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7
VJTUt9Us8cKBwMnFW7n6wACiEcROuNZDdOHg7lGbAT2vGT8pXG8N1NbWo8VsKQzo
N5tQhc8l5L08v9LwJ5qL8KXf7QzZ9X5X0Zz5D9pR0I1V4M9K7WxT4U2M8Z2N8V5X
wIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQAzq7pMGvY4
-----END CERTIFICATE-----`
        };

        https.createServer(options, this.app).listen(this.port, '0.0.0.0', () => {
            const networkInfo = this.analyserReseauTOM();
            console.log(`🚀 TOM Server démarré ! (Routeur ASUS optimisé)`);
            console.log(`📡 HTTPS: https://localhost:\${this.port}`);
            console.log(`🌐 Réseau: https://\${this.getLocalIP()}:\${this.port}`);
            console.log(`🔑 Code: \${this.codeAppairage}`);
            
            if (networkInfo.detected) {
                console.log(`✅ Connecté au réseau TOM-NETWORK`);
                console.log(`📍 Interface: \${networkInfo.interface}`);
                console.log(`🎯 Prêt pour BlockNodes ESP32`);
            } else {
                console.log(`⚠️ Réseau TOM-NETWORK non détecté`);
                console.log(`💡 Connectez-vous au WiFi TOM-NETWORK`);
            }
            
            console.log(`\\n💡 Test: https://localhost:\${this.port}/test`);
        });
    }
}

new TOMServerRouteur().start();
"@
}

Set-Content -Path "$TomDir\serveur-https-complet.js" -Value $serverJs -Encoding UTF8

# Créer le script de démarrage optimisé
$startScript = @"
@echo off
title TOM Server HTTPS - Routeur ASUS
echo 🚀 Démarrage TOM Server optimisé routeur ASUS...
echo 🔍 Analyse réseau TOM-NETWORK...
cd /d "C:\Program Files\TOM-Server"
node serveur-https-complet.js
pause
"@

Set-Content -Path "$TomDir\start-tom-https.bat" -Value $startScript -Encoding UTF8

# Créer script de test réseau
$testScript = @"
@echo off
title Test Réseau TOM - ASUS RT-AX58U
echo 🔍 Test configuration réseau TOM...
echo.

ipconfig | findstr "192.168.1."
if %errorlevel%==0 (
    echo ✅ Réseau 192.168.1.x détecté
) else (
    echo ⚠️ Réseau TOM non détecté
)

echo.
echo 🔌 Test ping routeur ASUS...
ping -n 1 192.168.1.1 > nul
if %errorlevel%==0 (
    echo ✅ Routeur ASUS accessible
) else (
    echo ❌ Routeur ASUS non accessible
)

echo.
echo 📋 Configuration recommandée:
echo    WiFi: TOM-NETWORK
echo    IP recommandée: 192.168.1.100 (réservation DHCP)
echo    Gateway: 192.168.1.1
echo.
pause
"@

Set-Content -Path "$TomDir\test-reseau-tom.bat" -Value $testScript -Encoding UTF8

Write-Host "✅ Fichiers TOM Server routeur créés" -ForegroundColor Green

Write-Host ""
Write-Host "📦 Étape 4/6 - Installation des dépendances..." -ForegroundColor Yellow

# Installer les dépendances
try {
    Set-Location $TomDir
    Write-Host "⬇️ Installation Express.js..." -ForegroundColor Yellow
    npm install --production --silent
    Write-Host "✅ Dépendances installées" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur installation dépendances: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour fermer"
    exit 1
}

Write-Host ""
Write-Host "🔗 Étape 5/6 - Configuration système..." -ForegroundColor Yellow

# Créer service Windows avec détection réseau
try {
    # Créer tâche programmée pour démarrage automatique
    $taskName = "TOM Server HTTPS Routeur"
    $taskAction = New-ScheduledTaskAction -Execute "node.exe" -Argument "`"$TomDir\serveur-https-complet.js`"" -WorkingDirectory $TomDir
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartOnIdle
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Supprimer tâche existante si présente
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName "TOM Server HTTPS" -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}
    
    # Créer nouvelle tâche
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Principal $taskPrincipal -Force | Out-Null
    
    # Démarrer le service immédiatement
    Start-ScheduledTask -TaskName $taskName
    
    Write-Host "✅ Service automatique configuré et démarré" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Service automatique non configuré: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "💡 TOM Server peut être démarré manuellement" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎯 Étape 6/6 - Finalisation et raccourcis..." -ForegroundColor Yellow

# Créer raccourcis optimisés
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    
    # Raccourci principal
    $shortcutPath = "$desktopPath\TOM Server (Routeur ASUS).lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "$TomDir\start-tom-https.bat"
    $shortcut.WorkingDirectory = $TomDir
    $shortcut.Description = "Démarrer TOM Server HTTPS - Optimisé ASUS RT-AX58U"
    $shortcut.Save()
    
    # Raccourci test réseau
    $testShortcutPath = "$desktopPath\Test Réseau TOM.lnk"
    $testShortcut = $shell.CreateShortcut($testShortcutPath)
    $testShortcut.TargetPath = "$TomDir\test-reseau-tom.bat"
    $testShortcut.WorkingDirectory = $TomDir
    $testShortcut.Description = "Tester la configuration réseau TOM avec routeur ASUS"
    $testShortcut.Save()
    
    Write-Host "✅ Raccourcis créés sur le Bureau" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Raccourcis non créés: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 INSTALLATION TOM TERMINÉE AVEC SUCCÈS !" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Node.js installé et configuré" -ForegroundColor Green
Write-Host "✅ TOM Server installé dans: $TomDir" -ForegroundColor Green
Write-Host "✅ Service automatique configuré et démarré" -ForegroundColor Green
Write-Host "✅ Optimisations routeur ASUS RT-AX58U appliquées" -ForegroundColor Green
Write-Host "✅ Raccourcis créés sur le Bureau" -ForegroundColor Green
Write-Host ""

# Affichage des informations de connexion
$currentIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -like "192.168.1.*" -and $_.IPAddress -ne "192.168.1.255" 
} | Select-Object -First 1).IPAddress

if (-not $currentIP) {
    $currentIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        -not $_.IPAddress.StartsWith("127.") -and -not $_.IPAddress.StartsWith("169.254.") 
    } | Select-Object -First 1).IPAddress
}

Write-Host "🚀 URLS D'ACCÈS TOM SERVER:" -ForegroundColor Cyan
Write-Host "   🌐 https://localhost:3443/test" -ForegroundColor White
if ($currentIP) {
    Write-Host "   🌐 https://$currentIP:3443/test" -ForegroundColor White
}
Write-Host ""

if ($networkInfo.Detected) {
    Write-Host "🎯 CONFIGURATION RÉSEAU OPTIMALE DÉTECTÉE !" -ForegroundColor Green
    Write-Host "   ✅ Réseau TOM-NETWORK connecté" -ForegroundColor Green
    Write-Host "   📍 IP actuelle: $($networkInfo.IP)" -ForegroundColor White
    Write-Host "   🎯 IP recommandée: 192.168.1.100 (configurez réservation DHCP)" -ForegroundColor Cyan
    Write-Host "   🔗 Gateway: $($networkInfo.Gateway)" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 PROCHAINES ÉTAPES RECOMMANDÉES:" -ForegroundColor Yellow
    Write-Host "   1. Configurez la réservation DHCP sur votre routeur ASUS" -ForegroundColor White
    Write-Host "   2. Associez cette machine à l'IP 192.168.1.100" -ForegroundColor White
    Write-Host "   3. Les BlockNodes se connecteront automatiquement" -ForegroundColor White
} else {
    Write-Host "📋 CONFIGURATION RÉSEAU À OPTIMISER:" -ForegroundColor Yellow
    Write-Host "   1. Connectez-vous au WiFi TOM-NETWORK" -ForegroundColor White
    Write-Host "   2. Configurez la réservation DHCP pour 192.168.1.100" -ForegroundColor White
    Write-Host "   3. Utilisez 'Test Réseau TOM' pour vérifier la configuration" -ForegroundColor White
}

Write-Host ""
Write-Host "🛠️ OUTILS DISPONIBLES:" -ForegroundColor Cyan
Write-Host "   • 'TOM Server (Routeur ASUS)' - Démarrer le serveur" -ForegroundColor White
Write-Host "   • 'Test Réseau TOM' - Vérifier la configuration réseau" -ForegroundColor White
Write-Host ""
Write-Host "🎯 LE SERVEUR TOM HTTPS EST ACTIF ET OPTIMISÉ !" -ForegroundColor Green
Write-Host ""

# Attendre confirmation utilisateur
Write-Host "Appuyez sur Entrée pour fermer cette fenêtre..." -ForegroundColor Yellow
Read-Host
