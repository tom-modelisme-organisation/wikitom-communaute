function telechargerTOMServer() {
    const os = detecterOS();
    
    if (os === 'macos') {
        // macOS - Copier commande Terminal avec URL GitHub
        const commandeInstall = `curl -fsSL https://raw.githubusercontent.com/tom-modelisme-organisation/wikitom-communaute/main/script-install-server-mac.sh | bash`;
        
        // Copier dans le presse-papier
        if (navigator.clipboard) {
            navigator.clipboard.writeText(commandeInstall).then(() => {
                if (window.PopupAide) {
                    window.PopupAide.afficher({
                        titre: 'TOM - Installation Terminal',
                        texte: '🍎 Commande copiée dans le presse-papier !\n\n🔥 ÉTAPES IMPORTANTES :\n1️⃣ Ouvre une NOUVELLE fenêtre Terminal\n   (Cmd+Espace → "Terminal" → Entrée)\n2️⃣ Colle la commande avec Cmd+V\n3️⃣ Appuie sur Entrée\n4️⃣ Saisis ton mot de passe Mac si demandé\n\n⚠️ IMPORTANT :\n• Utilise une NOUVELLE fenêtre Terminal\n• Tu ne verras pas ton mot de passe s\'afficher\n\n✅ Installation automatique complète !',
                        couleurSidebar: 'var(--1-validation)',
                        dureeAffichage: 10000
                    });
                }
            }).catch(() => {
                // Fallback si le clipboard ne marche pas
                afficherCommandeManuelle(commandeInstall);
            });
        } else {
            // Fallback : afficher la commande
            afficherCommandeManuelle(commandeInstall);
        }
    } else {
        // Windows - Commande PowerShell
        const commandeWindows = `irm https://raw.githubusercontent.com/tom-modelisme-organisation/wikitom-communaute/main/script-install-server-windows.ps1 | iex`;
        
        if (navigator.clipboard) {
            navigator.clipboard.writeText(commandeWindows).then(() => {
                if (window.PopupAide) {
                    window.PopupAide.afficher({
                        titre: 'TOM - Installation PowerShell',
                        texte: '🪟 Commande copiée dans le presse-papier !\n\n🔥 ÉTAPES IMPORTANTES :\n1️⃣ Ouvre un NOUVEAU PowerShell Admin\n   (Win+X → "PowerShell Admin")\n2️⃣ Colle la commande avec Ctrl+V\n3️⃣ Appuie sur Entrée\n4️⃣ Accepte les privilèges administrateur\n\n⚠️ IMPORTANT :\n• Utilise une NOUVELLE fenêtre PowerShell\n• En mode Administrateur\n\n✅ Installation automatique !',
                        couleurSidebar: 'var(--1-validation)',
                        dureeAffichage: 10000
                    });
                }
            });
        } else {
            afficherCommandeManuelle(commandeWindows);
        }
    }
}

function afficherCommandeManuelle(commande) {
    if (window.PopupAide) {
        window.PopupAide.afficher({
            titre: 'TOM - Copie cette commande',
            texte: '📋 COMMANDE À COPIER :\n\n' + commande + '\n\n🔥 ÉTAPES :\n1️⃣ Sélectionne et copie la commande ci-dessus\n2️⃣ Ouvre une NOUVELLE fenêtre Terminal/PowerShell\n3️⃣ Colle la commande et appuie sur Entrée\n4️⃣ Saisis ton mot de passe si demandé\n\n⚠️ IMPORTANT : Utilise une NOUVELLE fenêtre !',
            couleurSidebar: 'var(--3-action-titre)',
            dureeAffichage: 15000
        });
    }
}