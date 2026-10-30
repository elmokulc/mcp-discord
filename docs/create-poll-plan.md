# Ajouter create_poll avec Qwen et OpenCode

## État analysé le 30 octobre 2026

- Révision de départ : `e134c03`. Arbre de travail propre avant la préparation de ce dossier.
- Java 17, Maven, Spring Boot 4.0.2, Spring AI 2.0.0-M4, JDA 6.4.1.
- 18 fichiers Java, 15 services et 82 méthodes `@Tool`.
- `MessageService` reçoit JDA par constructeur. Son résolveur privé trouve les salons texte, les salons d'annonces et les threads présents dans le cache JDA.
- `DiscordMcpConfig.discordTools()` enregistre déjà `MessageService` dans `MethodToolCallbackProvider`. Une méthode annotée dans ce service suffit ; aucun nouveau service ni enregistrement nécessaire.
- Les outils renvoient des chaînes, utilisent `.complete()` et laissent remonter les erreurs de validation et de Discord. Conserver ces conventions.
- Les anciens paramètres sont essentiellement des chaînes. Pour le nouvel outil, utiliser des types JSON adaptés sans modifier les outils existants.
- Aucun `src/test`, aucune dépendance de test, aucun wrapper Maven. La CI existante publie les images et le Dockerfile compile avec `-DskipTests` : une image construite ne prouve donc pas que les tests passent.
- Le démarrage Spring crée une vraie connexion Discord et peut appeler `System.exit` sans token. Les tests doivent instancier le service avec JDA simulé, sans `@SpringBootTest`.
- Java et Maven absents du PATH local ; Docker est installé et son accès a été vérifié hors restriction du sandbox Codex. Le harness utilise Docker comme solution de repli.
- OpenCode installé : v2.0.32. Le provider global `ilass` déclare `qwen-3.8-27b`, via `https://llm.ilaas.fr/v1`. `opencode models --standalone` reconnaît bien `ilass/qwen-3.8-27b`. C'est un endpoint distant configuré, pas une exécution Ollama locale. Aucun appel d'inférence n'a été lancé ; sa disponibilité effective et sa facturation ne sont pas encore vérifiées. D'autres providers dont OpenAI sont également disponibles.
- L'aide de la CLI et `opencode run --help` ont été vérifiés. Le sandbox bloque l'écriture des journaux dans le profil utilisateur ; déplacer les répertoires XDG de données, cache et état permet de consulter l'aide. Le serveur standalone a nécessité une exécution hors de ce sandbox. Avec la v2.0.32, `opencode models` n'accepte pas le nom du provider comme argument positionnel.

## Contrat à implémenter

Nom exact : `create_poll`. Créer un sondage Discord natif, pas un message à réactions.

| Paramètre | Type Java / JSON | Règle |
| --- | --- | --- |
| channelId | String / string | Obligatoire, non blanc ; salon texte, annonces ou thread en cache |
| question | String / string | Obligatoire, non blanche, 300 caractères maximum selon JDA |
| answers | List<String> / array de strings | Obligatoire, 2 à 10 éléments, chacun non blanc et de 55 caractères maximum selon JDA |
| durationHours | Integer / integer | Facultatif, 24 par défaut ; 1 à 168 heures |
| allowMultiselect | Boolean / boolean | Facultatif, false par défaut |

Succès : chaîne contenant l'ID du message et son lien Discord. Échec : validation explicite ou exception JDA, jamais une confirmation de succès. Toutes les validations de contenu précèdent l'envoi. Utiliser les constantes et validations JDA lorsque possible, sans doubler inutilement leur logique.

La borne de 168 heures correspond à JDA utilisé ici. Vérifier l'API dans la version **6.4.1**, car la documentation publique JDA peut présenter une version plus récente. Ne pas mettre à jour les dépendances pour cette fonctionnalité.

Hors périmètre : résultats et clôture de sondages, emojis, alias `create_pool`, nouveaux intents, messages privés, changement des transports, refonte des autres outils. Un post de forum existant est un thread ; la création d'un nouveau post n'appartient pas à cet outil. Un thread archivé non mis en cache conserve la limitation actuelle des outils de messages.

## Étapes et livrables

