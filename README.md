# Challenge L2 – Online Boutique su Kubernetes locale (kind + Kustomize)

![CI](https://github.com/mariagiovannacardillo/kiratech_challenge_l2/actions/workflows/ci.yaml/badge.svg)

Ambiente locale riproducibile e laboratorio di troubleshooting L2: deploy di Online Boutique su **kind** con **Kustomize**, due incidenti simulati con relativi runbook, valutazione concettuale di Krateo e uso documentato dell'AI. Il progetto dimostra autonomia operativa su Kubernetes, metodologie GitOps (dichiarative) e troubleshooting analitico basato su evidenze reali.

## Indice
1. [Applicazione scelta](#1-applicazione-scelta)
2. [Architettura essenziale](#2-architettura-essenziale)
3. [Prerequisiti e ambiente di test](#3-prerequisiti-e-ambiente-di-test)
4. [Installazione](#4-installazione)
5. [Verifica del funzionamento](#5-verifica-del-funzionamento)
6. [Comandi del Makefile](#6-comandi-del-makefile)
7. [Demo](#7-demo)
8. [Troubleshooting L2](#8-troubleshooting-l2)
9. [Rimozione e reinstallazione](#9-rimozione-e-reinstallazione)
10. [Sicurezza e configurazione](#10-sicurezza-e-configurazione)
11. [Krateo e uso dell'AI](#11-krateo-e-uso-dellai)
12. [Limiti noti](#12-limiti-noti)
13. [Tracciabilità dei requisiti](#13-tracciabilità-dei-requisiti)
14. [Crediti e licenza](#14-crediti-e-licenza)

## 1. Applicazione scelta

- **Applicazione:** Online Boutique (Google Cloud), negozio online dimostrativo a microservizi.
- **Repository originale:** <https://github.com/GoogleCloudPlatform/microservices-demo>
- **Versione:** v0.10.7. Il manifest `release/kubernetes-manifests.yaml` è copiato **senza modifiche** in `k8s/base/boutique.yaml`.
- **Perché l'ho scelta:** È un'applicazione a microservizi reale con dipendenze gRPC complesse. Questo mi permette di testare scenari di guasto realistici da operatore L2 (es. cosa succede a cascata se cade un servizio backend) in un ecosistema già predisposto per Kubernetes.
- **Perimetro incluso:** 11 Deployment (10 microservizi + `redis-cart`), `frontend-external` esposto in locale.
- **Perimetro escluso (e perché):**
  - `loadgenerator` (genera traffico finto continuo): rimosso con una patch Kustomize nell'overlay `local` per risparmiare risorse CPU/RAM sulla VM e mantenere i log puliti durante l'analisi degli incidenti.
  - `shoppingassistantservice`: funzione opzionale, non presente nel manifest di base.

## 2. Architettura essenziale

Schema, tabella dei componenti e spiegazione del Dockerfile: **[docs/architecture.md](docs/architecture.md)**.

In breve: il browser raggiunge `http://onlineboutique.local:30000` (tramite modifica file hosts locale) → porta mappata da kind sul nodo → Service `frontend-external` (NodePort) → `frontend` → servizi gRPC interni (`ClusterIP`) → `redis-cart` per il carrello.

## 3. Prerequisiti e ambiente di test

| Strumento | Versione usata |
|---|---|
| Sistema operativo | Debian GNU/Linux 12 (bookworm) su VMware |
| CPU / RAM della VM | 4 vCPU / 7906 MiB RAM |
| Docker | 20.10.24+dfsg1 |
| kind | v0.34.0-alpha |
| kubectl | v1.37.1 |

Il comando `make doctor` verifica i prerequisiti, le dipendenze e stampa versioni e risorse hardware.

**Test eseguiti:** Il 31 Ottobre 2026 l'infrastruttura è stata collaudata con un deploy completo eseguito in ~5 minuti. Sono stati riprodotti con successo i due incidenti, raccolte le evidenze tramite il target `make evidence` e validato il ripristino dichiarativo tramite `make recover`.

## 4. Installazione

```bash
git clone [https://github.com/mariagiovannacardillo/kiratech_challenge_l2.git](https://github.com/mariagiovannacardillo/kiratech_challenge_l2.git)
cd kiratech_challenge_l2

make doctor        # controlla prerequisiti
make cluster-up    # crea il cluster kind "l2-challenge"
make deploy        # kubectl apply -k k8s/overlays/local
make wait-ready    # attende che i Deployment siano disponibili (max 300 s)
make smoke-test    # verifica HTTP sul frontend (output pulito senza pipe error)
```

L'applicazione risponde su **http://onlineboutique.local:30000**. Il primo avvio richiede il download delle immagini dal registry di Google.

## 5. Verifica del funzionamento

Output reale dell'ambiente dopo `make deploy` e `make wait-ready`:

```bash
\$ kubectl --context kind-l2-challenge get pods -n challenge-l2
NAME                                     READY   STATUS    RESTARTS   AGE
adservice-9745b7dfb-745mb                1/1     Running   0          4m58s
cartservice-6dd594447-9wb5k              1/1     Running   0          4m58s
checkoutservice-775f8bf878-94lx5         1/1     Running   0          4m58s
currencyservice-5dc84bf7d-7nbzg          1/1     Running   0          4m58s
emailservice-87865b54d-5fsw6             1/1     Running   0          4m58s
frontend-5d5bb549b-qdkmg                 1/1     Running   0          4m58s
paymentservice-d45f6dcf6-w5vtp           1/1     Running   0          4m58s
productcatalogservice-68847998d4-84jdz   1/1     Running   0          4m58s
recommendationservice-5b4d9cd76-xr2n7    1/1     Running   0          4m58s
redis-cart-558f8d8d44-gsb7x              1/1     Running   0          4m58s
shippingservice-6545f454d4-tmgnb         1/1     Running   0          4m57s
```
L'output dimostra che tutti i pod previsti dall'architettura sono instradati e attivi (Stato `Running`, colonna Ready `1/1`), a conferma del superamento dei controlli liveness e readiness impostati sui manifest.

## 6. Comandi del Makefile

Tutti i comandi `kubectl` usano `--context kind-l2-challenge`, agendo in sicurezza solo sul cluster della challenge.

| Comando | Cosa fa |
|---|---|
| `make doctor` | Verifica prerequisiti software e disponibilità risorse hardware VM |
| `make cluster-up` / `down` | Gestione ciclo di vita del cluster kind `l2-challenge` |
| `make deploy` | Applica Kustomize overlay `local` |
| `make wait-ready` | Loop di attesa deterministica (`condition=available`) |
| `make smoke-test` | Validazione applicativa HTTP silenziosa sul frontend (`grep` > `/dev/null`) |
| `make verify` | Stampa stato risorse core (Deployment, Pods, SVC, Endpoints) |
| `make trigger-incident-X` | Applica le patch di guasto isolato |
| `make diagnose` / `evidence` | Colleziona log, pod events e status salvandoli in `docs/evidence/` |
| `make recover` | Ripristino dichiarativo dell'infrastruttura (con `rollout status` sync) |
| `make demo-reconfig` | Riconfigurazione dichiarativa del ConfigMap banner |
| `make demo-scale` | Riconfigurazione imperativa (scaling) per scopi di training L2 |

## 7. Demo

Il copione dettagliato è presente in **[docs/demo.md](docs/demo.md)**.

## 8. Troubleshooting L2

| Incidente | Componente Compromesso | Runbook |
|---|---|---|
| 1 – Errore Pull | Tag inesistente sull'immagine del `frontend` | [docs/runbooks/incident-1-image.md](docs/runbooks/incident-1-image.md) |
| 2 – Disconnessione Service | Selettore errato sul `productcatalogservice` | [docs/runbooks/incident-2-service.md](docs/runbooks/incident-2-service.md) |

Ogni runbook documenta gli step analitici reali: baseline, innesco, evidenze estratte con `make evidence`, causa confermata, ripristino dichiarativo e criteri di escalation.

## 9. Rimozione e reinstallazione

Il comando `make undeploy` è stato testato con successo. Elimina l'intero namespace `challenge-l2` e le relative risorse in circa 5-10 secondi, garantendo idempotenza. È sufficiente rieseguire `make deploy` e `make wait-ready` per ottenere un nuovo rilascio pulito sul cluster ancora in esecuzione.

## 10. Sicurezza e configurazione

- **Nessuna credenziale hardcoded:** Non ho iniettato falsi Secret all'interno del progetto, poiché Google Online Boutique non ne richiede per l'operatività base e l'uso di Secret in chiaro nei repository Git costituisce un anti-pattern di sicurezza.
- **Configurazione disaccoppiata:** Il banner informativo (`FRONTEND_MESSAGE`) viene iniettato tramite il `configMapGenerator` di Kustomize nell'overlay `demo-reconfig`.
- **Hardening nativo:** Il container del frontend utilizza già best practices upstream, incluse `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, e drop di tutte le capabilities Linux.

## 11. Krateo e uso dell'AI

- Valutazione concettuale di Krateo: **[docs/krateo.md](docs/krateo.md)**
- Analisi critica del supporto AI (errori, test reali, validazioni manuali): **[docs/ai-usage.md](docs/ai-usage.md)**

## 12. Limiti noti

- **Archiviazione Volatile:** `redis-cart` utilizza un volume `emptyDir`. In caso di riavvio del pod, i carrelli attivi degli utenti andranno persi (nessuna persistenza hostPath/PV).
- **Esposizione di Rete:** Il `NodePort` su porta `30000` espone il servizio su `0.0.0.0` (tutte le interfacce). In un ambiente reale, il traffico dovrebbe essere ristretto e filtrato dietro a un Ingress Controller o API Gateway.
- **Singolo Punto di Fallimento:** Il cluster `kind` utilizzato è a nodo singolo e non garantisce High Availability (HA).

## 13. Tracciabilità dei requisiti

| Requisito della challenge | Dove lo trovi |
|---|---|
| Repository configurazioni, script, Makefile | Questo repository (root) |
| Kustomize overlays | `k8s/overlays/` |
| Runbook operativi L2 | `docs/runbooks/` |
| Schema architetturale e flussi | `docs/architecture.md` |
| Valutazione Platform Engineering (Krateo) | `docs/krateo.md` |
| Utilizzo critico dell'IA e Troubleshooting | `docs/ai-usage.md` |
| Plus: CI Workflow GitHub Actions | `.github/workflows/ci.yaml` |
| Plus: Diagnostica Automatizzata | Target `evidence` nel `Makefile` |

## 14. Crediti e licenza

Il workload Online Boutique è di proprietà di Google LLC, distribuito con licenza **Apache 2.0**. I file originali nella directory `base/` mantengono l'intestazione upstream. Tutto il codice di infrastruttura aggiuntivo e i runbook prodotti per questa challenge sono liberi e resi disponibili a scopo di validazione tecnica.