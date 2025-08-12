# Dans script-install-server-windows.ps1, remplacer la section serveur par :

# Arrêt forcé des processus sur le port 3444 et serveurs TOM
Write-Host ""
Write-Host "🛑 Arrêt des anciens serveurs TOM et libération du port 3444..." -ForegroundColor Yellow

# Tuer les processus TOM
try {
    Get-Process | Where-Object {$_.ProcessName -like "*node*" -and $_.CommandLine -like "*tom*"} | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process | Where-Object {$_.ProcessName -like "*node*" -and $_.CommandLine -like "*serveur*"} | Stop-Process -Force -ErrorAction SilentlyContinue
} catch {}

# Libérer le port 3444 spécifiquement
try {
    $processOnPort = Get-NetTCPConnection -LocalPort 3444 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess
    if ($processOnPort) {
        Stop-Process -Id $processOnPort -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Port 3444 libéré" -ForegroundColor Green
    }
} catch {
    Write-Host "ℹ️ Port 3444 déjà libre" -ForegroundColor Yellow
}

Start-Sleep -Seconds 2

# Créer le serveur HTTPS TOM avec PORT FIXE
$serverJs = @"
const express = require('express');
const https = require('https');
const os = require('os');

class TOMServer {
    constructor() {
        this.port = 3444; // PORT FIXE !
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
                <p><em>Installation TOM Server via PowerShell - Windows - Port Fixe</em></p>
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
        console.log(\`🔍 Démarrage serveur TOM sur port fixe \${this.port}...\`);
        
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

        const server = https.createServer(options, this.app);
        
        server.on('error', (err) => {
            if (err.code === 'EADDRINUSE') {
                console.log(\`❌ Port \${this.port} encore occupé - Redémarrage requis\`);
                process.exit(1);
            } else {
                console.log('❌ Erreur serveur:', err.message);
                process.exit(1);
            }
        });

        server.listen(this.port, '0.0.0.0', () => {
            console.log(\`🚀 TOM Server démarré sur PORT FIXE !\`);
            console.log(\`📡 HTTPS: https://localhost:\${this.port}\`);
            console.log(\`🌐 Réseau: https://\${this.getLocalIP()}:\${this.port}\`);
            console.log(\`🔑 Code: \${this.codeAppairage}\`);
            console.log(\`\\n💡 Test: https://localhost:\${this.port}/test\`);
            console.log(\`🛑 Pour arrêter: Ctrl+C\`);
        });
    }
}

new TOMServer().start();
"@

Set-Content -Path "$TomDir\serveur-https-complet.js" -Value $serverJs -Encoding UTF8
