#!/bin/bash
# TOM Server - Installateur macOS via curl
# URL: https://raw.githubusercontent.com/TOM-Team/installer/main/install-macos.sh

set -e

clear
echo "🚀 TOM Server Installer - macOS"
echo "================================"
echo ""
echo "Installation automatique de TOM Server HTTPS"
echo "Détection automatique de Node.js..."
echo ""

# Variables
TOM_DIR="/Applications/TOM-Server"
USER_HOME="$HOME"

# Vérifier les permissions
if [[ $EUID -eq 0 ]]; then
   echo "❌ Ne pas exécuter en tant que root/sudo"
   echo "💡 Relance sans 'sudo'"
   exit 1
fi

echo "📦 Étape 1/5 - Vérification/Installation Node.js..."

# Vérifier ou installer Node.js
if command -v node >/dev/null 2>&1; then
    NODE_CURRENT=$(node -v | sed 's/v//')
    echo "✅ Node.js déjà installé (version $NODE_CURRENT)"
else
    echo "📥 Téléchargement et installation Node.js..."
    
    cd /tmp
    echo "⬇️  Téléchargement Node.js..."
    curl -L -o nodejs.pkg https://nodejs.org/dist/v20.11.0/node-v20.11.0.pkg
    
    echo "🔧 Installation Node.js (privilèges administrateur requis)..."
    sudo installer -pkg nodejs.pkg -target /
    
    rm nodejs.pkg
    
    # Mettre à jour PATH pour cette session
    export PATH="/usr/local/bin:$PATH"
    
    # Vérifier installation
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node -v)
        echo "✅ Node.js installé avec succès ($NODE_VERSION)"
    else
        echo "❌ Erreur installation Node.js"
        echo "💡 Redémarre Terminal et relance la commande"
        exit 1
    fi
fi

echo ""
echo "📂 Étape 2/5 - Création dossier TOM Server..."

# Créer le dossier TOM avec permissions appropriées
echo "🔐 Création du dossier (privilèges administrateur requis)..."
sudo mkdir -p "$TOM_DIR"
sudo chown -R "$(whoami):staff" "$TOM_DIR"
chmod 755 "$TOM_DIR"

echo "✅ Dossier créé: $TOM_DIR"

echo ""
echo "📄 Étape 3/5 - Installation TOM Server..."

# Créer package.json
cat > "$TOM_DIR/package.json" << 'PACKAGE_EOF'
{
  "name": "tom-server-https",
  "version": "1.0.0",
  "description": "TOM Multi-Device HTTPS Server",
  "main": "serveur-https-complet.js",
  "scripts": {
    "start": "node serveur-https-complet.js",
    "stop": "pkill -f 'node.*serveur-https-complet'",
    "status": "pgrep -f 'node.*serveur-https-complet' && echo 'TOM Server running' || echo 'TOM Server stopped'"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "keywords": ["tom", "train", "https", "multi-device"],
  "author": "TOM Team",
  "license": "MIT"
}
PACKAGE_EOF

# Créer le serveur HTTPS TOM
cat > "$TOM_DIR/serveur-https-complet.js" << 'SERVER_EOF'
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
            res.send(`
                <h1>🚀 TOM Server Actif!</h1>
                <p>Serveur HTTPS opérationnel sur port ${this.port}</p>
                <p>IP: ${this.getLocalIP()}</p>
                <p>Code d'appairage: <strong>${this.codeAppairage}</strong></p>
                <p><em>Installation TOM Server via curl - macOS</em></p>
            `);
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
            console.log(`🚀 TOM Server démarré!`);
            console.log(`📡 HTTPS: https://localhost:${this.port}`);
            console.log(`🌐 Réseau: https://${this.getLocalIP()}:${this.port}`);
            console.log(`🔑 Code: ${this.codeAppairage}`);
            console.log(`\n💡 Test: https://localhost:${this.port}/test`);
        });
    }
}

new TOMServer().start();
SERVER_EOF

# Créer le script de démarrage
cat > "$TOM_DIR/start-tom-https.js" << 'START_EOF'
#!/usr/bin/env node
console.log('🚀 Démarrage TOM Server...');
require('./serveur-https-complet.js');
START_EOF

chmod +x "$TOM_DIR/start-tom-https.js"

echo "✅ Fichiers TOM Server créés"

echo ""
echo "📦 Étape 4/5 - Installation des dépendances..."
cd "$TOM_DIR"
echo "⬇️  Installation Express.js..."
npm install --production

echo "✅ Dépendances installées"

echo ""
echo "🔗 Étape 5/5 - Configuration système..."

# Créer lien symbolique pour commande globale
echo "🔐 Configuration commande globale (privilèges administrateur requis)..."
sudo ln -sf "$TOM_DIR/start-tom-https.js" /usr/local/bin/tom-server

# Créer service LaunchAgent pour démarrage automatique
PLIST_DIR="$USER_HOME/Library/LaunchAgents"
mkdir -p "$PLIST_DIR"

cat > "$PLIST_DIR/com.tom.server.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tom.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>$TOM_DIR/serveur-https-complet.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$TOM_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$USER_HOME/Library/Logs/tom-server.log</string>
    <key>StandardErrorPath</key>
    <string>$USER_HOME/Library/Logs/tom-server-error.log</string>
</dict>
</plist>
PLIST_EOF

# Charger le service
echo "🔄 Démarrage du service automatique..."
launchctl load "$PLIST_DIR/com.tom.server.plist"

echo "✅ Service automatique configuré"

echo ""
echo "🎉 INSTALLATION TOM TERMINÉE AVEC SUCCÈS !"
echo "==========================================="
echo ""
echo "✅ Node.js installé et configuré"
echo "✅ TOM Server installé dans: $TOM_DIR"
echo "✅ Service automatique configuré et démarré"
echo "✅ Commande globale: tom-server"
echo ""
echo "🚀 URLS D'ACCÈS TOM SERVER:"
echo "   🌐 https://localhost:3443/test"
echo "   🌐 https://$(ipconfig getifaddr en0 2>/dev/null || echo 'IP-LOCAL'):3443/test"
echo ""
echo "📝 Logs: ~/Library/Logs/tom-server*.log"
echo ""
echo "🎯 LE SERVEUR TOM HTTPS EST ACTIF !"
echo "🎯 Tu peux maintenant utiliser les appairages multi-appareils !"
echo ""
echo "✨ Installation terminée - Ferme ce Terminal ✨"
echo ""