# Challenge L2 – Online Boutique su Kubernetes locale (kind + Kustomize)

![CI](https://github.com/mariagiovannacardillo/kiratech_challenge_l2/actions/workflows/ci.yaml/badge.svg)

Ambiente locale riproducibile e laboratorio di troubleshooting L2: deploy di Online Boutique su **kind** con **Kustomize**, due incidenti simulati con relativi runbook, valutazione concettuale di Krateo e uso documentato dell'AI. Il progetto adotta un approccio dichiarativo (infrastructure as code: tutta la configurazione è nei file del repository), dimostra autonomia operativa su Kubernetes e troubleshooting analitico e fonda la diagnosi su evidenze raccolte realmente sul cluster.

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
- **Versione:** v0.10.7. Il manifest `release/kubernetes-manifests.yaml` è copiato **senza modifiche** in `k8s/base/boutique.yaml`; tutte le personalizzazioni sono negli overlay Kustomize.
- **Perché l'ho scelta:** È un'applicazione a microservizi reale con dipendenze gRPC tra i servizi, già predisposta per Kubernetes. Questo mi permette di testare scenari di guasto realistici da operatore L2  (ad esempio cosa succede quando un servizio backend non è più raggiungibile) senza dover scrivere l'applicazione.
- **Perimetro incluso:** 11 Deployment (10 microservizi + `redis-cart`) e il Service `frontend-external` esposto in locale.
- **Perimetro escluso (e perché):**
  - `loadgenerator` (genera traffico finto continuo): rimosso con una patch Kustomize nell'overlay `local` per risparmiare risorse CPU/RAM sulla VM e mantenere i log puliti durante l'analisi degli incidenti.
  - `shoppingassistantservice`: funzione opzionale, non presente nel manifest di base.

## 2. Architettura essenziale

Schema, tabella dei componenti e spiegazione del Dockerfile: **[docs/architecture.md](docs/architecture.md)**.

In breve: il browser raggiunge `http://localhost:30000` (tramite modifica file hosts locale `http://onlineboutique.local:30000`) → porta mappata da kind sul nodo → Service `frontend-external` (NodePort) → `frontend` → servizi gRPC interni (`ClusterIP`) → `redis-cart` per il carrello.

## 3. Prerequisiti e ambiente di test

| Strumento | Versione usata |
|---|---|
| Sistema operativo | Debian GNU/Linux 12 (bookworm) su VMware |
| CPU / RAM della VM | 4 vCPU / 7906 MiB RAM |
| Docker | 20.10.24+dfsg1 |
| kind | v0.34.0-alpha (versione riportata da `kind version`) |
| Immagine del nodo kind | `kindest/node:v1.31.0` (Kubernetes v1.31.0, fissata in `kind-config.yaml`) |
| kubectl | v1.37.1 |

Il comando `make doctor` verifica i prerequisiti, ovvere le dipendenze e la presenza degli strumenti, e stampa versioni e risorse hardware; il confronto con i valori consigliati (4 CPU, circa 8 GB di RAM) va fatto leggendo l'output.

Note sull'ambiente, emerse durante le prove:

- **Versioni:** kubectl v1.37.1 e cluster v1.31.0 distano più della differenza di una versione minore supportata ufficialmente; nelle mie prove ha funzionato, ma per una riesecuzione è preferibile un kubectl vicino alla versione del cluster (v1.30–v1.32).
- **DNS di Docker:** nella mia VM i pod sono finiti in `ErrImagePull` perché il resolver IPv6 non era raggiungibile (errore `lookup ... i/o timeout`). Ho risolto impostando i DNS in `/etc/docker/daemon.json` (`{"dns": ["8.8.8.8", "1.1.1.1"]}`) e riavviando Docker. Se in un altro ambiente i pull falliscono con errori di `lookup`, il primo controllo è questo.
- **Accesso dal browser:** l'applicazione è raggiunta su `localhost:30000` della macchina che ospita kind. Se kind gira in una VM e il browser è sull'host, serve inoltrare la porta 30000 della VM.

**Test eseguiti:** Il 31 Ottobre 2026 ho eseguito un ciclo completo (`doctor` → `cluster-up` → `deploy` → `wait-ready` → `smoke-test` → `verify` → incidente 1 con `evidence` e `recover` → incidente 2 con `evidence` e `recover` → `demo-reconfig` → `demo-scale` → `undeploy` → `cluster-down`). Il deploy completo, con download delle immagini, ha richiesto circa 5 minuti. Sono stati riprodotti con successo i due incidenti, raccolte le evidenze tramite il target `make evidence` e validato il ripristino dichiarativo tramite `make recover`.

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

L'applicazione risponde su **http://localhost:30000**. Il primo avvio richiede il download delle immagini dal registry di Google; in questa fase alcuni servizi possono riavviarsi.

## 5. Verifica del funzionamento

Output reale di `make verify` dopo `make deploy` (primo avvio, prima esecuzione sul cluster appena creato):

```text
kubectl --context kind-l2-challenge get deployments,pods -n challenge-l2
NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/adservice               1/1     1            1           2m7s
deployment.apps/cartservice             1/1     1            1           2m7s
deployment.apps/checkoutservice         1/1     1            1           2m7s
deployment.apps/currencyservice         1/1     1            1           2m7s
deployment.apps/emailservice            1/1     1            1           2m7s
deployment.apps/frontend                1/1     1            1           2m7s
deployment.apps/paymentservice          1/1     1            1           2m7s
deployment.apps/productcatalogservice   1/1     1            1           2m7s
deployment.apps/recommendationservice   1/1     1            1           2m7s
deployment.apps/redis-cart              1/1     1            1           2m7s
deployment.apps/shippingservice         1/1     1            1           2m7s

NAME                                         READY   STATUS    RESTARTS   AGE
pod/adservice-9745b7dfb-dvpz9                1/1     Running   0          2m7s
pod/cartservice-6dd594447-rxctj              1/1     Running   0          2m7s
pod/checkoutservice-775f8bf878-66667         1/1     Running   0          2m7s
pod/currencyservice-5dc84bf7d-h4zsd          1/1     Running   0          2m7s
pod/emailservice-87865b54d-pmwcg             1/1     Running   0          2m7s
pod/frontend-5d5bb549b-tch99                 1/1     Running   0          2m7s
pod/paymentservice-d45f6dcf6-98gh4           1/1     Running   0          2m7s
pod/productcatalogservice-68847998d4-4hc52   1/1     Running   0          2m7s
pod/recommendationservice-5b4d9cd76-wpvbs    1/1     Running   0          2m7s
pod/redis-cart-558f8d8d44-4hslw              1/1     Running   0          2m7s
pod/shippingservice-6545f454d4-xqlpl         1/1     Running   0          2m6s
kubectl --context kind-l2-challenge get svc,endpointslices -n challenge-l2
NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/adservice               ClusterIP   10.96.79.186    <none>        9555/TCP       2m7s
service/cartservice             ClusterIP   10.96.143.230   <none>        7070/TCP       2m7s
service/checkoutservice         ClusterIP   10.96.196.158   <none>        5050/TCP       2m7s
service/currencyservice         ClusterIP   10.96.81.50     <none>        7000/TCP       2m7s
service/emailservice            ClusterIP   10.96.131.152   <none>        5000/TCP       2m7s
service/frontend                ClusterIP   10.96.71.104    <none>        80/TCP         2m7s
service/frontend-external       NodePort    10.96.202.209   <none>        80:30000/TCP   2m7s
service/paymentservice          ClusterIP   10.96.77.73     <none>        50051/TCP      2m7s
service/productcatalogservice   ClusterIP   10.96.84.240    <none>        3550/TCP       2m7s
service/recommendationservice   ClusterIP   10.96.165.220   <none>        8080/TCP       2m7s
service/redis-cart              ClusterIP   10.96.103.202   <none>        6379/TCP       2m7s
service/shippingservice         ClusterIP   10.96.225.87    <none>        50051/TCP      2m7s

NAME                                                         ADDRESSTYPE   PORTS   ENDPOINTS     AGE
endpointslice.discovery.k8s.io/adservice-82gml               IPv4          9555    10.244.0.5    2m7s
endpointslice.discovery.k8s.io/cartservice-l6bkr             IPv4          7070    10.244.0.10   2m7s
endpointslice.discovery.k8s.io/checkoutservice-r7rbx         IPv4          5050    10.244.0.6    2m7s
endpointslice.discovery.k8s.io/currencyservice-tqd98         IPv4          7000    10.244.0.7    2m7s
endpointslice.discovery.k8s.io/emailservice-kncpx            IPv4          8080    10.244.0.12   2m7s
endpointslice.discovery.k8s.io/frontend-external-4x4pp       IPv4          8080    10.244.0.8    2m7s
endpointslice.discovery.k8s.io/frontend-kxgjx                IPv4          8080    10.244.0.8    2m7s
endpointslice.discovery.k8s.io/paymentservice-hkqbm          IPv4          50051   10.244.0.9    2m7s
endpointslice.discovery.k8s.io/productcatalogservice-hw7lj   IPv4          3550    10.244.0.11   2m7s
endpointslice.discovery.k8s.io/recommendationservice-8f8b7   IPv4          8080    10.244.0.13   2m7s
endpointslice.discovery.k8s.io/redis-cart-l2hnn              IPv4          6379    10.244.0.14   2m7s
endpointslice.discovery.k8s.io/shippingservice-sdpx8         IPv4          50051   10.244.0.15   2m7s

```

L'output dimostra che tutti i pod previsti dall'architettura sono instradati e attivi (Stato `Running`, colonna Ready `1/1`), a conferma del superamento dei controlli liveness e readiness impostati sui manifest.

**Nota sulle prestazioni di avvio**: Può succedere al primo avvio, quando la VM sta ancora scaricando immagini e avviando gli altri Pod che alcuni servizi non siano ancora in stato `Ready` (0/1) e che subiscano dei riavvii transitori.
Nel manifest upstream le probe non impostano il parametro `timeoutSeconds`, ereditando quindi il default stringente di Kubernetes di 1 secondo. La mia ipotesi, non verificata, è che alcuni container (es. i servizi Python) necessitino di più tempo per rispondere durante l'inizializzazione e quindi l'avvio.

Per questo `make wait-ready` da solo non basta come prova di salute: `condition=available` può risultare vera per un attimo anche se un Pod fallisce di nuovo la probe subito dopo. Di conseguenza ho implementato `make verify` per poter controllare che tutti i Pod siano `1/1`.

## 6. Comandi del Makefile

Tutti i comandi `kubectl` usano `--context kind-l2-challenge`, agendo in sicurezza solo sul cluster della challenge.

| Comando | Cosa fa |
|---|---|
| `make doctor` | Verifica prerequisiti software e stampa le risorse hardware della VM |
| `make cluster-up` / `down` | Gestione ciclo di vita del cluster kind `l2-challenge` |
| `make deploy` | Applica Kustomize overlay `local` |
| `make wait-ready` | Loop di attesa deterministica  `condition=available` su tutti i Deployment (max 300 s) |
| `make smoke-test` | Validazione applicativa HTTP silenziosa sul frontend (`grep` > `/dev/null`), cerca la stringa "Hot Products" nella home su `localhost:30000` |
| `make verify` | Stampa stato risorse core (Deployment, Pods, Service ed EndpointSlice) |
| `make trigger-incident-X` |  Applica l'overlay che introduce il guasto |
| `make diagnose` / `evidence` |  Raccolgono stato, eventi, describe dei Pod non pronti e log del frontend; `evidence` salva l'output in `docs/evidence/` con data e ora |
| `make recover` | Ripristino dichiarativo dell'infrastruttura (riapplica l'overlay `local` e attende `rollout status` e `available`) |
| `make demo-reconfig` | Riconfigurazione dichiarativa: banner del frontend da ConfigMap generato |
| `make undeploy` | Rimuove l'overlay Kustomize `local` |
| `make demo-scale` / `demo-scale-undo` | Riconfigurazione imperativa (scala il frontend a 2 repliche e torna a 1) per scopi di training L2, per confronto con l'approccio dichiarativo |

