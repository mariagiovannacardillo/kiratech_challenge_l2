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
| **Come ripristino** | `make recover` (Riallineamento GitOps) |

## 2. Sintomo e impatto

- **Sintomo osservato:** Eseguendo `k get pods`, il pod originale del frontend rimane in stato `Running`, mentre un nuovo pod generato dal ReplicaSet va immediatamente in stato `ImagePullBackOff`.
- **Impatto sull'utente (Nessuno):** Durante l'incidente, eseguendo `make smoke-test`, l'output è `Smoke test superato`. Grazie alla strategia di *RollingUpdate* (default in Kubernetes), il vecchio Pod viene mantenuto in vita e continua a servire traffico. Si tratta di un rollout bloccato, non di un downtime.

## 3. Evidenze raccolte (Output da make evidence)

| Strumento Diagnostico | Evidenza Rilevata |
|---|---|
| `k get pods` | `frontend-7dcc5fdb4f-tqz6w  0/1  ErrImagePull / ImagePullBackOff` |
| `k describe pod` (Events) | `Failed to pull image ".../frontend:tag-inesistente": failed to resolve reference` |

## 4. Ipotesi e causa confermata

| Ipotesi | Analisi | Esito |
|---|---|---|
| H1: Il nodo Kind non risolve DNS internet. | Eventi pod non riportano timeout IPv6, ma errore di reference. | Esclusa |
| H2: Il registry rifiuta credenziali. | Nessun messaggio `unauthorized` o `pull access denied`. | Esclusa |
| H3: Il tag dell'immagine non esiste. | Il descrittore logga `tag-inesistente` non risolvibile. | **Confermata** |

**Causa confermata:** Il nodo stabilisce correttamente la connessione al registry, ma la versione esatta dichiarata dal deployment (tag) non è disponibile all'interno del catalogo remoto.

## 5. Correzione

Uso dell'approccio **Dichiarativo**:
```bash
make recover
```
*Motivazione Operativa:* Rifiutato l'uso del `kubectl rollout undo` (Imperativo), in quanto risolverebbe l'emergenza immediata ma creerebbe un drift rispetto ai file del repository (infrangendo i principi Single Source of Truth).

## 6. Criteri di escalation (L3 / DevOps)
Richiedo supporto tecnico di livello superiore solo se:
- Gli eventi del pod riportano proxy error o DNS issue (`dial tcp: i/o timeout`).
- L'immagine confermata visivamente come "esistente" sul registry fallisce ripetutamente per Authentication Error.
- Inoltro il file diagnostico testuale automatico (generato da `make evidence`) a supporto del ticket L3.