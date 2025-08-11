#!/bin/bash
# TOM Server - Installateur macOS sans tuer les autres serveurs Node.js
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
echo "📂 Étape 2/4 - Création dossier TOM..."

# Arrêter seulement les serveurs TOM spécifiquement
echo "🛑 Arrêt des anciens serveurs TOM..."
pkill -f "serveur-https-complet" 2>/dev/null || true
pkill -f "serveur-https-local" 2>/dev/null || true
pkill -f "serveur-https-correct" 2>/dev/null || true
pkill -f "TOM-Server" 2>/dev/null || true
sleep 2

echo ""
echo "💡 INFORMATION IMPORTANTE :"
echo "   Si tu ne vois pas ton mot de passe Mac s'afficher, c'est normal."
echo "   Saisis-le et appuie sur Entrée."
echo ""

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

# Serveur HTTPS avec port aléatoire pour éviter les conflits
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

    // Générer un port aléatoire dans une plage sûre
    genererPortAleatoire() {
        return Math.floor(Math.random() * (9999 - 8000 + 1)) + 8000;
    }

    async essayerDemarrage(maxTentatives = 5) {
        for (let tentative = 1; tentative <= maxTentatives; tentative++) {
            // Générer un port aléatoire pour chaque tentative
            const port = tentative === 1 ? 3444 : this.genererPortAleatoire();
            
            try {
                console.log(`🔍 Tentative ${tentative}/${maxTentatives} - Port ${port}...`);
                
                // Générer certificats si nécessaires
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
                
                // Promesse pour gérer l'écoute du serveur
                await new Promise((resolve, reject) => {
                    server.on('error', (err) => {
                        if (err.code === 'EADDRINUSE') {
                            console.log(`❌ Port ${port} occupé`);
                            reject(new Error(`Port ${port} occupé`));
                        } else {
                            console.log('❌ Erreur serveur:', err.message);
                            reject(err);
                        }
                    });

                    server.listen(port, '0.0.0.0', () => {
                        this.port = port;
                        console.log(`🚀 TOM Server démarré!`);
                        console.log(`📡 HTTPS: https://localhost:${this.port}`);
                        console.log(`🌐 Réseau: https://${this.getLocalIP()}:${this.port}`);
                        console.log(`🔑 Code: ${this.codeAppairage}`);
                        console.log(`\n💡 Test: https://localhost:${this.port}/test`);
                        console.log(`   (Accepte le certificat auto-signé)`);
                        console.log(`🛑 Pour arrêter: Ctrl+C`);
                        resolve(server);
                    });
                });

                // Si on arrive ici, le serveur a démarré avec succès
                return;

            } catch (error) {
                if (tentative === maxTentatives) {
                    console.log(`❌ Impossible de démarrer après ${maxTentatives} tentatives`);
                    console.log('💡 Essaie de redémarrer ton Mac et relancer l\'installation');
                    throw error;
                }
                // Attendre un peu avant la prochaine tentative
                await new Promise(resolve => setTimeout(resolve, 1000));
            }
        }
    }

    async start() {
        try {
            await this.essayerDemarrage();
        } catch (error) {
            console.log('❌ Erreur lors du démarrage:', error.message);
        }
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
echo ""
echo "💡 INFORMATION : Le serveur va essayer différents ports automatiquement."
echo "   Ton serveur de développement sur le port 3000 ne sera pas affecté."
echo ""

# Démarrer le serveur
node serveur-https-complet.js
