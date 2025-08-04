#!/bin/bash
# TOM Server - Installateur macOS avec port automatique
# URL: https://raw.githubusercontent.com/tom-modelisme-organisation/wikitom-communaute/main/script-install-server-mac.sh

set -e

clear
echo "🚀 TOM Server Installer - macOS"
echo "================================"
echo ""

# Variables
TOM_DIR="/Applications/TOM-Server"

echo "📦 Étape 1/4 - Vérification Node.js..."

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

# Arrêter tous les anciens serveurs Node.js
pkill -f "node.*serveur-https" 2>/dev/null || true
pkill -f "node.*TOM" 2>/dev/null || true

sudo mkdir -p "$TOM_DIR"
sudo chown -R "$(whoami):staff" "$TOM_DIR"

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

# Serveur HTTPS avec détection automatique de port libre
cat > "$TOM_DIR/serveur-https-complet.js" << 'SERVER_EOF'
const express = require('express');
const https = require('https');
const fs = require('fs');
const os = require('os');
const net = require('net');
const { execSync } = require('child_process');

class TOMServer {
    constructor() {
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

    async trouverPortLibre(startPort = 3443) {
        for (let port = startPort; port < startPort + 10; port++) {
            if (await this.isPortFree(port)) {
                return port;
            }
        }
        throw new Error('Aucun port libre trouvé');
    }

    isPortFree(port) {
        return new Promise((resolve) => {
            const server = net.createServer();
            server.listen(port, () => {
                server.once('close', () => resolve(true));
                server.close();
            });
            server.on('error', () => resolve(false));
        });
    }

    genererCertificats() {
        try {
            execSync(`openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=localhost"`, { cwd: __dirname });
            console.log('✅ Certificats SSL générés');
            return true;
        } catch (error) {
            console.log('❌ Erreur génération certificats');
            return false;
        }
    }

    async start() {
        // Trouver un port libre
        this.port = await this.trouverPortLibre(3443);
        console.log(`🔍 Port libre trouvé: ${this.port}`);

        // Générer certificats si nécessaires
        if (!fs.existsSync('key.pem') || !fs.existsSync('cert.pem')) {
            console.log('🔐 Génération des certificats SSL...');
            if (!this.genererCertificats()) {
                console.log('❌ Impossible de générer les certificats');
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

new TOMServer().start().catch(console.error);
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

# Démarrer le serveur
node serveur-https-complet.js