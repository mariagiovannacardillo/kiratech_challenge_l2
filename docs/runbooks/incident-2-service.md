# Runbook L2 – Incidente 2: Service senza endpoint 

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
| **Come lo innesco** | `make trigger-incident-2` |
| **Cosa cambia** | Viene alterato il selector del Service `productcatalogservice` in modo che punti a `app: productcatalog-rotto` |
| **Come ripristino** | `make recover` |

## 2. Sintomo e impatto

- **Sintomo osservato:** Ingestibile dai semplici alert di stato: tutti i Pod del cluster (incluso il `productcatalogservice`) restano rigidamente `Running 1/1`. Le probe (`/_healthz`) monitorano il container, ignorando l'instradamento di rete.
- **Impatto sull'utente (Degradazione Silenziosa):** 
  - La route base non collassa: `curl -I localhost:30000` restituisce `HTTP/1.1 200 OK`. 
  - Il blocco critico (Incidente P1) avviene al momento dell'acquisto: navigando verso `/cart/checkout`, la transazione fallisce con **HTTP Status: 500 Internal Server Error** (Stack: `rpc error: code = Internal desc = failed to prepare order`).
  - L'output di controllo di `make smoke-test` fallisce.

## 3. Evidenze raccolte (Output da make evidence)

| Strumento Diagnostico | Evidenza Rilevata |
|---|---|
| `k get pods` | Tutti i container in stato `Running 1/1`. |
| `k get endpoints productcatalogservice` | Restituisce `<none>`. |
| `k logs -l app=frontend` | Nessun errore di connessione (`200 OK` sulle route di base e probe). |

## 4. Ipotesi e causa confermata

| Ipotesi | Analisi | Esito |
|---|---|---|
| H1: Il Pod `productcatalogservice` è in crash loop o Out of Memory (OOMKilled). | Analisi dei restart dei Pod tramite `k get pods`. | Esclusa (0 restarts recenti). |
| H2: Disconnessione a livello di Service Mesh / Instradamento. | Verifica degli EndpointSlice per il servizio associato (`k get endpoints`). | **Confermata** (Output `<none>`). |

**Causa confermata:** Disallineamento tra il Selettore K8s specificato nel servizio e la reale Label appesa al Pod running. Di conseguenza, il traffico inter-pod verso la route gRPC `productcatalog` si perde, provocando un collasso a cascata del `checkoutservice`.

## 5. Correzione

```bash
make recover
```
Ripristinando dichiarativamente il manifest di base, il selettore del Service torna a mappare il pod corretto. Eseguendo nuovamente `k get endpoints`, l'indirizzo IP del catalogo si è ripopolato al posto del parametro `<none>`.

## 6. Criteri di escalation (L3 / SRE)
Avvio procedura di escalation tecnica qualora:
- Gli endpoint siano correttamente popolati con gli IP corretti, ma l'errore 500 su checkout persista (sintomo di policy di rete bloccanti, esaurimento porte o timeout).
- Allego nel ticket SRE lo screenshot dell'errore applicativo 500, l'estratto dei log del frontend ed il documento formattato estratto da `make evidence`.