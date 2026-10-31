.PHONY: doctor cluster-up cluster-down deploy undeploy wait-ready smoke-test verify diagnose evidence trigger-incident-1 trigger-incident-2 recover demo-reconfig demo-scale demo-scale-undo

# Variabili d'ambiente
CLUSTER_NAME := l2-challenge
NS := challenge-l2
KCTX := --context kind-$(CLUSTER_NAME)
KC := kubectl $(KCTX)

doctor:
	@echo "=== Controllo prerequisiti di sistema ==="
	@command -v docker >/dev/null 2>&1 || { echo >&2 "Docker non trovato."; exit 1; }
	@docker info >/dev/null 2>&1 || { echo >&2 "Demone Docker non attivo."; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo >&2 "Kubectl non trovato."; exit 1; }
	@command -v kind >/dev/null 2>&1 || { echo >&2 "Kind non trovato."; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo >&2 "Curl non trovato."; exit 1; }
	@echo "docker : $$(docker --version)"
	@echo "kind   : $$(kind version)"
	@echo "kubectl: $$(kubectl version --client 2>/dev/null | head -n 1)"
	@echo "CPU    : $$(nproc) core (consigliati: almeno 4)"
	@echo "RAM    : $$(free -m | awk '/^Mem:/ {print $$2}') MiB (consigliati: almeno 8000)"
	@echo "Diagnostica completata: tool di base operativi. Verificare visivamente che l'hardware rilevato rispetti i valori consigliati."

cluster-up:
	kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml
	$(KC) get nodes

cluster-down:
	kind delete cluster --name $(CLUSTER_NAME)

deploy:
	$(KC) apply -k k8s/overlays/local

undeploy:
	$(KC) delete -k k8s/overlays/local --ignore-not-found

wait-ready:
	$(KC) wait --for=condition=available deployment --all -n $(NS) --timeout=300s

smoke-test:
	curl -fsS http://localhost:30000/ | grep "Hot Products" > /dev/null && echo "Smoke test superato" || { echo "Smoke test fallito"; exit 1; }

verify:
	$(KC) get deployments,pods -n $(NS)
	$(KC) get svc,endpointslices -n $(NS)

# Raccoglie le evidenze da allegare a un'escalation (Pod, Service, EndpointSlice, eventi, describe dei Pod non pronti, log)
diagnose:
	@echo "### DATA: $$(date -Iseconds)   CONTESTO: kind-$(CLUSTER_NAME)   NAMESPACE: $(NS)"
	@echo; echo "### DEPLOYMENT E POD"; $(KC) get deployments,pods -o wide -n $(NS)
	@echo; echo "### SERVICE ED ENDPOINTSLICE"; $(KC) get svc,endpointslices -n $(NS)
	@echo; echo "### ULTIMI EVENTI"; $(KC) get events -n $(NS) --sort-by=.lastTimestamp | tail -n 25
	@echo; echo "### POD NON PRONTI (describe)"; \
	for p in $$($(KC) get pods -n $(NS) --no-headers | awk '{split($$2,a,"/"); if (a[1]!=a[2]) print $$1}'); do \
	    echo "--- $$p"; $(KC) describe pod $$p -n $(NS) | tail -n 25; \
	done
	@echo; echo "### LOG FRONTEND (ultime 30 righe per Pod)"; $(KC) logs -l app=frontend -n $(NS) --tail=30 --prefix || true

# Salva l'output di diagnose in docs/evidence/ con data e ora
evidence:
	@mkdir -p docs/evidence
	@f=docs/evidence/diagnose-$$(date +%Y%m%d-%H%M%S).txt; $(MAKE) --no-print-directory diagnose > $$f 2>&1; echo "Evidenze salvate in $$f"

trigger-incident-1:
	$(KC) apply -k k8s/overlays/incident-1

trigger-incident-2:
	$(KC) apply -k k8s/overlays/incident-2

recover:
	$(KC) apply -k k8s/overlays/local
	$(KC) rollout status deployment/frontend -n $(NS) --timeout=300s
	$(KC) wait --for=condition=available deployment --all -n $(NS) --timeout=300s

# Riconfigurazione DICHIARATIVA: il banner arriva da un ConfigMap (overlay demo-reconfig); cambia il nome (hash) => rollout automatico
demo-reconfig:
	$(KC) apply -k k8s/overlays/demo-reconfig
	$(KC) rollout status deployment/frontend -n $(NS) --timeout=300s

# Riconfigurazione IMPERATIVA (per confronto): non e' tracciata in Git
demo-scale:
	$(KC) scale deployment frontend --replicas=2 -n $(NS)
	$(KC) get pods -l app=frontend -n $(NS)

demo-scale-undo:
	$(KC) scale deployment frontend --replicas=1 -n $(NS)
	$(KC) get pods -l app=frontend -n $(NS)
