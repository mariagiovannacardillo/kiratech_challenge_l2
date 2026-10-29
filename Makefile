.PHONY: doctor cluster-up cluster-down deploy wait-ready smoke-test verify trigger-incident-1 trigger-incident-2 recover demo-scale demo-scale-undo

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
	@echo "Tutti i prerequisiti (Docker, Kubectl, Kind) sono installati e funzionanti."

cluster-up:
	kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml
	
cluster-down:
	kind delete cluster --name $(CLUSTER_NAME)

deploy:
	$(KC) apply -k k8s/overlays/local

wait-ready:
	$(KC) wait --for=condition=available deployment --all -n $(NS) --timeout=300s

smoke-test:
	curl -fsS http://localhost:30000/ | grep -q "Hot Products" && echo "Smoke test superato" || { echo "Smoke test fallito"; exit 1; }

verify:
	$(KC) get pods -n $(NS)
	$(KC) get svc frontend-external -n $(NS)

trigger-incident-1:
	$(KC) apply -k k8s/overlays/incident-1

trigger-incident-2:
	$(KC) apply -k k8s/overlays/incident-2

recover:
	$(KC) apply -k k8s/overlays/local
	$(KC) wait --for=condition=available deployment --all -n $(NS) --timeout=300s

demo-scale:
	$(KC) scale deployment frontend --replicas=2 -n $(NS)
	$(KC) get pods -l app=frontend -n $(NS)

demo-scale-undo:
	$(KC) scale deployment frontend --replicas=1 -n $(NS)
	$(KC) get pods -l app=frontend -n $(NS)