## 7. Demo

Il copione dettagliato è presente in **[docs/demo.md](docs/demo.md)**.

## 8. Troubleshooting L2

| Incidente | Componente Compromesso | Runbook |
|---|---|---|
| 1 – Errore di Pull | Tag inesistente sull'immagine del `frontend` | [docs/runbooks/incident-1-image.md](docs/runbooks/incident-1-image.md) |
| 2 – Service senza endpoint | Selector errato sul Service `productcatalogservice` | [docs/runbooks/incident-2-service.md](docs/runbooks/incident-2-service.md) |

Ogni runbook documenta gli step analitici reali: controlli iniziali, innesco, sintomo e impatto, evidenze raccolte con `make evidence`, ipotesi scartate o confermate, correzione, verifica del ripristino e criteri di escalation.

**Evidenze nel repository (`docs/evidence/`):**

- `diagnose-20261031-102032.txt`: evidenze dell'incidente 1.
- `diagnose-20261031-102948.txt`: evidenze dell'incidente 2.
- `web-site.png`: home di riferimento; `demo-reconfig.png`: banner dopo la riconfigurazione dichiarativa.
- `sito-err500/`: schermate dell'incidente 2, tra cui `checkout-err500.png` (HTTP 500 su `/cart/checkout`).

Gli output veri raccolti durante le prove sono in `docs/evidence/demo-transcript.txt`.

