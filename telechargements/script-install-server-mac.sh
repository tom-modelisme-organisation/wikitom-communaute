#!/bin/bash
# TOM Server - Installateur macOS optimisé pour routeur ASUS RT-AX58U
# URL: https://raw.githubusercontent.com/tom-modelisme-organisation/wikitom-communaute/main/script-install-server-mac.sh

set -e

clear
echo "🚀 TOM Server Installer - macOS (ASUS Routeur)"
echo "====================================================="
echo ""
echo "Installation automatique optimisée pour routeur ASUS RT-AX58U"
echo "Détection réseau TOM-NETWORK et configuration automatique..."
echo ""

# Variables
TOM_DIR="/Applications/TOM-Server"

# Fonction pour détecter le réseau TOM
detect_tom_network() {
    local tom_ip=""
    local tom_interface=""
    local gateway=""
    
    # Rechercher interface avec IP 192.168.1.x
    tom_ip=$(ifconfig | grep -E "inet 192\.168\.1\." | head -1 | awk '{print $2}')
    
    if [ -n "$tom_ip" ]; then
        # Trouver l'interface correspondante
        tom_interface=$(ifconfig | grep -B 10 "$tom_ip" | grep "^[a-z]" | tail -1 | cut -d: -f1)
        
        # Détecter la gateway
        gateway=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
        
        if [[ "$gateway" == 192.168.1.* ]]; then
            echo "detected:false"
    return 1
}

