# Uso Critico e Responsabile dell'AI

Il progetto ha impiegato assistenti AI come strumenti di confronto, analisi diagnostica e revisione (pair-programming), sottoponendo ogni output a rigorosa validazione manuale (CLI validation). Ho tenuto la totale responsabilità di ciò che è nel repository: ogni risposta è stata letta, provata sul mio cluster e, dove necessario, corretta.

## 1. Strumenti usati

| Strumento | Per cosa | Note |
|---|---|---|
| **Google Gemini** | Analisi diagnostica durante lo sviluppo e il troubleshooting (manifest, errori complessi K8s, comandi Bash). | Utilizzato principalmente per revisionare il `Makefile` e analizzare i log di rete. |
| **Claude** | Revisione finale della documentazione e controllo di coerenza tra documenti, log ed evidenze diagnostiche. | Impiegato per uniformare il tono tecnico e formattare i runbook. |

## 2. Regole Operative Adottate

- **Divieto di Dati Sensibili:** Nessun indirizzo IP reale, password di laboratorio o credenziale è stata immessa nei prompt.
- **Comprensione Pre-Esecuzione:** Non ho mai eseguito comandi generati dall'IA senza prima averne compreso la logica e gli effetti.
- **Validazione Empirica (Zero-Trust):** La diagnosi fornita dall'IA è stata accettata solo se matematicamente confermabile dai log (`kubectl describe`, `logs`) della mia VM locale. Ogni frammento YAML o Kustomize è stato ispezionato visivamente o tramite `kustomize build` (`kubectl kustomize`) prima dell'applicazione.

## 3. Casi Pratici e Correzioni Manuali all'IA

### Caso 1: L'errore della degradazione applicativa (Incidente 2)
- **Suggerimento IA:** Durante l'analisi teorica del guasto sul Service `productcatalogservice`, l'intelligenza artificiale aveva stabilito con certezza che "La home page genererà un errore HTTP 500 perché non trova il catalogo".
- **Verifica Manuale:** Dopo aver innescato l'incidente, `curl -I localhost:30000` ha restituito inequivocabilmente `HTTP/1.1 200 OK`. L'errore 500 si innescava solo nella successiva route `/cart/checkout`. Nell'evidenza `diagnose-20261031-102948.txt` l'EndpointSlice risultava `<unset>`.
- **Esito:** L'IA aveva torto. I documenti finali (Runbook) riflettono la realtà osservata sul terminale, non l'ipotesi della macchina.
- **Ipotesi sul perché la home regge (Non Verificata):** Le connessioni gRPC verso il catalogo (Connection Pooling) potrebbero non interrompersi quando cambiano gli endpoint del Service, mentre il checkout apre la sua connessione *ex novo* dopo l'incidente. Per verificarlo empiricamente, a incidente attivo, dovrei riavviare il frontend (`kubectl rollout restart deployment/frontend`) e ricaricare la home: se l'ipotesi è corretta, andrebbe in 500.

### Caso 2: Risoluzione bug DNS IPv6 su Kind/VMware
- **Problema:** Durante un deploy, i container upstream fallivano improvvisamente il download restando in `ErrImagePull`.
- **Diagnosi IA:** Richiedendo l'analisi della riga di errore `lookup ... on [fd33:...]:53: i/o timeout` generata da `make evidence`, Gemini ha spiegato che il resolver DNS configurato era un indirizzo IPv6 non raggiungibile. Ha correlato questo log a un bug noto di Docker su Linux VM.
- **Azione:** Ho impostato manualmente `{"dns": ["8.8.8.8", "1.1.1.1"]}` in `/etc/docker/daemon.json` e riavviato il daemon, ripristinando l'infrastruttura definitivamente. L'IA mi ha risparmiato ore di debug di rete.

### Caso 3: Fix per "Broken Pipe" di curl nel Makefile
- **Problema:** Il comando `make smoke-test` superava il test, ma generava l'avviso antiestetico `curl: (23) Failure writing output to destination`.
- **Risoluzione Congiunta:** L'IA ha spiegato la meccanica UNIX dei segnali (`SIGPIPE`), in cui `grep -q` interrompe forzatamente la comunicazione di `curl` dopo il primo match. Ho deciso quindi di rimuovere il quiet tag `-q` di grep redirezionando l'output standard verso `> /dev/null`, ottenendo un workflow L2 pulito.

### Caso 4: Errori trovati nei suggerimenti per gli overlay
- **Problema:** Una versione iniziale dell'overlay `incident-1` suggerita dall'AI generava un manifest inefficace.
- **Come l'ho scoperto:** Confrontando l'output di `kubectl kustomize k8s/overlays/incident-1` con quello di `local`, risultavano identici. L'IA proponeva fix YAML sintatticamente validi ma logicamente nulli.
- **Correzione:** Ho scartato il suggerimento e riscritto manualmente l'overlay sfruttando la direttiva nativa `images:` di Kustomize.

## 4. Matrice di Affidabilità: Cosa ho verificato e cosa no

| Contenuto | Stato di Validazione |
|---|---|
| Deploy, Incidenti, Ripristino (GitOps), Rimozione | Eseguiti rigorosamente sul mio cluster; output in `docs/evidence/` |
| Esito applicativo dell'Incidente 2 | Osservato empiricamente tramite `curl` (home HTTP 200, checkout HTTP 500) |
| Perché la home regge nell'Incidente 2 | Ipotesi teorica (Connection Pooling), non verificata (vedi Caso 1) |
| Causa dei riavvii di `emailservice` al primo avvio | Coerente con gli eventi (probe stringente timeout 1s), ma non verificata con ulteriori test isolati |
| Valutazione architetturale di Krateo | Esclusivamente concettuale (documentazione ufficiale); componente non installato |

## 5. Limiti dell'AI riscontrati

Durante questo progetto, ho notato che l'IA tende ad essere "eccessivamente sicura", presentando come certezze assolute previsioni teoriche che invece vanno misurate sul campo (Caso 1). Spesso propone file YAML che non generano errori in console, ma non producono l'effetto infrastrutturale desiderato (Caso 4). Infine, l'IA non possiede consapevolezza del layer infrastrutturale sottostante (es. i colli di bottiglia della VM locale): le cause ambientali legate a cali di risorse o timeout di rete le ho dovute dedurre e isolare io stesso analizzando gli eventi del cluster.