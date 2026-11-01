# Runbook L2 – Incidente 2: Service senza endpoint 

```bash
alias k='kubectl --context kind-l2-challenge -n challenge-l2'
```

Evidenze reali: `docs/evidence/diagnose-20261031-102948.txt` (EndpointSlice, eventi, log) e screenshot in `docs/evidence/sito-err500/` e `docs/evidence/web-site.png` (home di riferimento).

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
| **Come lo innesco** | `make trigger-incident-2` |
| **Cosa cambia** | L'overlay `incident-2` altera il selector del Service `productcatalogservice` in `app: productcatalog-rotto`; i Pod del catalogo mantengono invece la label corretta `app: productcatalogservice`. |
| **Come ripristino** | `make recover` (Riallineamento all'overlay `local`) |

## 2. Sintomo e impatto

- **Sintomo osservato:** Nessun allarme dallo stato dei Pod. Tutti i container (incluso il `productcatalogservice`) restano rigidamente `Running 1/1`. 
  - *Motivazione tecnica:* Le probe del catalogo sono gRPC e il demone `kubelet` le esegue direttamente sull'IP del Pod, ignorando i fallimenti di instradamento di rete a livello di Service. (Le probe HTTP `/_healthz` sono invece esclusive del frontend).
- **Impatto sull'utente (Degradazione Silenziosa e Guasto a Cascata):** 
  - La route base non collassa: `curl -I localhost:30000` restituisce `HTTP/1.1 200 OK`. Il frontend gestisce l'assenza del catalogo senza andare in crash totale.
  - L'output di controllo `make smoke-test` continua a passare, poiché cerca la stringa "Hot Products" nella home. Questo è un limite intrinseco del test, non del cluster.
  - **Effetto a cascata:** Il blocco critico (Incidente P1) esplode al momento dell'acquisto: navigando verso `/cart/checkout`, la transazione fallisce a cascata con **HTTP Status: 500 Internal Server Error** (Stack: `rpc error: code = Internal desc = failed to prepare order: failed to get product`). 

## 3. Evidenze raccolte (Output da make evidence e CLI)

| Strumento Diagnostico | Evidenza Rilevata |
|---|---|
| `k get pods` | Tutti i container in stato `Running 1/1`. |
| `k get endpointslices` | L'EndpointSlice di `productcatalogservice` risulta con `PORTS <unset>` ed `ENDPOINTS <unset>`. |
| `k get svc productcatalogservice -o wide` | Colonna SELECTOR risulta errata: `app=productcatalog-rotto`. |
| `k get pods -l app=productcatalogservice --show-labels` | Il pod in esecuzione porta la label `app=productcatalogservice`. Non c'è match con il Service. |
| `k logs -l app=frontend --tail=300 \| grep -v _healthz` | Applicando il filtro `grep -v _healthz` (per rimuovere il rumore delle liveness probe) emerge l'errore fatale del checkout. |

## 4. Ipotesi e causa confermata

| Ipotesi | Analisi / Come la verifico | Esito |
|---|---|---|
| H1: Il Pod `productcatalogservice` è in crash loop o Out of Memory. | Analisi dei restart e dei log tramite `k get pods` e `k logs`. | Esclusa (Pod in stato `Ready 1/1`, 0 restart). |
| H2: Disconnessione a livello di Service (Selector errato). | Confronto tra il Selector K8s del Service e le Label reali del Pod; verifica degli endpoint tramite `k get endpointslices`. | **Confermata** (EndpointSlice `<unset>`). |
| H3: `targetPort` del Service sbagliata. | Controllo corrispondenza `targetPort` (3550). | Esclusa (Senza endpoint, la porta non viene nemmeno testata). |
| H4: Problema DNS (CoreDNS). | Verifica eventi cluster e raggiungibilità altri servizi. | Esclusa |

**Causa confermata:** Disallineamento critico tra il Selettore specificato nel Service e la Label appesa al Pod. Il traffico inter-pod verso la route gRPC `productcatalog` si perde nel vuoto, provocando un collasso a cascata del `checkoutservice` al momento dell'acquisto.
- *Nota (Ipotesi non verificata):* La home continua a rispondere probabilmente perché le connessioni gRPC aperte *in precedenza* dal frontend verso il catalogo non si sono interrotte al cambio degli endpoint (Connection Pooling). Per validare empiricamente l'ipotesi, basterebbe forzare un `kubectl rollout restart deployment/frontend` a incidente attivo e ricaricare la home.

## 5. Correzione

**Opzione A: Rapida / Imperativa (Solo per emergenze)**
```bash
k patch svc productcatalogservice -p '{"spec":{"selector":{"app":"productcatalogservice"}}}'
```
*Nota operativa:* Ripristina istantaneamente l'instradamento di rete, ma crea un disallineamento (drift) temporaneo tra lo stato del cluster e il repository Git.

**Opzione B: Dichiarativa / GitOps (Consigliata e adottata)**
```bash
make recover
```
*Nota operativa:* Ripristinando dichiarativamente l'overlay `local`, il selettore del Service torna a mappare correttamente la label del Pod, allineando l'infrastruttura alla *Single Source of Truth*.

## 6. Verifica del ripristino

Al termine della correzione, eseguo i controlli di integrità di rete e applicativi:

```bash
k get svc productcatalogservice -o wide
# Output atteso: SELECTOR torna a app=productcatalogservice

k get endpointslices | grep productcatalog
# Output atteso: L'EndpointSlice non è più <unset>, ha acquisito IP e porta 3550.

make verify
# Output atteso: Tutti i Pod 1/1
```
**Verifica applicativa (Manuale):** Ricaricando la pagina `/cart/checkout` dal browser ed effettuando l'acquisto, la transazione torna a completarsi senza l'errore 500.

## 7. Criteri di escalation (L3 / SRE)

Avvio immediatamente la procedura di escalation tecnica qualora:
- Selettore e label **coincidono**, gli endpoint sono correttamente popolati con gli IP, ma l'errore 500 sul checkout persiste (sintomo di policy di rete bloccanti, esaurimento porte, o timeout CNI/DNS fuori dal perimetro L2).
- I Pod di `productcatalogservice` perdono inaspettatamente lo stato di `Ready 1/1` e i log non evidenziano eccezioni applicative chiare.
- Il problema di assenza di endpoint si estende improvvisamente a più Service contemporaneamente.
- Dopo aver eseguito la correzione con `make recover`, il sintomo non rientra entro **5 minuti**.

**Cosa allego al ticket:** Il documento testuale generato da `make evidence`, uno screenshot dell'errore 500 al checkout, l'orario esatto di innesco dell'anomalia, l'output dei comandi `k get svc productcatalogservice -o wide` e `k get pods -l app=productcatalogservice --show-labels`, insieme all'estratto dei log del frontend filtrato dal rumore delle probe.