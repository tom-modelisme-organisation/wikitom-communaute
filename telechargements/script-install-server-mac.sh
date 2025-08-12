#!/bin/bash
# TOM Server - Installateur macOS COMPLET (HTTPS + HTTP Satellites)
# URL: https://raw.githubusercontent.com/tom-modelisme-organisation/wikitom-communaute/main/telechargements/scripts/install-server-mac.sh

set -e

clear
echo "🚀 TOM Server Installer COMPLET - macOS"
echo "========================================"
echo "Installation HTTPS (mobiles) + HTTP (BlockNodes)"
echo ""

# Variables
TOM_DIR="/Applications/TOM-Server"

echo "📦 Étape 1/5 - Vérification Node.js..."

if command -v node >/dev/null 2>&1; then
    NODE_CURRENT=$(node -v | sed 's/v//')
    echo "✅ Node.js déjà installé (version $NODE_CURRENT)"
else
    echo "📥 Installation Node.js..."
    echo ""
    echo "💡 INFORMATION IMPORTANTE :"
    echo "   Si tu ne vois pas ton mot de passe Mac s'afficher, c'est normal."
    echo "   Saisis-le et appuie sur Entrée."
    echo ""
    
    cd /tmp
    curl -L -o nodejs.pkg https://nodejs.org/dist/v20.11.0/node-v20.11.0.pkg
    sudo installer -pkg nodejs.pkg -target /
    rm nodejs.pkg
    export PATH="/usr/local/bin:$PATH"
    echo "✅ Node.js installé"
fi

echo ""
echo "📂 Étape 2/5 - Création dossier TOM..."

# Arrêter tous les serveurs TOM existants
echo "🛑 Arrêt des anciens serveurs TOM..."
pkill -f "serveur-https-complet" 2>/dev/null || true
pkill -f "serveur-https-local" 2>/dev/null || true
pkill -f "serveur-tom-satellites" 2>/dev/null || true
pkill -f "TOM-Server" 2>/dev/null || true
sleep 3

echo ""
echo "💡 INFORMATION IMPORTANTE :"
echo "   Si tu ne vois pas ton mot de passe Mac s'afficher, c'est normal."
echo "   Saisis-le et appuie sur Entrée."
echo ""

sudo mkdir -p "$TOM_DIR"
sudo chown -R "$(whoami):staff" "$TOM_DIR"

echo "✅ Dossier créé: $TOM_DIR"

echo ""
echo "📄 Étape 3/5 - Installation serveurs TOM..."

# Package.json unifié
cat > "$TOM_DIR/package.json" << 'PACKAGE_EOF'
{
  "name": "tom-servers-complete",
  "version": "1.0.0",
  "main": "start-tom-complete.js",
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  },
  "scripts": {
    "start": "node start-tom-complete.js",
    "https-only": "node serveur-https-complet.js",
    "satellites-only": "node serveur-tom-satellites.js"
  }
}
PACKAGE_EOF

# Serveur HTTPS (mobiles)
cat > "$TOM_DIR/serveur-https-complet.js" << 'HTTPS_EOF'
const express = require('express');
const https = require('https');
const fs = require('fs');
const os = require('os');
const { execSync } = require('child_process');

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
            res.send(`
                <h1>🚀 TOM HTTPS Server Actif!</h1>
                <p>Serveur HTTPS pour appareils mobiles</p>
                <p>Port: ${this.port}</p>
                <p>IP: ${this.getLocalIP()}</p>
                <p>Code d'appairage: <strong>${this.codeAppairage}</strong></p>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
                    h1 { color: #2c5aa0; }
                    p { margin: 10px 0; }
                    strong { color: #e74c3c; font-size: 1.2em; }
                </style>
            `);
        });
    }

    getLocalIP() {
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

    genererCertificats() {
        try {
            console.log('🔐 Génération des certificats SSL...');
            execSync(`openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=localhost"`, { 
                cwd: __dirname,
                stdio: ['inherit', 'pipe', 'pipe']
            });
            console.log('✅ Certificats SSL générés');
            return true;
        } catch (error) {
            console.log('❌ Erreur génération certificats');
            return false;
        }
    }

    async start() {
        try {
            if (!fs.existsSync('key.pem') || !fs.existsSync('cert.pem')) {
                if (!this.genererCertificats()) {
                    throw new Error('Impossible de générer les certificats');
                }
            }

            const options = {
                key: fs.readFileSync('key.pem'),
                cert: fs.readFileSync('cert.pem')
            };

            const server = https.createServer(options, this.app);
            
            server.listen(this.port, '0.0.0.0', () => {
                console.log(`🚀 TOM HTTPS Server démarré!`);
                console.log(`📡 HTTPS: https://localhost:${this.port}`);
                console.log(`🌐 Réseau: https://${this.getLocalIP()}:${this.port}`);
                console.log(`🔑 Code: ${this.codeAppairage}`);
                console.log(`📱 Pour: Tablettes et smartphones`);
            });

        } catch (error) {
            console.log('❌ Erreur HTTPS:', error.message);
        }
    }
}