## 9. Rimozione e reinstallazione

- **Rimozione dell'applicazione:** `make undeploy` esegue `kubectl delete -k k8s/overlays/local --ignore-not-found`: elimina il namespace `challenge-l2` e tutte le risorse al suo interno. Il comando è ripetibile senza errori grazie a `--ignore-not-found`.
- **Reinstallazione sul cluster ancora attivo:** `make deploy` seguito da `make wait-ready` e `make verify`, la stessa procedura dell'installazione.
- **Rimozione dell'intero ambiente:** `make cluster-down` elimina il cluster kind `l2-challenge`.
- **Reinstallazione da zero:** `make cluster-up`, poi i passi del §4.

## 10. Sicurezza e configurazione

- **Nessuna credenziale nel codice e nessun Secret:** Online Boutique non richiede credenziali per il funzionamento base (il deploy crea solo ConfigMap, nessun Secret). Non ho inserito Secret finti nel repository: sarebbero credenziali in chiaro in Git, un anti-pattern di sicurezza. Se l'applicazione richiedesse credenziali (ad esempio una password per Redis), andrebbero in un Secret creato fuori da Git o gestito con uno strumento dedicato.  
- **Configurazione disaccoppiata:** Il banner informativo (`FRONTEND_MESSAGE`) viene iniettato tramite il `configMapGenerator` di Kustomize negli overlay `local` (valore vuoto) e `demo-reconfig` (banner attivo). Il nome generato contiene un hash del contenuto: se il messaggio cambia, cambia anche il nome del ConfigMap, forzando Kubernetes ad avviare autonomamente un nuovo rollout del Deployment senza bisogno di comandi imperativi.
- **Contesto esplicito bloccato (Safety-First):** Il Makefile utilizza sempre il flag `--context kind-l2-challenge`. Questa è una best practice operativa L2 per evitare che i comandi vengano inavvertitamente lanciati su cluster sbagliati (es. produzione) nel caso in cui il contesto attivo di kubeconfig sia differente.
- **Hardening nativo già presente nel manifest upstream:** i container usano già le best practices upstream `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false` e `capabilities: drop: [ALL]`.