1. **Établir la base** : `bash scripts/verify.sh --baseline` a terminé avec succès le 30 octobre 2026 : compilation Java 17, production du JAR et sortie 0 du harness. Aucun test n'existe encore. Le contrôle de syntaxe Bash passe et la commande sans `--baseline` refuse correctement l'absence de tests. Si la base échoue ultérieurement, distinguer panne d'environnement et erreur préexistante ; éviter toute réparation hors sujet.
2. **Préparer la délégation** : lire les consignes anglaises de `AGENTS.md`, utiliser le brief anglais `docs/tasks/create-poll.md`, la configuration `harness/opencode-qwen.json` et une session neuve. Elle fixe modèle principal et auxiliaire à `ilass/qwen-3.8-27b` et limite les providers à `ilass`. La restriction a été vérifiée avec `opencode models --standalone` et ce même contenu JSON : seuls les trois modèles ilass restent listés. Ne pas transmettre l'historique du chat.
3. **Tests par Qwen** : ajouter `spring-boot-starter-test` en scope test, des tests unitaires JUnit/Mockito et des tests du callback MCP réel. Confirmer que les tests de la nouvelle fonctionnalité échouent avant implémentation pour la bonne raison.
4. **Implémentation par Qwen** : ajouter une méthode dans `MessageService`, avec `@Tool` et `@ToolParam`, construire `MessagePollData` et appeler `sendMessagePoll(...).complete()`. Préserver le résolveur de salons existant et les autres méthodes. Compiler contre JDA 6.4.1 pour vérifier les signatures réelles.
5. **Documentation par Qwen** : ajouter l'outil au README, son exemple JSON, les limites, les valeurs par défaut et les permissions View Channel / Send Messages (Send Messages in Threads pour un thread) / Send Polls.
6. **Validation déterministe** : `bash scripts/verify.sh`. Vérifier les rapports et le diff ; le harness refuse une validation finale sans tests exécutés. Aucun appel Discord réel nécessaire.
7. **Revue indépendante** : contrôler le schéma exposé, l'absence de régression et les changements autorisés. Fournir à Qwen uniquement les erreurs précises à corriger, avec au plus deux boucles de correction avant réévaluation. La revue OpenAI éventuelle porte sur le diff et les résultats, pas sur une nouvelle lecture exhaustive du dépôt.
8. **Intégration ultérieure** : reconstruire le serveur ou l'image utilisée par le client, redémarrer et rafraîchir la liste MCP. Vérifier `tools/list`. Un essai réel dans un salon dédié est une étape distincte qui publie un message. Ne pas utiliser automatiquement le bot ou les tokens présents sur la machine.

Fichiers fonctionnels attendus : `pom.xml`, `src/main/java/dev/saseq/services/MessageService.java`, tests sous `src/test/java/dev/saseq/`, `README.md`. Pas de modification attendue dans `DiscordMcpConfig`. Renforcer la CI avec un job de vérification sur PR est utile, mais constitue un lot séparé ; ne pas changer le workflow de publication pendant ce petit ajout.

## Matrice d'acceptation

- Succès avec paramètres facultatifs absents : durée 24, choix unique ; vérifier le payload capturé, un seul envoi, l'ID et le lien retournés.
- Succès avec 1 et 168 heures ; multisélection true et false ; 2 et 10 réponses ; question à la limite et réponse à la limite.
- Résolution des trois types de salons ; salon inconnu : aucun envoi.
- channelId null/vide/blanc ; question nulle/vide/blanche/trop longue ; liste nulle/vide/1 élément/11 éléments ; réponse nulle/vide/blanche/trop longue ; durées 0, négative et 169 : erreur, aucun envoi.
- Erreur de permission ou de requête JDA : propagation, aucun faux succès.
- Construire `MethodToolCallbackProvider` avec le service simulé : `create_poll` existe exactement une fois, les noms d'outils restent uniques et les outils existants sont toujours présents.
- Examiner le JSON Schema généré avec un parseur, pas des recherches de sous-chaînes : champs, types, required/optional, éléments string du tableau. Tenir compte des unions nullable éventuelles.
- Invoquer le callback avec un vrai JSON sans champs facultatifs puis avec champs facultatifs : preuve de conversion JSON vers List<String>/Integer/Boolean. Aucune connexion Spring/Discord.

## Exécution et coût

Depuis la racine, la commande prévue est :

```bash
OPENCODE_CONFIG_CONTENT="$(cat harness/opencode-qwen.json)" \
opencode run --standalone --model ilass/qwen-3.8-27b \
  --file docs/tasks/create-poll.md \
  'Read AGENTS.md, implement only the attached brief, verify the result, and return a short factual report.'
```

Ne pas lancer cette commande pendant la phase de planification. Ne pas ajouter `--auto` sans avoir configuré et vérifié les permissions OpenCode. Conserver sa configuration globale et ses identifiants hors du dépôt. L'override fourni est limité à cette commande ; il ne change pas la configuration globale. Le contrôle de listing confirme la restriction des providers, pas une exécution d'inférence ni son coût.

Contexte initial limité : AGENTS.md, brief, pom, MessageService, DiscordMcpConfig et section Message Management du README. Pas de sous-agents, exploration générale, commit, push, publication ou déploiement. Demander une sortie courte : fichiers changés, tests réellement exécutés, résultat et blocages. Conserver les sorties longues dans un journal local ignoré plutôt que de les réinjecter dans le chat. Ne pas annoncer un coût nul : le provider distant peut facturer ses propres requêtes.

Le harness `scripts/verify.sh` fonctionne avec Java/Maven locaux ou un conteneur Maven 3.9.6 / Java 17. Avec Docker, seul un instantané de pom/src est monté ; `.env`, `.git` et les identifiants ne sont pas exposés. Les résultats sont copiés dans `target/harness/`, déjà ignoré par Git. Les dépendances sont téléchargées dans un cache éphémère : première exécution plus lente et réseau nécessaire. Le script est un contrôleur de build/tests, pas une sandbox de sécurité pour OpenCode ni une preuve de couverture exhaustive.

## Références vérifiées

- [MessagePollBuilder — documentation JDA](https://docs.jda.wiki/net/dv8tion/jda/api/utils/messages/MessagePollBuilder.html)
- [MessageChannel — source JDA 6.4.1](https://raw.githubusercontent.com/discord-jda/JDA/v6.4.1/src/main/java/net/dv8tion/jda/api/entities/channel/middleman/MessageChannel.java)
- [OpenCode CLI](https://opencode.ai/docs/cli/) ; l'aide de la version installée reste la référence pour ses options.
- [OpenCode configuration](https://opencode.ai/docs/config/).
