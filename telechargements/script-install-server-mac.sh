# Dans script-install-server-mac.sh, remplacer la section serveur par :

# Arrêter seulement les serveurs TOM spécifiquement ET libérer le port 3444
echo "🛑 Arrêt des anciens serveurs TOM et libération du port 3444..."
pkill -f "serveur-https-complet" 2>/dev/null || true
pkill -f "serveur-https-local" 2>/dev/null || true
pkill -f "serveur-https-correct" 2>/dev/null || true
pkill -f "TOM-Server" 2>/dev/null || true

# Forcer la libération du port 3444
sudo lsof -ti:3444 | xargs sudo kill -9 2>/dev/null || true
sleep 3

# Serveur HTTPS avec PORT FIXE 3444
cat > "$TOM_DIR/serveur-https-complet.js" << 'SERVER_EOF'
const express = require('express');
const https = require('https');
const fs = require('fs');
const os = require('os');
const { execSync } = require('child_process');

class TOMServer {
    constructor() {
        this.app = express();
        this.port = 3444; // PORT FIXE !
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
                <p><em>Installation TOM Server - macOS - Port Fixe</em></p>
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
            console.log(`🔍 Démarrage serveur TOM sur port fixe ${this.port}...`);
            
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
            
            server.on('error', (err) => {
                if (err.code === 'EADDRINUSE') {
                    console.log(`❌ Port ${this.port} encore occupé - Force l'arrêt...`);
                    process.exit(1);
                } else {
                    console.log('❌ Erreur serveur:', err.message);
                    process.exit(1);
                }
            });

            server.listen(this.port, '0.0.0.0', () => {
                console.log(`🚀 TOM Server démarré sur PORT FIXE !`);
                console.log(`📡 HTTPS: https://localhost:${this.port}`);
                console.log(`🌐 Réseau: https://${this.getLocalIP()}:${this.port}`);
                console.log(`🔑 Code: ${this.codeAppairage}`);
                console.log(`\n💡 Test: https://localhost:${this.port}/test`);
                console.log(`   (Accepte le certificat auto-signé)`);
                console.log(`🛑 Pour arrêter: Ctrl+C`);
            });

        } catch (error) {
            console.log('❌ Erreur lors du démarrage:', error.message);
            process.exit(1);
        }
    }
}

new TOMServer().start();
SERVER_EOF