## 11. Krateo e uso dell'AI

- Valutazione concettuale di Krateo (parametri, benefici, limiti): **[docs/krateo.md](docs/krateo.md)**
- Analisi critica del supporto AI (errori, test reali, validazioni manuali): **[docs/ai-usage.md](docs/ai-usage.md)**

## 12. Limiti noti

- **Riavvii al primo avvio:** `emailservice` e `recommendationservice` si riavviano alcune volte nei primi minuti per probe gRPC con timeout di 1 s; poi si stabilizzano. `make wait-ready` può risultare soddisfatto prima che tutti i Pod siano stabili.
- **Ambiente:** problema DNS IPv6 di Docker nella mia VM (risolto con `daemon.json`, vedi §3); kubectl v1.37.1 contro cluster v1.31.0, fuori dallo scarto di versione supportato; kind in versione non di release.
- **Archiviazione Volatile:** `redis-cart` utilizza un volume `emptyDir`. In caso di riavvio del pod, i carrelli attivi degli utenti andranno persi (nessuna persistenza tramite hostPath o PersistentVolumes).
- **Redis:** immagine `redis:alpine` con tag mobile (non fissato a una versione) e senza autenticazione.
- **Sicurezza di Rete e RBAC:** Il cluster non implementa `NetworkPolicy` restrittive né un RBAC dedicato per segregare i permessi. Il repository upstream offre un componente Kustomize `network-policies`, che ho escluso per mantenere il laboratorio essenziale.
- **Esposizione di Rete:** Il `NodePort` sulla porta `30000` espone il frontend su `0.0.0.0` (tutte le interfacce dell'host). In un ambiente reale, il traffico andrebbe ristretto e gestito tramite un Ingress Controller o un API Gateway.
- **Singolo Punto di Fallimento:** Il cluster `kind` utilizzato è a nodo singolo (control-plane e worker coincidono) e non garantisce alcuna High Availability (HA).
- **Gestione Immagini:** Le immagini dei container utilizzate nei manifest non sono state compilate localmente, ma vengono scaricate direttamente dal registry upstream di Google.
- **Cronologia Git:** nella cronologia del repository compare (e poi è stata rimossa) una password di esempio, mai usata in alcun sistema reale.
- **Gestione Secret:** Eventuali secret Kubernetes (seppur non richiesti da questa app) sarebbero solo codificati in base64. In un cluster di produzione, l'iniezione di credenziali reali richiederebbe strumenti di cifratura dedicati come Sealed Secrets o External Secrets.
- **Osservabilità Limitata:** Non sono state configurate metriche né dashboard. Il cluster è sprovvisto di `metrics-server`, rendendo indisponibili comandi base come `kubectl top`.
- **Non implementato (plus facoltativi):** GitOps con agente (Argo CD/Flux), metriche e dashboard, Ingress.

## 13. Tracciabilità dei requisiti

| Requisito della challenge | Dove lo trovi |
|---|---|
| Repository configurazioni, script, Makefile | Questo repository (root) |
| Manifest / Kustomize overlays | `k8s/base/`, `k8s/overlays/` |
| Immagini e Dockerfile (spiegazione) | `docs/architecture.md`, sezione 4 |
| Runbook operativi L2 con due scenari, correzione, escalation | `docs/runbooks/` |
| Schema architetturale e flussi | `docs/architecture.md` |
| Valutazione concettuale Krateo | `docs/krateo.md` |
| Uso dell'AI con verifiche manuali ed esempio di troubleshooting | `docs/ai-usage.md` |
| Plus: CI Workflow GitHub Actions | `.github/workflows/ci.yaml` |
| Plus: Diagnostica Automatizzata | target `diagnose` ed `evidence` nel `Makefile` |

## 14. Crediti e licenza

Il workload Online Boutique è di proprietà di Google LLC, distribuito con licenza **Apache 2.0**. Il file `k8s/base/boutique.yaml` mantiene l'intestazione upstream. Tutto il codice di infrastruttura aggiuntivo e i runbook prodotti per questa challenge sono liberi e resi disponibili a scopo di valutazione tecnica.