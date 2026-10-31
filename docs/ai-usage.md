# Uso Critico e Responsabile dell'AI

Il progetto ha impiegato l'assistente Gemini come strumento di confronto, analisi diagnostica e revisione (pair-programming), sottoponendo ogni output a rigorosa validazione manuale (CLI validation). 

## 1. Regole Operative Adottate
- **Divieto di Dati Sensibili:** Nessun indirizzo IP reale, password di laboratorio o credenziale è stata immessa nel prompt.
- **Validazione Empirica:** La diagnosi fornita dall'IA è stata accettata solo se matematicamente confermabile dai log (`kubectl describe`, `logs`) della VM locale.
- **Zero-Trust per il Codice:** Ogni frammento YAML suggerito è stato ispezionato visivamente o tramite `kustomize build` prima dell'esecuzione.

## 2. Casi Pratici e Correzioni Manuali all'IA

### Caso 1: L'errore della degradazione applicativa (Incidente 2)
- **Suggerimento IA:** Durante l'analisi teorica del guasto sul Service `productcatalogservice`, l'intelligenza artificiale aveva stabilito con certezza che "La home page genererà un errore HTTP 500 perché non trova il catalogo".
- **Verifica Manuale:** L'esecuzione di `curl -I localhost:30000` ha restituito inequivocabilmente `HTTP/1.1 200 OK`. L'errore 500 si innescava solo nella successiva route `/cart/checkout`. 
- **Esito e Correzione:** L'IA aveva torto. È stato dimostrato che il microservizio Frontend in linguaggio Go implementa un pattern di resilienza interno, servendo una home page intatta ma vuota anziché andare in crash. I documenti finali riflettono la realtà osservata sul terminale, non l'ipotesi della macchina.

### Caso 2: Risoluzione bug DNS IPv6 su Kind/VMware
- **Problema:** I pod originali di Google rimanevano improvvisamente in `ErrImagePull`, nonostante il manifest fosse upstream.
- **Diagnosi IA:** Richiedendo l'analisi della riga di errore `lookup ... on [fd33:...]:53: i/o timeout` presente nel target `make evidence`, Gemini ha isolato immediatamente un bug noto di Docker su Linux VM, in cui il container tentava invano di risolvere URL IPv4 tramite server DNS IPv6 non instradabili.
- **Azione:** Impostazione manuale di `{"dns": ["8.8.8.8", "1.1.1.1"]}` in `/etc/docker/daemon.json` e riavvio del daemon, che ha ripristinato l'infrastruttura definitivamente.

### Caso 3: Fix per "Broken Pipe" di curl nel Makefile
- **Problema:** Il comando `make smoke-test` superava il test, ma generava l'avviso antiestetico `curl: (23) Failure writing output to destination`.
- **Risoluzione Congiunta:** L'IA ha spiegato la meccanica UNIX dei segnali (`SIGPIPE`), in cui `grep -q` interrompe forzatamente la comunicazione di `curl` dopo il primo match. Ho deciso quindi di rimuovere il quiet tag `-q` di grep redirezionando l'output standard verso `> /dev/null`, ottenendo un workflow L2 pulito e senza warning.