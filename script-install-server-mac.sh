#!/bin/bash
# TOM Server - Installateur macOS ULTRA-SIMPLE
# URL: https://raw.githubusercontent.com/tom-modelisme-organisation/wikitom-communaute/main/script-install-server-mac.sh

set -e

clear
echo "🚀 TOM Server Installer - macOS"
echo "================================"
echo ""

# Variables
TOM_DIR="/Applications/TOM-Server"
USER_HOME="$HOME"

echo "📦 Étape 1/4 - Vérification Node.js..."

# Vérifier ou installer Node.js
if command -v node >/dev/null 2>&1; then
    NODE_CURRENT=$(node -v | sed 's/v//')
    echo "✅ Node.js déjà installé (version $NODE_CURRENT)"
else
    echo "📥 Installation Node.js..."
    cd /tmp
    curl -L -o nodejs.pkg https://nodejs.org/dist/v20.11.0/node-v20.11.0.pkg
    sudo installer -pkg nodejs.pkg -target /
    rm nodejs.pkg
    export PATH="/usr/local/bin:$PATH"
    echo "✅ Node.js installé"
fi

echo ""
echo "📂 Étape 2/4 - Création dossier TOM..."

sudo mkdir -p "$TOM_DIR"
sudo chown -R "$(whoami):staff" "$TOM_DIR"
chmod 755 "$TOM_DIR"

echo "✅ Dossier créé: $TOM_DIR"

echo ""
echo "📄 Étape 3/4 - Installation TOM Server..."

# Package.json
cat > "$TOM_DIR/package.json" << 'PACKAGE_EOF'
{
  "name": "tom-server-https",
  "version": "1.0.0",
  "main": "serveur-https-complet.js",
  "dependencies": {
    "express": "^4.18.2"
  }
}
PACKAGE_EOF

# Serveur HTTPS avec génération automatique de certificats
cat > "$TOM_DIR/serveur-https-complet.js" << 'SERVER_EOF'
const express = require('express');
const https = require('https');
const fs = require('fs');
const os = require('os');
const { execSync } = require('child_process');

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
            res.send(`
                <h1>🚀 TOM Server Actif!</h1>
                <p>Serveur HTTPS opérationnel sur port ${this.port}</p>
                <p>IP: ${this.getLocalIP()}</p>
                <p>Code d'appairage: <strong>${this.codeAppairage}</strong></p>
                <p><em>Installation TOM Server - macOS</em></p>
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
            // Générer certificats auto-signés avec OpenSSL
            execSync(`openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=localhost"`, { cwd: __dirname });
            console.log('✅ Certificats SSL générés');
            return true;
        } catch (error) {
            console.log('❌ Erreur génération certificats:', error.message);
            return false;
        }
    }

    start() {
        // Vérifier si les certificats existent, sinon les générer
        if (!fs.existsSync('key.pem') || !fs.existsSync('cert.pem')) {
            console.log('🔐 Génération des certificats SSL...');
            if (!this.genererCertificats()) {
                console.log('❌ Impossible de générer les certificats SSL');
                console.log('💡 Installe OpenSSL: brew install openssl');
                return;
            }
        }

        const options = {
            key: fs.readFileSync('key.pem'),
            cert: fs.readFileSync('cert.pem')
        };

        https.createServer(options, this.app).listen(this.port, '0.0.0.0', () => {
            console.log(`🚀 TOM Server démarré!`);
            console.log(`📡 HTTPS: https://localhost:${this.port}`);
            console.log(`🌐 Réseau: https://${this.getLocalIP()}:${this.port}`);
            console.log(`🔑 Code: ${this.codeAppairage}`);
            console.log(`\n💡 Test: https://localhost:${this.port}/test`);
            console.log(`🛑 Pour arrêter: Ctrl+C`);
        });
    }
}

new TOMServer().start();
SERVER_EOF

echo "✅ Fichiers TOM Server créés"

echo ""
echo "📦 Étape 4/4 - Installation finale..."

cd "$TOM_DIR"
npm install --production --silent

echo ""
echo "🎉 INSTALLATION TERMINÉE !"
echo "=========================="
echo ""
echo "🚀 Démarrage du serveur TOM..."

# Démarrer le serveur immédiatement
node serveur-https-complet.js &
SERVER_PID=$!

sleep 3
echo ""
echo "✅ TOM Server actif sur:"
echo "   🌐 https://localhost:3443/test"
echo "   🌐 https://$(ipconfig getifaddr en0 2>/dev/null || echo 'IP-LOCAL'):3443/test"
echo ""
echo "🎯 INSTALLATION RÉUSSIE !"
echo "🎯 Le serveur fonctionne maintenant !"
echo ""
echo "💡 Pour arrêter: kill $SERVER_PID"
echo ""