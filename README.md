# NPC AI Voice System for FiveM

Un système complet d'IA pour NPCs avec interaction vocale pour FiveM, alimenté par Ollama et intégré avec pma-voice.

## 🎯 Fonctionnalités

### 🎤 Système Vocal
- Détection automatique de proximité des joueurs
- Intégration avec pma-voice pour chat vocal
- Reconnaissance vocale (speech-to-text) via Web Speech API
- Synthèse vocale (text-to-speech) pour les réponses des NPCs
- Activation automatique sans touche

### 🤖 Intelligence Artificielle
- Connexion au framework Ollama
- Personnalités uniques pour chaque NPC (friendly, grumpy, mysterious, cheerful, serious, criminal, businessman, artist, worker, student)
- Mémoire contextuelle des conversations
- Réponses naturelles et cohérentes

### 💼 Système de Travail
- NPCs peuvent proposer du travail
- Système de candidatures aux entreprises
- Entretiens d'embauche automatisés avec évaluation IA
- Différents types d'emplois disponibles (transport, médical, gouvernement)

### 🚔 Activités Criminelles
- Trafic de drogue (achat/vente) avec négociation
- Système d'arrestation par la police
- Conséquences réalistes (prison, amendes)
- Système de réputation criminelle

### 🏃‍♂️ Comportements Autonomes
- Déplacements naturels dans la ville
- Routines quotidiennes basées sur la personnalité
- Animations contextuelles et réactions émotionnelles
- Interactions sociales entre NPCs et joueurs

## 📋 Prérequis

### Dépendances FiveM
- **pma-voice** - Système de chat vocal (requis)
- **mysql-async** - Base de données MySQL (requis)
- **ox_lib** - Utilitaires (optionnel)

### Services Externes
- **Ollama** - Framework IA local
  - Installation: [https://ollama.ai](https://ollama.ai)
  - Modèle recommandé: `llama3.2`
- **MySQL** - Base de données pour persistance
- **Node.js** - Pour services de reconnaissance vocale (optionnel)

## 🚀 Installation

### 1. Installation d'Ollama

```bash
# Linux/Mac
curl -fsSL https://ollama.ai/install.sh | sh

# Windows
# Télécharger depuis https://ollama.ai/download

# Installer le modèle
ollama pull llama3.2
```

### 2. Configuration FiveM

1. Placez le dossier dans `resources/[local]/npc-ai-voice/`
2. Ajoutez à votre `server.cfg`:

```cfg
ensure mysql-async
ensure pma-voice
ensure npc-ai-voice
```

### 3. Configuration Base de Données

Le script créera automatiquement les tables nécessaires au premier démarrage:
- `npc_ai_characters` - Données des NPCs
- `npc_ai_conversations` - Historique des conversations
- `npc_ai_memory` - Mémoire contextuelle des NPCs
- `npc_ai_jobs` - Système d'emplois et candidatures

### 4. Configuration

Modifiez `shared/config.lua` selon vos besoins:

```lua
-- AI settings
Config.AI = {
    enabled = true,
    provider = 'ollama',
    endpoint = 'http://localhost:11434', -- URL de votre instance Ollama
    model = 'llama3.2',
    temperature = 0.7
}

-- Voice system settings
Config.Voice = {
    enabled = true,
    proximityDistance = 15.0,
    autoActivation = true
}
```

## 🎮 Utilisation

### Commandes Joueur

- `/npc_talk` - Activer/désactiver manuellement l'écoute vocale
- `/job_stats` - Voir l'historique de vos candidatures
- `/crime_stats` - Voir votre réputation criminelle

### Commandes Admin (Console)

- `/create_npc [nom] [personnalité]` - Créer un nouveau NPC
- `/test_ollama` - Tester la connexion Ollama
- `/npc_stats` - Voir les statistiques du système
- `/npc_debug_toggle` - Activer/désactiver le mode debug

### Interactions

1. **Approchez-vous d'un NPC** (< 15m) pour déclencher la détection de proximité
2. **Parlez naturellement** - Le système détecte automatiquement votre voix via pma-voice
3. **Écoutez les réponses** - Les NPCs répondent avec leur personnalité unique
4. **Explorez les fonctionnalités** :
   - Demandez du travail aux NPCs businessmen/managers
   - Engagez des activités criminelles avec les NPCs criminal
   - Conversez naturellement selon leur personnalité

## 🔧 Personnalisation

### Ajouter de Nouveaux NPCs

```lua
local npcData = {
    name = "Jean Dupont",
    model = 'a_m_y_business_01',
    coords = {x = 100.0, y = 200.0, z = 30.0},
    heading = 180.0,
    personality = "friendly", -- voir Config.NPCs.personalities
    job = "Manager"
}

local npcId = exports['npc-ai-voice']:CreateNPC(npcData)
```

### Ajouter de Nouvelles Entreprises

Modifiez `Config.Jobs.companies` dans `shared/config.lua`:

```lua
{
    name = "Ma Nouvelle Entreprise",
    type = "custom",
    positions = {"employe", "manager"},
    requirements = {"clean_record"},
    salary = {min = 2500, max = 5000}
}
```

### Personnalités Disponibles

- `friendly` - Amical et sociable
- `grumpy` - Grincheux et impatient
- `mysterious` - Mystérieux et discret
- `cheerful` - Joyeux et optimiste
- `serious` - Sérieux et professionnel
- `criminal` - Activités illégales
- `businessman` - Orienté business
- `artist` - Créatif et artistique
- `worker` - Travailleur manuel
- `student` - Étudiant curieux

## 🐛 Dépannage

### Problèmes Courants

1. **NPCs ne répondent pas**
   - Vérifiez que Ollama est démarré: `ollama serve`
   - Vérifiez l'endpoint dans la config: `Config.AI.endpoint`
   - Consultez les logs serveur pour les erreurs

2. **Reconnaissance vocale ne fonctionne pas**
   - Vérifiez que pma-voice est actif
   - Autorisez l'accès microphone dans votre navigateur
   - Testez avec `/npc_talk` en manuel

3. **NPCs n'apparaissent pas**
   - Vérifiez la connection MySQL
   - Consultez les logs pour les erreurs de base de données
   - Utilisez `/npc_stats` pour voir les statistiques

### Logs de Debug

Activez le debug dans `shared/config.lua`:

```lua
Config.Debug = true
```

## 🔄 Mises à Jour

Le système inclut des fonctions de maintenance automatique:
- Nettoyage des anciennes conversations (7 jours)
- Nettoyage de la mémoire expirée
- Timeout des conversations inactives

## 🤝 Contribution

Pour contribuer au projet:

1. Fork le repository
2. Créez une branche feature
3. Committez vos changements
4. Créez une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.

## 🆘 Support

Pour obtenir de l'aide:

1. Consultez la documentation
2. Vérifiez les issues GitHub existantes
3. Créez une nouvelle issue avec les détails du problème

## 🎉 Remerciements

- **Ollama** - Framework IA
- **pma-voice** - Système vocal FiveM
- **FiveM Community** - Support et ressources