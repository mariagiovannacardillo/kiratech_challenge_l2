# Copione della demo

## Prima della demo
- Cluster pulito `make cluster-down` e inizializzato tramite `make cluster-up`.
- `make doctor` testato con esito positivo per le dipendenze.
- File hosts di Windows configurato per risolvere `onlineboutique.local`.

## Scaletta

| Minuti | Punto della traccia | Cosa mostro e Dico |
|---|---|---|
| 1 | Struttura del repo | **Azione:** `tree k8s/` <br>**Spiegazione:** "Mostro la separazione netta tra la risorsa upstream (`base`) e le logiche customizzate e isolate negli `overlays` (local, demo-reconfig, incidenti)." |
| 1-2 | Deploy | **Azione:** `make deploy` e `make wait-ready` <br>**Spiegazione:** "Sto applicando l'overlay base in modo dichiarativo. Ho escluso il `loadgenerator` per snellire la RAM della mia VM ed eliminare rumore diagnostico durante il troubleshooting." |
| 1 | Accesso e Stato | **Azione:** `make verify` e apro browser su `http://onlineboutique.local:30000` <br>**Spiegazione:** "Tutti i 12 container sono operativi. Uso `verify` per mostrare in tempo reale la relazione tra Deployment, Pods e i Service associati." |
| 1 | Riconfigurazione | **Azione:** `make demo-reconfig` <br>**Spiegazione:** "Mostro il potenziale di Kustomize e `configMapGenerator`. Cambiando dichiarativamente il payload del ConfigMap, Kubernetes innesca autonomamente un nuovo rollout senza interruzioni." |
| 3 | Analisi Incidente | **Azione:** `make trigger-incident-2` <br>**Spiegazione:** "Innesco l'incidente P1 al Service. Raccolgo i log reali usando `make evidence`. Mostro come i probe di stato rimangano ingannevolmente verdi, ma come l'applicativo degradi con un Errore 500 al checkout." |
| 1 | Ripristino | **Azione:** `make recover` <br>**Spiegazione:** "Eseguo il ripristino allineando forzatamente il cluster a Git, garantendo che lo stato dell'infrastruttura torni fedele al codice sorgente." |
| 1 | Krateo & Platform | **Azione:** Apro `krateo.md` <br>**Spiegazione:** "Sintetizzo come Krateo potrebbe astrarre tutto il lavoro fatto finora con Kustomize, offrendo al developer un form web e riconciliando le configurazioni via controller Kubernetes." |
| 1 | Uso critico dell'IA | **Azione:** Racconto Caso 2 da `ai-usage.md` <br>**Spiegazione:** "Porto l'esempio di come l'IA ipotizzasse un crash totale per l'incidente 2, mentre sul campo ho riscontrato e documentato una degradazione silenziosa dell'e-commerce." |

## Frasi chiave L2
- *"Raccolgo prima le evidenze diagnostiche (eventi, descrizioni, probe), isolo l'ambito e solo dopo agisco."*
- *"Uso `make recover` per un ripristino dichiarativo orientato al GitOps, anziché usare rattoppi temporanei tramite comandi imperativi come il `kubectl edit`."*