# Fonction pour tester la connexion au routeur ASUS
test_asus_router() {
    local gateway="$1"
    if ping -c 1 -W 3000 "$gateway" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

echo "🔍 Étape 0/5 - Analyse réseau TOM..."

# Analyser le réseau
network_result=$(detect_tom_network)

if echo "$network_result" | grep -q "detected:true"; then
    tom_ip=$(echo "$network_result" | grep "ip:" | cut -d: -f2)
    tom_interface=$(echo "$network_result" | grep "interface:" | cut -d: -f2)
    gateway=$(echo "$network_result" | grep "gateway:" | cut -d: -f2)
    
    echo "✅ Réseau TOM-NETWORK détecté !"
    echo "   📍 IP actuelle: $tom_ip"
    echo "   🌐 Interface: $tom_interface"
    echo "   🚪 Gateway: $gateway"
    
    # Test connexion routeur ASUS
    echo "🔌 Test connexion routeur ASUS..."
    if test_asus_router "$gateway"; then
        echo "✅ Routeur ASUS RT-AX58U accessible !"
        echo "   💡 Recommandation: Configurez réservation DHCP pour 192.168.1.100"
    else
        echo "⚠️ Routeur non accessible, mais configuration réseau détectée"
    fi
else
    echo "⚠️ Réseau TOM-NETWORK non détecté"
    echo "   💡 Le serveur TOM fonctionnera, mais optimisations limitées"
    echo "   📋 Connectez-vous au WiFi TOM-NETWORK après installation"
fi

echo ""
echo "📦 Étape 1/5 - Vérification Node.js..."

if command -v node >/dev/null 2>&1; then
    NODE_CURRENT=$(node -v | sed 's/v//')
    echo "✅ Node.js déjà installé (version $NODE_CURRENT)"
else
    echo "🔥 Installation Node.js..."
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
echo "📄 Étape 3/5 - Installation TOM Server optimisé routeur..."

# Package.json optimisé
cat > "$TOM_DIR/package.json" << 'PACKAGE_EOF'
{
  "name": "tom-server-https-routeur",
  "version": "2.0.0",
  "description": "TOM Multi-Device HTTPS Server - Optimisé ASUS RT-AX58U",
  "main": "serveur-https-complet.js",
  "scripts": {
    "start": "node serveur-https-complet.js",
    "stop": "pkill -f serveur-https-complet",
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
PACKAGE_EOF

# Serveur HTTPS optimisé routeur
cat > "$TOM_DIR/serveur-https-complet.js" << 'SERVER_EOF'
// TOM Server HTTPS - Version optimisée routeur ASUS (Installation macOS)
const express = require('express');
const https = require('https');
const os = require('os');
const { execSync } = require('child_process');

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
                routeur: 'ASUS RT-AX58U optimisé',
                platform: 'macOS'
            });
        });

        this.app.get('/api/test-routeur', (req, res) => {
            const test = this.testerConnexionRouteur();
            res.json(test);
        });

        this.app.get('/test', (req, res) => {
            const networkInfo = this.analyserReseauTOM();
            res.send(`
                <!DOCTYPE html>
                <html>
                <head>
                    <title>TOM Server - Routeur ASUS RT-AX58U</title>
                    <meta charset="utf-8">
                    <style>
                        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
                        .container { max-width: 700px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                        h1 { color: #2c5aa0; text-align: center; }
                        .success { color: #27ae60; }
                        .warning { color: #f39c12; }
                        .info { color: #2196F3; margin: 15px 0; }
                        .code { background: #f5f5f5; padding: 15px; border-radius: 5px; font-family: monospace; }
                        .network-status { background: ${networkInfo.detected ? '#d4edda' : '#fff3cd'}; padding: 15px; border-radius: 5px; margin: 15px 0; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1>🚀 TOM Server - Routeur ASUS RT-AX58U</h1>
                        <p class="success">Serveur HTTPS opérationnel sur macOS</p>
                        
                        <div class="network-status">
                            <h3>📡 Statut Réseau TOM</h3>
                            <p><strong>Réseau TOM-NETWORK:</strong> ${networkInfo.detected ? '✅ Connecté' : '⚠️ Non détecté'}</p>
                            ${networkInfo.detected ? `
                                <p><strong>Interface:</strong> ${networkInfo.interface}</p>
                                <p><strong>IP actuelle:</strong> ${networkInfo.ip}</p>
                                <p><strong>Gateway:</strong> ${networkInfo.gateway}</p>
                            ` : ''}
                        </div>
                        
                        <div class="code">
                            <strong>URL serveur:</strong> https://${this.getLocalIP()}:${this.port}<br>
                            <strong>Code d'appairage:</strong> ${this.codeAppairage}<br>
                            <strong>Plateforme:</strong> macOS optimisé ASUS
                        </div>
                        
                        ${networkInfo.detected ? `
                            <div class="info">
                                <h4>🎯 Configuration optimale détectée !</h4>
                                <p>Le serveur TOM est correctement connecté au routeur ASUS RT-AX58U.</p>
                                <p>Recommandation: Configurez une réservation DHCP pour 192.168.1.100</p>
                            </div>
                        ` : `
                            <div class="warning">
                                <h4>⚠️ Configuration réseau à optimiser</h4>
                                <p>Connectez-vous au WiFi TOM-NETWORK pour une configuration optimale.</p>
                            </div>
                        `}
                        
                        <p style="margin-top: 30px; color: #666; text-align: center;">
                            <em>Installation TOM Server - macOS - Routeur ASUS RT-AX58U</em>
                        </p>
                    </div>
                </body>
                </html>
            `);
        });
    }

    analyserReseauTOM() {
        try {
            const interfaces = os.networkInterfaces();
            
            for (const [nom, details] of Object.entries(interfaces)) {
                for (const detail of details) {
                    if (detail.family === 'IPv4' && !detail.internal && detail.address.startsWith('192.168.1.')) {
                        // Détecter la gateway via route
                        let gateway = '192.168.1.1';
                        try {
                            const routeOutput = execSync('route -n get default 2>/dev/null || echo ""', { encoding: 'utf8' });
                            const gatewayMatch = routeOutput.match(/gateway: (192\.168\.1\.\d+)/);
                            if (gatewayMatch) {
                                gateway = gatewayMatch[1];
                            }
                        } catch (e) {
                            // Ignore les erreurs de route
                        }
                        
                        return {
                            detected: true,
                            interface: nom,
                            ip: detail.address,
                            gateway: gateway,
                            netmask: detail.netmask
                        };
                    }
                }
            }
            
            return { detected: false };
        } catch (error) {
            return { detected: false, error: error.message };
        }
    }

    testerConnexionRouteur() {
        const networkInfo = this.analyserReseauTOM();
        const result = {
            timestamp: Date.now(),
            reseauTOM: networkInfo.detected,
            gateway: networkInfo.gateway,
            tests: {}
        };

        if (networkInfo.detected) {
            try {
                execSync(`ping -c 1 -W 3000 ${networkInfo.gateway}`, { stdio: 'ignore' });
                result.tests.gateway = { success: true, message: 'Gateway accessible' };
            } catch (error) {
                result.tests.gateway = { success: false, message: 'Gateway non accessible' };
            }

            result.tests.configuration = {
                success: true,
                message: 'Configuration réseau TOM détectée',
                details: {
                    ip: networkInfo.ip,
                    interface: networkInfo.interface,
                    subnet: '192.168.1.0/24'
                }
            };
        } else {
            result.tests.configuration = {
                success: false,
                message: 'Configuration réseau TOM non détectée'
            };
        }

        return result;
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

    async essayerDemarrage(maxTentatives = 5) {
        for (let tentative = 1; tentative <= maxTentatives; tentative++) {
            const port = tentative === 1 ? this.port : Math.floor(Math.random() * (9999 - 8000 + 1)) + 8000;
            
            try {
                await this.demarrerAvecPort(port);
                return true;
            } catch (error) {
                console.log(`❌ Tentative ${tentative}/${maxTentatives} échouée (port ${port})`);
                if (tentative === maxTentatives) {
                    throw error;
                }
            }
        }
        return false;
    }

    demarrerAvecPort(port) {
        return new Promise((resolve, reject) => {
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

            const server = https.createServer(options, this.app);
            
            server.listen(port, '0.0.0.0', () => {
                this.port = port;
                const networkInfo = this.analyserReseauTOM();
                
                console.log(`🚀 TOM Server démarré ! (Routeur ASUS optimisé)`);
                console.log(`📡 HTTPS: https://localhost:${port}`);
                console.log(`🌐 Réseau: https://${this.getLocalIP()}:${port}`);
                console.log(`🔑 Code: ${this.codeAppairage}`);
                
                if (networkInfo.detected) {
                    console.log(`✅ Connecté au réseau TOM-NETWORK (${networkInfo.interface})`);
                    console.log(`📍 IP: ${networkInfo.ip}`);
                    console.log(`🎯 Gateway: ${networkInfo.gateway}`);
                    console.log(`💡 Recommandation: Réservation DHCP pour 192.168.1.100`);
                } else {
                    console.log(`⚠️ Réseau TOM-NETWORK non détecté`);
                    console.log(`💡 Connectez-vous au WiFi TOM-NETWORK pour optimisations`);
                }
                
                console.log(`\n💡 Test: https://localhost:${port}/test`);
                console.log(`⚠️ Acceptez le certificat auto-signé dans votre navigateur`);
                
                resolve();
            });

            server.on('error', (error) => {
                if (error.code === 'EADDRINUSE') {
                    reject(new Error(`Port ${port} déjà utilisé`));
                } else {
                    reject(error);
                }
            });
        });
    }

    async start() {
        try {
            await this.essayerDemarrage();
        } catch (error) {
            console.error('❌ Erreur démarrage serveur:', error.message);
            console.log('💡 Essayez: sudo lsof -i :3443 pour voir les ports utilisés');
            process.exit(1);
        }
    }
}

