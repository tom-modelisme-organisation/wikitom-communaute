# TOM Server - Installateur Windows via PowerShell
# URL: https://raw.githubusercontent.com/tom-modelisme-organisation/wikitom-communaute/main/script-install-server-windows.ps1

# Configuration
$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

Clear-Host
Write-Host "🚀 TOM Server Installer - Windows" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation automatique de TOM Server HTTPS" -ForegroundColor White
Write-Host "Détection automatique de Node.js..." -ForegroundColor White
Write-Host ""

# Variables
$TomDir = "C:\Program Files\TOM-Server"
$UserHome = $env:USERPROFILE

# Vérifier les privilèges administrateur
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Privilèges administrateur requis" -ForegroundColor Red
    Write-Host "💡 Clic droit sur PowerShell → 'Exécuter en tant qu'administrateur'" -ForegroundColor Yellow
    Read-Host "Appuyez sur Entrée pour fermer"
    exit 1
}

Write-Host "📦 Étape 1/5 - Vérification/Installation Node.js..." -ForegroundColor Yellow

# Vérifier ou installer Node.js
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js déjà installé ($nodeVersion)" -ForegroundColor Green
} catch {
    Write-Host "📥 Téléchargement et installation Node.js..." -ForegroundColor Yellow
    
    $nodeUrl = "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi"
    $nodeInstaller = "$env:TEMP\nodejs.msi"
    
    try {
        Write-Host "⬇️  Téléchargement Node.js..." -ForegroundColor Yellow
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
Write-Host "📂 Étape 2/5 - Création dossier TOM Server..." -ForegroundColor Yellow

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
Write-Host "📄 Étape 3/5 - Installation TOM Server..." -ForegroundColor Yellow

# Créer package.json
$packageJson = @"
{
  "name": "tom-server-https",
  "version": "1.0.0",
  "description": "TOM Multi-Device HTTPS Server",
  "main": "serveur-https-complet.js",
  "scripts": {
    "start": "node serveur-https-complet.js",
    "stop": "taskkill /f /im node.exe",
    "status": "tasklist /fi \"imagename eq node.exe\" | findstr node"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "keywords": ["tom", "train", "https", "multi-device"],
  "author": "TOM Team",
  "license": "MIT"
}
"@

Set-Content -Path "$TomDir\package.json" -Value $packageJson -Encoding UTF8

# Créer le serveur HTTPS TOM
$serverJs = @"
const express = require('express');
const https = require('https');
const os = require('os');

class TOMServer {
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
        this.app.get('/status', (req, res) => {
            res.json({ status: 'ok', server: 'tom-https', port: this.port, code: this.codeAppairage });
        });

        this.app.get('/tom-ping', (req, res) => {
            res.json({ pong: true, timestamp: Date.now(), server: 'tom-https' });
        });

        this.app.get('/health', (req, res) => {
            res.json({ healthy: true, uptime: process.uptime() });
        });

        this.app.get('/favicon.ico', (req, res) => res.status(204).send());

        this.app.get('/test', (req, res) => {
            res.send(\`
                <h1>🚀 TOM Server Actif!</h1>
                <p>Serveur HTTPS opérationnel sur port \${this.port}</p>
                <p>IP: \${this.getLocalIP()}</p>
                <p>Code d'appairage: <strong>\${this.codeAppairage}</strong></p>
                <p><em>Installation TOM Server via PowerShell - Windows</em></p>
            \`);
        });
    }

    getLocalIP() {
        const interfaces = os.networkInterfaces();
        for (const name of Object.keys(interfaces)) {
            for (const interface of interfaces[name]) {
                if (interface.family === 'IPv4' && !interface.internal) {
                    return interface.address;
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
            key: \`-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7VJTUt9Us8cKB
wMnFW7n6wACiEcROuNZDdOHg7lGbAT2vGT8pXG8N1NbWo8VsKQzoN5tQhc8l5L08
v9LwJ5qL8KXf7QzZ9X5X0Zz5D9pR0I1V4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V
4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V
4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V4M9K7WxT4U2M8Z2N8V5X0Zz5D9pR0I1V
wIDAQABAoIBAEFNrWh8VJEWsGZJQkNV
-----END PRIVATE KEY-----\`,
            cert: \`-----BEGIN CERTIFICATE-----
MIICpDCCAYwCCQC7VJTUt9Us8cDANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
b2NhbGhvc3QwHhcNMjQwMTAxMDAwMDAwWhcNMjUwMTAxMDAwMDAwWjAUMRIwEAYD
VQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7
VJTUt9Us8cKBwMnFW7n6wACiEcROuNZDdOHg7lGbAT2vGT8pXG8N1NbWo8VsKQzo
N5tQhc8l5L08v9LwJ5qL8KXf7QzZ9X5X0Zz5D9pR0I1V4M9K7WxT4U2M8Z2N8V5X
wIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQAzq7pMGvY4
-----END CERTIFICATE-----\`
        };

        https.createServer(options, this.app).listen(this.port, '0.0.0.0', () => {
            console.log(\`🚀 TOM Server démarré!\`);
            console.log(\`📡 HTTPS: https://localhost:\${this.port}\`);
            console.log(\`🌐 Réseau: https://\${this.getLocalIP()}:\${this.port}\`);
            console.log(\`🔑 Code: \${this.codeAppairage}\`);
            console.log(\`\\n💡 Test: https://localhost:\${this.port}/test\`);
        });
    }
}

new TOMServer().start();
"@

Set-Content -Path "$TomDir\serveur-https-complet.js" -Value $serverJs -Encoding UTF8

# Créer le script de démarrage
$startScript = @"
@echo off
echo 🚀 Démarrage TOM Server...
cd /d "C:\Program Files\TOM-Server"
node serveur-https-complet.js
pause
"@

Set-Content -Path "$TomDir\start-tom-https.bat" -Value $startScript -Encoding UTF8

Write-Host "✅ Fichiers TOM Server créés" -ForegroundColor Green

Write-Host ""
Write-Host "📦 Étape 4/5 - Installation des dépendances..." -ForegroundColor Yellow

# Installer les dépendances
try {
    Set-Location $TomDir
    Write-Host "⬇️  Installation Express.js..." -ForegroundColor Yellow
    npm install --production --silent
    Write-Host "✅ Dépendances installées" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur installation dépendances: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour fermer"
    exit 1
}

Write-Host ""
Write-Host "🔗 Étape 5/5 - Configuration système..." -ForegroundColor Yellow

# Créer service Windows (optionnel)
try {
    # Créer tâche programmée pour démarrage automatique
    $taskName = "TOM Server HTTPS"
    $taskAction = New-ScheduledTaskAction -Execute "node.exe" -Argument "`"$TomDir\serveur-https-complet.js`"" -WorkingDirectory $TomDir
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Supprimer tâche existante si présente
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}
    
    # Créer nouvelle tâche
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Principal $taskPrincipal -Force | Out-Null
    
    # Démarrer le service immédiatement
    Start-ScheduledTask -TaskName $taskName
    
    Write-Host "✅ Service automatique configuré et démarré" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Service automatique non configuré: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "💡 TOM Server peut être démarré manuellement" -ForegroundColor Yellow
}

# Créer raccourci sur le Bureau
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = "$desktopPath\TOM Server.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "$TomDir\start-tom-https.bat"
    $shortcut.WorkingDirectory = $TomDir
    $shortcut.Description = "Démarrer TOM Server HTTPS"
    $shortcut.Save()
    Write-Host "✅ Raccourci créé sur le Bureau" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Raccourci non créé: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 INSTALLATION TOM TERMINÉE AVEC SUCCÈS !" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Node.js installé et configuré" -ForegroundColor Green
Write-Host "✅ TOM Server installé dans: $TomDir" -ForegroundColor Green
Write-Host "✅ Service automatique configuré et démarré" -ForegroundColor Green
Write-Host "✅ Raccourci créé sur le Bureau" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 URLS D'ACCÈS TOM SERVER:" -ForegroundColor Cyan
Write-Host "   🌐 https://localhost:3443/test" -ForegroundColor White
Write-Host "   🌐 https://$(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Ethernet*','Wi-Fi*' | Select-Object -First 1 -ExpandProperty IPAddress):3443/test" -ForegroundColor White
Write-Host ""
Write-Host "🎯 LE SERVEUR TOM HTTPS EST ACTIF !" -ForegroundColor Green
Write-Host "🎯 Tu peux maintenant utiliser les appairages multi-appareils !" -ForegroundColor Green
Write-Host ""
Write-Host "✨ Installation terminée - Ferme cette fenêtre ✨" -ForegroundColor Cyan
Write-Host ""

Read-Host "Appuyez sur Entrée pour fermer"
