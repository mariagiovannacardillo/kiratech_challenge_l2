# Runbook L2 – Incidente 1: Immagine del frontend non disponibile

```bash
alias k='kubectl --context kind-l2-challenge -n challenge-l2'
```

## 0. Controlli iniziali (Baseline)
```bash
k get deployments,pods -o wide        
k get svc,endpointslices              
k get events --sort-by=.lastTimestamp | tail -n 20
make smoke-test                       
```

## 1. Scenario

| | |
|---|---|
| **Come lo innesco** | `make trigger-incident-1` |
| **Cosa cambia** | Viene sovrascritto il tag dell'immagine del frontend: `...frontend:v0.10.7` → `...frontend:tag-inesistente` |
| **Come ripristino** | `make recover` (Riallineamento dichiarativo all'overlay `local`) |

## 2. Sintomo e impatto

- **Sintomo osservato:** Eseguendo `k get pods -l app=frontend`, si vedono due Pod: il vecchio Pod resta in stato `1/1 Running`, mentre il nuovo Pod appena creato dal ReplicaSet passa inizialmente per `ErrImagePull` e si stabilizza in `ImagePullBackOff`.
- **Impatto sull'utente (Nessuno):** L'infrastruttura non subisce disservizi. `make smoke-test` controlla solo la home e non rileva questo incidente. Con la strategia *RollingUpdate* (default), il controller non è autorizzato a spegnere il vecchio Pod finché il nuovo non diventa `Ready`. Il problema si qualifica quindi come un **rollout bloccato** e non come un downtime.
- *Nota Diagnostica:* Durante l'incidente, eseguire `k get deployment frontend` è ingannevole: mostrerà comunque `1/1` perché Kubernetes sta conteggiando il pod originale ancora in esecuzione.

## 3. Evidenze raccolte (Output da make evidence)

| Strumento Diagnostico | Evidenza Rilevata |
|---|---|
| `k get pods` | `frontend-5fd57fbbb-wjkt5  0/1  ImagePullBackOff` (il Pod vecchio `frontend-5d5bb549b-b7km5` resta `1/1 Running`) – da `diagnose-20261031-102032.txt` |
| `k get deployments -o wide` | Colonna IMAGES del frontend riporta: `...frontend:tag-inesistente` |
| `k describe pod` (Events) | `Failed to pull image ".../frontend:tag-inesistente": failed to resolve reference ... not found` |
| `k logs -l app=frontend` | `container "server" ... is waiting to start: trying and failing to pull image` (il container non è mai partito, quindi non possiede log applicativi). |

## 4. Ipotesi e causa confermata

| Ipotesi | Analisi | Esito |
|---|---|---|
| H1: Il nodo non risolve DNS o internet. | Gli eventi pod non riportano timeout IPv6/DNS, ma restituiscono una precisa risposta `NotFound` dal registry. | Esclusa |
| H2: Il registry rifiuta credenziali. | L'errore di pull è `code = NotFound` (`not found`), non `pull access denied` né errori di autenticazione del registry. Negli stessi eventi compaiono per pochi secondi messaggi `Unauthorized` (`ReplicaSetCreateError`, `FailedToUpdateEndpointSlices`) emessi dal controllo del cluster, non dal registry: osservati e non indagati. | Esclusa |
| H3: Il tag dell'immagine non esiste. | Il descrittore logga `tag-inesistente` come esplicitamente non risolvibile dal catalogo remoto. | **Confermata** |

**Causa confermata:** Il nodo stabilisce correttamente la connessione al registry, ma la versione esatta dichiarata dal deployment (il tag) non è disponibile all'interno del catalogo remoto.

## 5. Correzione

**Opzione A: Rapida / Imperativa (Solo per emergenze critiche)**
```bash
k rollout undo deployment/frontend
```
*Nota operativa:* Risolve l'emergenza immediata annullando l'ultimo rollout, ma crea un "drift" (disallineamento) tra lo stato del cluster e il codice presente sul repository. Infrange il principio della *Single Source of Truth*.

**Opzione B: Dichiarativa (consigliata e adottata)**
```bash
make recover
```
*Nota operativa:* Riapplica il manifest Kustomize corretto (`k8s/overlays/local`). Ripristina l'infrastruttura riallineando il cluster al repository ed eliminando il ReplicaSet fallato in attesa. È la scelta corretta per questo ambiente.

## 6. Verifica del ripristino

Al termine dell'esecuzione di `make recover`, il sistema esegue i controlli di integrità:

```bash
k rollout status deployment/frontend
# Output atteso: deployment "frontend" successfully rolled out

k get pods -l app=frontend
# Output atteso: Un solo pod, frontend-5d5bb549b-xxxxx   1/1     Running   0

make smoke-test
# Output atteso: Smoke test superato
```
L'infrastruttura è nuovamente stabile. Il pod bloccato in `ImagePullBackOff` è stato terminato e rimosso dalla garbage collection di Kubernetes.

## 7. Criteri di escalation (L3 / DevOps)

Escalo la problematica al livello superiore (senza tentare ulteriori fix manuali) se:
- L'evento di pull riporta errori di rete **esterni al cluster** (es. `dial tcp: i/o timeout`, o errori di risoluzione CoreDNS).
- L'immagine, confermata visivamente come "esistente" sul registry tramite browser/CLI, continua a fallire il pull ripetutamente per Authentication Error.
- Dopo aver lanciato `make recover`, il Pod `frontend` non torna in stato `Ready 1/1` entro **5 minuti**.
- Il problema di pull si estende improvvisamente anche ad altri microservizi.

**Cosa allego al ticket:** Il file diagnostico generato da `make evidence` (che include lo stato dei Pod, i Service e gli eventi completi) e il riferimento esatto dell'immagine fallata.

**Modello di messaggio per l'escalation (Ticket L3):**

> **Oggetto:** [challenge-l2] P2 - Frontend non aggiornabile, immagine non scaricabile
> **Quando:** [Ora dell'incidente] – **Ambiente:** kind-l2-challenge, namespace: challenge-l2
> **Sintomo:** Il nuovo Pod `frontend` va in `ImagePullBackOff`. Il vecchio Pod continua a servire traffico, ma il rollout è bloccato.
> **Evidenze:** In allegato file `diagnose-YYYYMMDD-HHMMSS.txt`. Errore rilevato negli eventi: `Failed to pull image ".../frontend:tag-inesistente": failed to resolve reference`.
> **Ipotesi:** Il nodo comunica col registry, ma il tag specificato nel manifest non esiste o è stato rimosso.
> **Azioni eseguite:** Eseguito `make recover` per riallineare il cluster a Git.
> **Richiesta:** Si richiede verifica della validità del tag sul registry o eventuale correzione della pipeline CI che genera le immagini.