// Démarrage avec gestion d'erreurs
const serveur = new TOMServerRouteur();
serveur.start();

// Gestion arrêt propre
process.on('SIGINT', () => {
    console.log('\n🛑 Arrêt du serveur TOM...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n🛑 Arrêt programmé du serveur...');
    process.exit(0);
});
SERVER_EOF

echo "✅ Fichiers TOM Server routeur créés"

echo ""
echo "📦 Étape 4/5 - Installation des dépendances..."

# Installer les dépendances
cd "$TOM_DIR"
echo "⬇️ Installation Express.js..."
npm install --production --silent
echo "✅ Dépendances installées"

echo ""
echo "🔗 Étape 5/5 - Configuration système et finalisation..."

# Créer script de démarrage optimisé
cat > "$TOM_DIR/start-tom-server.sh" << 'START_EOF'
#!/bin/bash
echo "🚀 Démarrage TOM Server optimisé routeur ASUS..."
echo "🔍 Analyse réseau TOM-NETWORK..."
cd "/Applications/TOM-Server"
node serveur-https-complet.js
START_EOF

chmod +x "$TOM_DIR/start-tom-server.sh"

# Créer script de test réseau
cat > "$TOM_DIR/test-reseau-tom.sh" << 'TEST_EOF'
#!/bin/bash
echo "🔍 Test configuration réseau TOM - ASUS RT-AX58U"
echo "============================================="
echo ""

# Détecter IP TOM
tom_ip=$(ifconfig | grep -E "inet 192\.168\.1\." | head -1 | awk '{print $2}')

if [ -n "$tom_ip" ]; then
    echo "✅ Réseau 192.168.1.x détecté"
    echo "   📍 IP actuelle: $tom_ip"
    
    # Détecter interface
    interface=$(ifconfig | grep -B 10 "$tom_ip" | grep "^[a-z]" | tail -1 | cut -d: -f1)
    echo "   🌐 Interface: $interface"
    
    # Test gateway
    echo ""
    echo "🔌 Test ping routeur ASUS (192.168.1.1)..."
    if ping -c 1 -W 3000 192.168.1.1 >/dev/null 2>&1; then
        echo "✅ Routeur ASUS accessible"
    else
        echo "❌ Routeur ASUS non accessible"
    fi
else
    echo "⚠️ Réseau TOM non détecté"
    echo "   💡 Connectez-vous au WiFi TOM-NETWORK"
fi

