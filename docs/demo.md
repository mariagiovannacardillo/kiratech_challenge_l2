# Copione della demo

Durata prevista: circa 15 minuti. Ogni riga della scaletta corrisponde a un punto della demo obbligatoria della traccia.

## 1. Prima della demo (Checklist 30 minuti prima)

- [ ] Ambiente base: RAM libera sulla VM Debian, nessun container pesante attivo.
- [ ] Rete: File hosts di Windows configurato per risolvere `onlineboutique.local` (o fallback su `localhost:30000`).
- [ ] Cluster: `make cluster-down` e inizializzato tramite `make cluster-up`. Immagini Docker già pullate per accelerare il deploy.
- [ ] Contesto K8s: `kubectl config current-context` mostra `kind-l2-challenge`.
- [ ] GUI e Terminale: Browser pronto sulla tab del frontend, terminale con font ingrandito.
- [ ] Alias pronto: `alias k='kubectl --context kind-l2-challenge -n challenge-l2'`.
- [ ] Prova a secco: Eseguita almeno una prova completa della demo mantenendo questa esatta sequenza.

## 2. Scaletta Esecutiva

| Minuti | Punto della traccia | Azione | Cosa mostro e Dico |
|---|---|---|---|
| 1 | Struttura del repo | `tree -L 2 .` e `tree k8s/` | "Mostro la separazione netta tra la risorsa upstream (`base`) e le logiche customizzate e isolate negli `overlays` (local, demo-reconfig, incidenti)." |
| 1-2 | Ambiente e Deploy | `make deploy`, poi `make wait-ready` | "Applico l'overlay `local` in modo dichiarativo. Ho escluso il `loadgenerator` per risparmiare RAM sulla VM e tenere puliti i log durante il troubleshooting." |
| 1 | Accesso e Stato | `make verify`, apro browser | "Tutti i 12 container sono operativi. Se `emailservice` mostra dei restart iniziali, è il normale effetto del timeout (1s) delle probe al primo avvio a freddo, come documentato nel README." |
| 1 | Log e Osservabilità | `k get events --sort-by=.lastTimestamp \| tail -n 15`<br>`k logs -l app=frontend --tail=20 \| grep -v _healthz` | "Parto sempre dallo stato e dagli eventi. Dai log applicativi filtro le chiamate costanti delle probe (`_healthz`), altrimenti inquinano l'output e coprono gli errori reali." |
| 1 | Riconfigurazione | `make demo-reconfig` e `make demo-scale` | "Modifica dichiarativa: il ConfigMap cambia payload, cambia il suo hash, il Deployment lo referenzia e Kubernetes avvia il rollout. La scala imperativa, invece, la mostro per confronto ma non essendo in Git crea drift." |
| 3 | Analisi Incidente | `make trigger-incident-2`<br>apro `/cart/checkout`<br>`k get pods -l app=productcatalogservice --show-labels`<br>`k get endpointslices \| grep productcatalog`<br>`make evidence` | "Innesco l'incidente. I pod restano `Ready`, ma il checkout dà HTTP 500. Vi mostro la causa: il Service ha un selector errato che non mappa le label dei Pod, quindi l'EndpointSlice è `<none>`. Salvo l'evidenza per il ticket." |
| 1 | Ripristino | `make recover` | "Eseguo il ripristino allineando forzatamente il cluster a Git (GitOps). È molto più sicuro di un fix imperativo come `kubectl edit`, che lascerebbe il cluster disallineato dal repository." |
| 1 | Rimozione pulita | `make undeploy`<br>`k get ns` | "Dimostro l'idempotenza e la pulizia del sistema: rimuovo l'intera infrastruttura con un comando. Il namespace scompare." |
| 1 | Krateo & Platform | Apro `krateo.md` | "Sintetizzo come Krateo potrebbe astrarre tutto il lavoro fatto finora con Kustomize, offrendo al developer un form web e riconciliando le configurazioni tramite Helm e CRD." |
| 1 | Uso critico dell'IA | Racconto Caso 1 da `ai-usage.md` | "L'IA aveva previsto che per l'incidente 2 la home desse errore 500. Eseguendo i test ho misurato che la home risponde 200 e solo il checkout dà 500. Ho documentato la realtà osservata, confermando lo zero-trust." |

## 3. Frasi chiave da inserire nel discorso (Mindset L2)

- *"Raccolgo prima le evidenze diagnostiche (stato, eventi, describe, log), isolo l'ambito e solo dopo agisco."*
- *"Non ho modificato i manifest upstream: ogni differenza sta in un overlay, quindi è visibile, versionabile e reversibile."*
- *"Se la causa non fosse risultata chiara dai log, avrei scalato al livello superiore allegando i log strutturati raccolti tramite `make evidence`."*

## 4. Domande di sbarramento (Ripasso Tecnico)

1. **Perché base + overlay invece di modificare il manifest?** (Immutabilità del codice upstream, facilità di aggiornamento versioni).
2. **Differenza tra `kubectl apply -f`, `apply -k` e `kustomize build`?** (`-f` per file diretti, `-k` per compilare overlay al volo, `build` solo per generare e ispezionare il manifest finale in stdout).
3. **Cosa succede, passo per passo, quando metti un'immagine inesistente?** (ReplicaSet crea un nuovo pod, fallisce il pull, va in ImagePullBackOff, ma il rolling update non uccide il vecchio pod).
4. **Un Pod è `Running` ma `0/1`: cosa controlli?** (La *readiness probe* fallisce, il pod è vivo - liveness ok - ma non è pronto a ricevere traffico).
5. **Cosa fa `kind` e perché la porta 30000 raggiunge il frontend?** (Mappa l'hostPort di Windows 30000 sul NodePort della VM, che instrada al Service `frontend-external`, che manda il traffico al Pod).
6. **Cosa cambierebbe in produzione?** (Secret cifrati via SOPS/External Secrets, RBAC severo, NetworkPolicy deny-all, risorse limitate per namespace, metriche Prometheus/Grafana).

## 5. Piano B (Contingenza di Rete/Ambiente)

In caso di freeze della macchina virtuale, crollo del cluster o problemi di connettività durante la live:
- **Niente panico:** Dichiaro apertamente il problema tecnico e lo converto in un esercizio di esposizione.
- **Transcript Testuale:** Apro immediatamente il file `docs/demo-transcript.txt` e scorro l'esecuzione cronologica e idempotente registrata con successo.
- **Evidenze e Screenshot:** Mostro i file di testo diagnostici generati in `docs/evidence/` (es. `diagnose-20261031-102948.txt`) e gli screenshot salvati per l'incidente 500, dimostrando che il lavoro è stato interamente validato sul campo.