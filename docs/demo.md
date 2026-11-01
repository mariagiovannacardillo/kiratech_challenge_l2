# Copione della demo

Durata prevista: circa 15 minuti. Ogni riga della scaletta corrisponde a un punto della demo obbligatoria della traccia.

## Prima della demo

- `make doctor` eseguito con esito positivo; cluster pulito: `make cluster-down`, poi `make cluster-up`.
- Browser pronto su `http://localhost:30000` (nessuna modifica al file hosts necessaria).
- Prima prova completa della sequenza esatta della demo, almeno una volta, nello stesso ordine in cui la presento. Il comportamento dell'incidente 2 (home che risponde, checkout in errore) l'ho osservato nella prova del 31/10; lo ricontrollo nella stessa sequenza della demo.
- Terminale con `alias k='kubectl --context kind-l2-challenge -n challenge-l2'`.

## Scaletta

| Punto della traccia | Cosa faccio e dico |
|---|---|
| 1. Struttura del repo | **Azione:** `tree -L 2 .` e `tree k8s/`<br>**Dico:** "`k8s/base` è il manifest upstream, invariato. Le mie personalizzazioni sono negli `overlays`: `local`, `demo-reconfig` e i due incidenti, ognuno cambia pochissime righe." |
| 2. Ambiente locale | **Azione:** `make doctor`, `kind get clusters`<br>**Dico:** "Cluster kind a un nodo, Kubernetes v1.31.0, creato con `make cluster-up`." |
| 3. Installazione | **Azione:** `make deploy` e `make wait-ready`<br>**Dico:** "Applico l'overlay `local` in modo dichiarativo. Ho escluso il `loadgenerator` per risparmiare RAM sulla VM e tenere puliti i log." |
| 4. Verifica di Pod e Service | **Azione:** `make verify`<br>**Dico:** "11 Deployment e 11 Pod, 12 Service: 11 `ClusterIP` e `frontend-external` di tipo NodePort sulla 30000. Se `emailservice` o `recommendationservice` mostrano riavvii, è l'effetto delle probe al primo avvio, descritto nel README." |
| 5. Accesso all'applicazione | **Azione:** apro `http://localhost:30000`, poi `make smoke-test`<br>**Dico:** "Lo smoke test cerca la stringa 'Hot Products' nella home: controlla la home, non il checkout." |
| 6. Log, eventi, stato | **Azione:** `k get pods -o wide`, `k get events --sort-by=.lastTimestamp \| tail -n 15`, `k logs -l app=frontend --tail=20 \| grep -v _healthz`, `k describe deployment frontend \| head -n 40`<br>**Dico:** "Parto sempre da stato, eventi e log. Nei log del frontend filtro le righe delle probe `/_healthz`, altrimenti coprono tutto il resto." |
| 7. Riconfigurazione | **Azione:** `make demo-reconfig`, ricarico il browser (compare il banner); poi `make demo-scale` e `make demo-scale-undo`<br>**Dico:** "Modifica dichiarativa: cambia il contenuto del ConfigMap generato, il nome cambia (hash), il Deployment lo referenzia e parte un rollout. La scala imperativa, invece, non è tracciata in Git: la mostro per confronto." |
| 8. Errore semplice e diagnosi | **Azione (incidente 2):** `make trigger-incident-2`; `make verify` (tutti i Pod `Running`); apro `/cart/checkout` (errore 500); poi `k get svc productcatalogservice -o wide`, `k get pods -l app=productcatalogservice --show-labels`, `k get endpointslices \| grep productcatalog`; poi `make evidence`<br>**Dico:** "I Pod sono tutti Ready perché le probe controllano il container, non il percorso di rete. Il Service ha un selector (`app=productcatalog-rotto`) che non corrisponde alla label dei Pod (`app=productcatalogservice`), quindi non ha endpoint: nell'EndpointSlice vedo `<unset>`. Il checkout fallisce con `failed to get product`." <br>**Poi:** `make recover` e ripeto il checkout. *(Se avanza tempo: incidente 1, `make trigger-incident-1`, `k get pods -l app=frontend`, `k describe pod`, `make recover`.)* |
| 9. Rimozione e reinstallazione | **Azione:** `make undeploy`, `k get ns` (il namespace non c'è più), poi `make deploy` e `make wait-ready`<br>**Dico:** "Rimuovo tutto con un comando e reinstallo con gli stessi comandi dell'installazione. Per eliminare l'intero ambiente: `make cluster-down`." |
| 10. Krateo | **Azione:** apro `docs/krateo.md`<br>**Dico:** "Non l'ho installato. Ho valutato come i miei overlay potrebbero diventare un template con pochi parametri, e quali limiti ha: convertire in Helm chart, un componente in più da gestire." |
| 11. Uso dell'AI | **Azione:** racconto il **Caso 1** di `docs/ai-usage.md`<br>**Dico:** "L'AI aveva previsto che la home desse errore 500. Ho misurato: la home risponde 200 e solo il checkout dà 500. Ho riportato nei documenti ciò che ho osservato, non la previsione." |

## Frasi chiave L2

- *"Raccolgo prima le evidenze (stato, eventi, describe, log), isolo l'ambito e solo dopo agisco."*
- *"Uso `make recover` per un ripristino dichiarativo: riapplico lo stato descritto nel repository invece di correggere a mano nel cluster con `kubectl edit`, che lascerebbe il cluster diverso da Git."*
- *"Se la causa non è chiara dopo i controlli del runbook, faccio escalation allegando l'output di `make evidence`."*

## Piano B (se la rete, le immagini o il cluster non funzionano)

- Mostro gli output già raccolti: `docs/evidence/diagnose-20261031-102032.txt` (incidente 1), `docs/evidence/diagnose-20261031-102948.txt` (incidente 2) e le schermate in `docs/evidence/` (`web-site.png`, `demo-reconfig.png`, `sito-err500/checkout-err500.png`).
- Se il cluster è già acceso ma l'applicazione non risponde: `make verify` e `k get events --sort-by=.lastTimestamp`, e spiego cosa guarderei.
- Se una prova in diretta fallisce, lo dico e lo uso come esercizio di troubleshooting: stato, eventi, ipotesi, correzione.