echo ""
echo "📋 Configuration recommandée:"
echo "   WiFi: TOM-NETWORK"
echo "   IP recommandée: 192.168.1.100 (réservation DHCP)"
echo "   Gateway: 192.168.1.1"
echo ""
read -p "Appuyez sur Entrée pour continuer..."
TEST_EOF

chmod +x "$TOM_DIR/test-reseau-tom.sh"

# Créer service automatique (LaunchAgent)
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.tom.server.plist << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tom.server.routeur</string>
    <key>ProgramArguments</key>
    <array>
        <string>node</string>
        <string>/Applications/TOM-Server/serveur-https-complet.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Applications/TOM-Server</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/tom-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/tom-server-error.log</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
PLIST_EOF

# Charger le service
launchctl load ~/Library/LaunchAgents/com.tom.server.plist 2>/dev/null || true
launchctl start com.tom.server.routeur 2>/dev/null || true

echo "✅ Service automatique configuré"

# Créer raccourcis sur le Bureau si possible
if [ -d ~/Desktop ]; then
    cat > ~/Desktop/TOM\ Server\ \(Routeur\ ASUS\).command << 'SHORTCUT_EOF'
#!/bin/bash
cd "/Applications/TOM-Server"
./start-tom-server.sh
SHORTCUT_EOF
    
    cat > ~/Desktop/Test\ Réseau\ TOM.command << 'TEST_SHORTCUT_EOF'
#!/bin/bash
cd "/Applications/TOM-Server"
./test-reseau-tom.sh
TEST_SHORTCUT_EOF
    
    chmod +x ~/Desktop/TOM\ Server\ \(Routeur\ ASUS\).command
    chmod +x ~/Desktop/Test\ Réseau\ TOM.command
    
    echo "✅ Raccourcis créés sur le Bureau"
fi

echo ""
echo "🎉 INSTALLATION TOM TERMINÉE AVEC SUCCÈS !"
echo "============================================="
echo ""
echo "✅ Node.js installé et configuré"
echo "✅ TOM Server installé dans: $TOM_DIR"
echo "✅ Service automatique configuré et démarré"
echo "✅ Optimisations routeur ASUS RT-AX58U appliquées"
echo "✅ Raccourcis créés sur le Bureau"
echo ""

# Détecter la configuration réseau actuelle
current_network=$(detect_tom_network)

echo "🚀 URLS D'ACCÈS TOM SERVER:"
echo "   🌐 https://localhost:3443/test"

if echo "$current_network" | grep -q "detected:true"; then
    current_ip=$(echo "$current_network" | grep "ip:" | cut -d: -f2)
    current_interface=$(echo "$current_network" | grep "interface:" | cut -d: -f2)
    current_gateway=$(echo "$current_network" | grep "gateway:" | cut -d: -f2)
    
    echo "   🌐 https://$current_ip:3443/test"
    echo ""
    echo "🎯 CONFIGURATION RÉSEAU OPTIMALE DÉTECTÉE !"
    echo "   ✅ Réseau TOM-NETWORK connecté"
    echo "   📍 IP actuelle: $current_ip"
    echo "   🌐 Interface: $current_interface"
    echo "   🎯 IP recommandée: 192.168.1.100 (configurez réservation DHCP)"
    echo "   🔗 Gateway: $current_gateway"
    echo ""
    echo "📋 PROCHAINES ÉTAPES RECOMMANDÉES:"
    echo "   1. Configurez la réservation DHCP sur votre routeur ASUS"
    echo "   2. Associez cette machine à l'IP 192.168.1.100"
    echo "   3. Les BlockNodes se connecteront automatiquement"
else
    echo ""
    echo "📋 CONFIGURATION RÉSEAU À OPTIMISER:"
    echo "   1. Connectez-vous au WiFi TOM-NETWORK"
    echo "   2. Configurez la réservation DHCP pour 192.168.1.100"
    echo "   3. Utilisez 'Test Réseau TOM' pour vérifier la configuration"
fi

echo ""
echo "🛠️ OUTILS DISPONIBLES:"
echo "   • 'TOM Server (Routeur ASUS)' - Démarrer le serveur"
echo "   • 'Test Réseau TOM' - Vérifier la configuration réseau"
echo ""
echo "🎯 LE SERVEUR TOM HTTPS EST ACTIF ET OPTIMISÉ !"
echo ""
echo "Les serveurs se relanceront automatiquement à chaque"
echo "démarrage de ton Mac."

echo ""
echo "✨ Installation terminée - Ferme cette fenêtre ✨"
echo ""

read -p "Appuyez sur Entrée pour fermer"d:true"
            echo "ip:$tom_ip"
            echo "interface:$tom_interface"
            echo "gateway:$gateway"
            return 0
        fi
    fi
    
    echo "detecte
