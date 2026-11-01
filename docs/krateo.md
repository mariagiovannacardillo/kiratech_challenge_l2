# Krateo PlatformOps – Valutazione Concettuale

> **Stato della valutazione:** solo concettuale, ricavata dalla lettura della documentazione e dei repository pubblici di Krateo. **Non l'ho installato né provato**; l'esempio YAML in fondo è illustrativo e non testato.

## 1. Cos'è Krateo

Krateo PlatformOps è una piattaforma di Platform Engineering pensata per superare la stesura manuale dei manifest e abbattere il carico cognitivo sugli sviluppatori. 

Secondo l'architettura di Krateo:
- Un **Blueprint** è un pacchetto infrastrutturale riutilizzabile (basato su **Helm chart**), accompagnato da un file `values.schema.json` che ne descrive i parametri ammessi.
- Una **CompositionDefinition** registra questo blueprint nel cluster Krateo; il `core-provider` si occupa di generare al volo un CRD (Custom Resource Definition) e un controller dedicati per quel blueprint.
- L'utente finale interagisce con il *Composable Portal* (l'interfaccia Web). Il form che compila genera una **Composition**, che viene intercettata e riconciliata dal controller per creare le risorse reali sul cluster di destinazione.

## 2. Applicazione al caso d'uso Online Boutique

Attualmente, l'orchestrazione di Online Boutique in questo progetto locale richiede padronanza della CLI (make, kubectl) e comprensione profonda di Kustomize per modificare e applicare l'overlay corretto.

Con Krateo, il team platform astrarrebbe questa logica: Kustomize non è il formato nativo del blueprint, ma Online Boutique dispone già di un Helm chart nel repo upstream.

1. convertirebbe Online Boutique in un Helm chart (la base upstream più le parti degli overlay `local` e `demo-reconfig` come valori configurabili);
2. descriverebbe i parametri esposti in un `values.schema.json`;
3. registrerebbe il chart in Krateo come template; chi lo usa compilerebbe un form (o un file YAML con pochi campi).

Gli overlay degli incidenti restano uno strumento di laboratorio e non entrerebbero nel template.

## 3. Parametri richiesti all'utilizzatore (Developer)

Lo schema verrebbe astratto esponendo allo sviluppatore solo le scelte essenziali, eliminando il rischio di errori di sintassi YAML o configurazioni pericolose:

| Parametro | Esempio | Note |
|---|---|---|
| `applicationName` | `online-boutique` | Nome dell'istanza |
| `namespace` | `test-team-frontend` | Dove viene installata |
| `environment` | `local` / `dev` / `staging` | Scelta da elenco; seleziona valori predefiniti (es. replicas, risorse) |
| `repository` | `github.com/<org>/<repo>` | Repository con la configurazione di riferimento |
| `imageTag` | `v0.10.7` | Versione dell'applicazione da installare |
| `frontendMessage` | `Ambiente di test` | Banner (oggi l'overlay `demo-reconfig`) |
| `enableLoadGenerator` | `false` | Oggi rimosso con una patch nell'overlay `local` |

Flusso concettuale:
`Utente compila form` → `Generazione Composition (CRD)` → `Controller Krateo riconcilia` → `Deploy di Deployment, Service e ConfigMap nel namespace di destinazione`.

## 4. Benefici

- **Standardizzazione e Sicurezza:** ogni installazione parte dallo stesso template e dalle stesse impostazioni di sicurezza, invece che da overlay copiati e modificati a mano.
- **Meno errori di configurazione:** chi usa il template compila pochi campi validati dallo schema e non tocca gli YAML.
- **Self-Service:** Svincola il team sistemistico/DevOps dalle richieste routinarie di provisioning ("Mi tiri su un cluster di test col nuovo tag per favore?"). Chi usa il template non deve conoscere Kubernetes.
- **Ripetibilità:** il template è versionato, quindi due installazioni con gli stessi parametri sono uguali.
- **Integrazione possibile con i controlli della piattaforma** (permessi, monitoring): dipende da cosa il team di piattaforma inserisce nel template; non è automatico.

## 5. Limiti

- **Non provato qui:** non ho installato Krateo né verificato nel mio ambiente quanto scritto in questo documento.
- **Conversione necessaria:** Krateo parte da Helm chart; i miei overlay Kustomize andrebbero ricostruiti come chart, e va mantenuta la coerenza con l'upstream a ogni aggiornamento.
- **Un componente in più da gestire:** installazione, aggiornamenti e monitoraggio di Krateo stesso, oltre alla curva di apprendimento del team.
- **Copre i casi standard:** il form espone solo i parametri previsti; esigenze fuori schema richiedono modifiche al template.
- **Sproporzionato per questo laboratorio:** per un'unica applicazione su kind il Makefile con gli overlay è più semplice; il valore di Krateo cresce con più applicazioni, team e ambienti.

## 6. Esempio illustrativo (non testato)

Il chart `online-boutique` e il repository sotto sono ipotetici; i nomi dei campi di Krateo vanno verificati sulla documentazione ufficiale prima di qualunque uso reale.

```yaml
# 1. Il team di piattaforma registra il template (chart con values.schema.json)
apiVersion: core.krateo.io/v1alpha1
kind: CompositionDefinition
metadata:
  name: online-boutique
  namespace: krateo-system
spec:
  chart:
    url: https://example.org/charts      # repository del chart (ipotetico)
    repo: online-boutique
    version: 1.0.0
---
# 2. L'utilizzatore chiede un'istanza compilando solo i parametri essenziali
apiVersion: composition.krateo.io/v1-0-0
kind: OnlineBoutique
metadata:
  name: boutique-test-team
  namespace: test-team-frontend
spec:
  applicationName: online-boutique
  environment: dev
  repository: github.com/<org>/<repo>
  imageTag: v0.10.7
  frontendMessage: "Ambiente di test"
  enableLoadGenerator: false
```