module.exports = TOMServerHTTPS;

if (require.main === module) {
    new TOMServerHTTPS().start();
}
HTTPS_EOF

# Serveur HTTP Satellites (BlockNodes)
cat > "$TOM_DIR/serveur-tom-satellites.js" << 'HTTP_EOF'
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

                console.log(`[SATELLITE] Canton ${data.canton}: Train=${data.data.train_present}, Courant=${data.data.current_ma}mA`);
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
                console.log(`[EVENT] Canton ${data.canton}: ${data.event}`);
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
                name: data.name || `BlockNode-${canton}`,
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
        console.log(`📡 [EVENT] Canton ${canton}: ${event}`);
        
        this.updateSatellite(canton, {
            last_event: event,
            last_event_time: timestamp
        });
    }

    start() {
        this.app.listen(this.port, '0.0.0.0', () => {
            console.log(`🛰️ TOM Satellite Server démarré!`);
            console.log(`📡 HTTP: http://localhost:${this.port}`);
            console.log(`🌐 API: http://localhost:${this.port}/api/status`);
            console.log(`🔧 Pour: BlockNodes ESP32`);
        });
    }
}

module.exports = TOMSatelliteServer;

if (require.main === module) {
    new TOMSatelliteServer().start();
}
HTTP_EOF

# Serveur de démarrage unifié
cat > "$TOM_DIR/start-tom-complete.js" << 'START_EOF'
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
START_EOF

echo "✅ Fichiers serveurs créés"

echo ""
echo "📦 Étape 4/5 - Installation dépendances..."

cd "$TOM_DIR"
npm install --production --silent

echo "✅ Dépendances installées"

echo ""
echo "🔧 Étape 5/5 - Configuration service automatique..."

# Créer script de démarrage
cat > "$TOM_DIR/start-tom.sh" << 'SCRIPT_EOF'
#!/bin/bash
cd "/Applications/TOM-Server"
node start-tom-complete.js
SCRIPT_EOF

chmod +x "$TOM_DIR/start-tom.sh"

# Créer plist pour LaunchAgent (démarrage auto)
PLIST_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$PLIST_DIR"

cat > "$PLIST_DIR/com.tom.servers.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tom.servers</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/TOM-Server/start-tom.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/tom-servers.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/tom-servers.err</string>
</dict>
</plist>
PLIST_EOF

# Charger et démarrer le service
launchctl unload "$PLIST_DIR/com.tom.servers.plist" 2>/dev/null || true
launchctl load "$PLIST_DIR/com.tom.servers.plist"
launchctl start com.tom.servers

echo "✅ Service automatique configuré"

echo ""
echo "🎉 INSTALLATION TERMINÉE !"
echo "=========================="
echo ""
echo "🚀 Démarrage des serveurs TOM..."
echo ""
echo "💡 INFORMATION : Deux serveurs sont installés :"
echo "   📱 HTTPS (port 3444) pour mobiles"
echo "   🛰️ HTTP (port 3001) pour BlockNodes"
echo ""

# Attendre que les serveurs démarrent
sleep 5

echo "✅ Installation TOM Server COMPLÈTE !"
echo ""
echo "🎯 URLS D'ACCÈS :"
echo "   📱 HTTPS Mobile: https://localhost:3444/test"
echo "   🛰️ HTTP Satellites: http://localhost:3001/api/status"
echo ""
echo "🔄 Les serveurs se relancent automatiquement au démarrage du Mac"
echo "🔧 Logs disponibles dans /tmp/tom-servers.out"
