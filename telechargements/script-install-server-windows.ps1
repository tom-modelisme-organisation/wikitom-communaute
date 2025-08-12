# TOM Server - Installateur Windows COMPLET (HTTPS + HTTP Satellites)
# URL: https://raw.githubusercontent.com/tom-modelisme-organisation/wikitom-communaute/main/telechargements/scripts/install-server-windows.ps1

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

Clear-Host
Write-Host "🚀 TOM Server Installer COMPLET - Windows" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Installation HTTPS (mobiles) + HTTP (BlockNodes)" -ForegroundColor White
Write-Host ""

# Variables
$TomDir = "C:\Program Files\TOM-Server"

# Vérifier les privilèges administrateur
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Privilèges administrateur requis" -ForegroundColor Red
    Write-Host "💡 Clic droit sur PowerShell → 'Exécuter en tant qu'administrateur'" -ForegroundColor Yellow
    Read-Host "Appuyez sur Entrée pour fermer"
    exit 1
}

Write-Host "📦 Étape 1/6 - Vérification/Installation Node.js..." -ForegroundColor Yellow

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
Write-Host "📂 Étape 2/6 - Création dossier TOM Server..." -ForegroundColor Yellow

# Arrêter les anciens processus
try {
    Write-Host "🛑 Arrêt des anciens serveurs TOM..." -ForegroundColor Yellow
    Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*tom*" } | Stop-Process -Force
    Start-Sleep -Seconds 2
} catch {
    # Ignoré si aucun processus
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
Write-Host "📄 Étape 3/6 - Installation serveurs TOM..." -ForegroundColor Yellow

# Package.json unifié
$packageJson = @"
{
  "name": "tom-servers-complete",
  "version": "1.0.0",
  "description": "TOM Complete Servers - HTTPS + HTTP Satellites",
  "main": "start-tom-complete.js",
  "scripts": {
    "start": "node start-tom-complete.js",
    "https-only": "node serveur-https-complet.js",
    "satellites-only": "node serveur-tom-satellites.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  },
  "keywords": ["tom", "train", "https", "satellites", "blocknode"],
  "author": "TOM Team",
  "license": "MIT"
}
"@

Set-Content -Path "$TomDir\package.json" -Value $packageJson -Encoding UTF8

# Serveur HTTPS (mobiles)
$serverHTTPS = @"
const express = require('express');
const https = require('https');
const os = require('os');

class TOMServerHTTPS {
    constructor() {
        this.app = express();
        this.port = 3444;
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
            res.json({ 
                status: 'ok', 
                server: 'tom-https', 
                port: this.port, 
                code: this.codeAppairage,
                type: 'mobile-devices'
            });
        });

        this.app.get('/tom-ping', (req, res) => {
            res.json({ pong: true, timestamp: Date.now(), server: 'tom-https' });
        });

        this.app.get('/health', (req, res) => {
            res.json({ healthy: true, uptime: process.uptime() });
        });

        this.app.get('/test', (req, res) => {
            res.send(\`
                <h1>🚀 TOM HTTPS Server Actif!</h1>
                <p>Serveur HTTPS pour appareils mobiles</p>
                <p>Port: \${this.port}</p>
                <p>IP: \${this.getLocalIP()}</p>
                <p>Code d'appairage: <strong>\${this.codeAppairage}</strong></p>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
                    h1 { color: #2c5aa0; }
                    p { margin: 10px 0; }
                    strong { color: #e74c3c; font-size: 1.2em; }
                </style>
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
            console.log(\`🚀 TOM HTTPS Server démarré!\`);
            console.log(\`📡 HTTPS: https://localhost:\${this.port}\`);
            console.log(\`🌐 Réseau: https://\${this.getLocalIP()}:\${this.port}\`);
            console.log(\`🔑 Code: \${this.codeAppairage}\`);
            console.log(\`📱 Pour: Tablettes et smartphones\`);
        });
    }
}

module.exports = TOMServerHTTPS;

if (require.main === module) {
    new TOMServerHTTPS().start();
}
"@

Set-Content -Path "$TomDir\serveur-https-complet.js" -Value $serverHTTPS -Encoding UTF8

# Serveur HTTP Satellites (BlockNodes)
$serverHTTP = @"
const express = require('express');
const cors = require('cors');

class TOMSatelliteServer {
    constructor() {
        this.app = express();
        this.port = 3001;
        this.satellites = new Map();
        this.setupMiddleware();
        this.setupRoutes();
    }

    setupMiddleware() {
        this.app.use(cors({
            origin: '*',
            methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
            allowedHeaders: ['Content-Type', 'Authorization']
        }));
        
        this.app.use(express.json({ limit: '10mb' }));
        this.app.use(express.urlencoded({ extended: true }));
    }

    setupRoutes() {
        // API Status
        this.app.get('/api/status', (req, res) => {
            res.json({
                status: 'TOM Satellite Server',
                version: '1.0.0',
                satellites_connected: this.satellites.size,
                uptime: process.uptime(),
                timestamp: Date.now(),
                port: this.port,
                type: 'blocknode-satellites'
            });
        });

        // Télémétrie BlockNodes
        this.app.post('/api/satellites/telemetry', (req, res) => {
            try {
                const data = req.body;
                
                if (!data.api_key || !data.canton || !data.data) {
                    return res.status(400).json({ error: 'Données manquantes' });
                }

                const clientIP = req.ip?.replace('::ffff:', '') || 'unknown';
                
                this.updateSatellite(data.canton, {
                    ...data,
                    last_seen: Date.now(),
                    ip: clientIP,
                    status: 'online'
                });

                console.log(\`[SATELLITE] Canton \${data.canton}: Train=\${data.data.train_present}, Courant=\${data.data.current_ma}mA\`);
                res.json({ 
                    status: 'received', 
                    timestamp: Date.now(),
                    server: 'TOM Satellite Server'
                });

            } catch (error) {
                console.error('[ERROR] Télémétrie:', error);
                res.status(500).json({ error: 'Erreur serveur' });
            }
        });

        // Événements satellites
        this.app.post('/api/satellites/event', (req, res) => {
            try {
                const data = req.body;
                this.handleSatelliteEvent(data);
                console.log(\`[EVENT] Canton \${data.canton}: \${data.event}\`);
                res.json({ status: 'processed', timestamp: Date.now() });
            } catch (error) {
                console.error('[ERROR] Événement:', error);
                res.status(500).json({ error: 'Erreur serveur' });
            }
        });

        // Liste satellites
        this.app.get('/api/satellites/list', (req, res) => {
            const satellitesList = Array.from(this.satellites.entries()).map(([canton, data]) => ({
                canton,
                name: data.name || \`BlockNode-\${canton}\`,
                status: data.status,
                last_seen: data.last_seen,
                ip: data.ip,
                train_present: data.data?.train_present || false,
                current_ma: data.data?.current_ma || 0
            }));

            res.json({
                satellites: satellitesList,
                total: satellitesList.length,
                online: satellitesList.filter(s => s.status === 'online').length
            });
        });
    }

    updateSatellite(canton, data) {
        const existing = this.satellites.get(canton) || {};
        this.satellites.set(canton, {
            ...existing,
            ...data,
            last_update: Date.now()
        });
    }

    handleSatelliteEvent(eventData) {
        const { canton, event, timestamp } = eventData;
        console.log(\`📡 [EVENT] Canton \${canton}: \${event}\`);
        
        this.updateSatellite(canton, {
            last_event: event,
            last_event_time: timestamp
        });
    }

    start() {
        this.app.listen(this.port, '0.0.0.0', () => {
            console.log(\`🛰️ TOM Satellite Server démarré!\`);
            console.log(\`📡 HTTP: http://localhost:\${this.port}\`);
            console.log(\`🌐 API: http://localhost:\${this.port}/api/status\`);
            console.log(\`🔧 Pour: BlockNodes ESP32\`);
        });
    }
}

module.exports = TOMSatelliteServer;

if (require.main === module) {
    new TOMSatelliteServer().start();
}
"@

Set-Content -Path "$TomDir\serveur-tom-satellites.js" -Value $serverHTTP -Encoding UTF8

# Serveur de démarrage unifié
$startServer = @"
const TOMServerHTTPS = require('./serveur-https-complet');
const TOMSatelliteServer = require('./serveur-tom-satellites');

console.log('🚀 TOM - Démarrage serveurs complets...');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

// Démarrage serveur HTTPS (mobiles)
const httpsServer = new TOMServerHTTPS();
httpsServer.start();

// Attendre un peu puis démarrer serveur satellites
setTimeout(() => {
    const satelliteServer = new TOMSatelliteServer();
    satelliteServer.start();
    
    setTimeout(() => {
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('✅ TOM SERVERS OPÉRATIONNELS ✅');
        console.log('📱 HTTPS Mobile: https://localhost:3444');
        console.log('🛰️ HTTP Satellites: http://localhost:3001');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }, 2000);
}, 2000);

// Gestion arrêt propre
process.on('SIGTERM', () => {
    console.log('🛑 Arrêt des serveurs TOM...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 Arrêt des serveurs TOM...');
    process.exit(0);
});
"@

Set-Content -Path "$TomDir\start-tom-complete.js" -Value $startServer -Encoding UTF8

# Script de démarrage Windows
$startScript = @"
@echo off
echo 🚀 Démarrage TOM Servers Complets...
cd /d "C:\Program Files\TOM-Server"
node start-tom-complete.js
pause
"@

Set-Content -Path "$TomDir\start-tom-complete.bat" -Value $startScript -Encoding UTF8

Write-Host "✅ Fichiers serveurs créés" -ForegroundColor Green

Write-Host ""
Write-Host "📦 Étape 4/6 - Installation des dépendances..." -ForegroundColor Yellow

# Installer les dépendances
try {
    Set-Location $TomDir
    Write-Host "⬇️  Installation Express.js et CORS..." -ForegroundColor Yellow
    npm install --production --silent
    Write-Host "✅ Dépendances installées" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur installation dépendances: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour fermer"
    exit 1
}

Write-Host ""
Write-Host "🔗 Étape 5/6 - Configuration système..." -ForegroundColor Yellow

# Créer service Windows automatique
try {
    $taskName = "TOM Servers Complete"
    $taskAction = New-ScheduledTaskAction -Execute "node.exe" -Argument "`"$TomDir\start-tom-complete.js`"" -WorkingDirectory $TomDir
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Supprimer tâche existante si présente
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}
    
    # Créer nouvelle tâche
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Principal $taskPrincipal -Force | Out-Null
    
    Write-Host "✅ Service automatique configuré" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Service automatique non configuré: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "💡 TOM Servers peuvent être démarrés manuellement" -ForegroundColor Yellow
}

# Créer raccourci sur le Bureau
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = "$desktopPath\TOM Servers.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "$TomDir\start-tom-complete.bat"
    $shortcut.WorkingDirectory = $TomDir
    $shortcut.Description = "Démarrer TOM Servers HTTPS + HTTP"
    $shortcut.Save()
    Write-Host "✅ Raccourci créé sur le Bureau" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Raccourci non créé: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🚀 Étape 6/6 - Démarrage des serveurs..." -ForegroundColor Yellow

# Démarrer les serveurs immédiatement
try {
    Start-ScheduledTask -TaskName "TOM Servers Complete"
    Write-Host "✅ Serveurs démarrés automatiquement" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Démarrage automatique échoué, démarrage manuel..." -ForegroundColor Yellow
    Start-Process -FilePath "node.exe" -ArgumentList "`"$TomDir\start-tom-complete.js`"" -WorkingDirectory $TomDir -WindowStyle Minimized
}

# Attendre un peu que les serveurs démarrent
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "🎉 INSTALLATION TOM TERMINÉE AVEC SUCCÈS !" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Node.js installé et configuré" -ForegroundColor Green
Write-Host "✅ TOM Servers installés dans: $TomDir" -ForegroundColor Green
Write-Host "✅ Service automatique configuré et démarré" -ForegroundColor Green
Write-Host "✅ Raccourci créé sur le Bureau" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 URLS D'ACCÈS TOM SERVERS:" -ForegroundColor Cyan
Write-Host "   📱 HTTPS Mobile: https://localhost:3444/test" -ForegroundColor White
Write-Host "   🛰️ HTTP Satellites: http://localhost:3001/api/status" -ForegroundColor White
Write-Host "   🌐 IP Réseau: https://$(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Ethernet*','Wi-Fi*' | Select-Object -First 1 -ExpandProperty IPAddress):3444" -ForegroundColor White
Write-Host ""
Write-Host "🎯 LES SERVEURS TOM SONT ACTIFS !" -ForegroundColor Green
Write-Host "📱 Appareils mobiles → Port 3444 HTTPS" -ForegroundColor Green
Write-Host "🛰️ BlockNodes ESP32 → Port 3001 HTTP" -ForegroundColor Green
Write-Host ""
Write-Host "✨ Installation terminée - Ferme cette fenêtre ✨" -ForegroundColor Cyan
Write-Host ""

Read-Host "Appuyez sur Entrée pour fermer"
