.PHONY: doctor cluster-up cluster-down deploy wait-ready smoke-test verify trigger-incident-1 trigger-incident-2 recover demo-scale

# Variabile per proteggere il contesto ed evitare di rompere altri cluster
KC := kubectl --context kind-l2-challenge

doctor:
	@echo "=== Controllo prerequisiti di sistema ==="
	@command -v docker >/dev/null 2>&1 || { echo >&2 "Docker non trovato."; exit 1; }
	@docker info >/dev/null 2>&1 || { echo >&2 "Demone Docker non attivo."; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo >&2 "Kubectl non trovato."; exit 1; }
	@command -v kind >/dev/null 2>&1 || { echo >&2 "Kind non trovato."; exit 1; }
	@echo "Tutti i prerequisiti (Docker, Kubectl, Kind) sono installati e funzionanti."

cluster-up:
	kind create cluster --name l2-challenge --config kind-config.yaml
	
cluster-down:
	kind delete cluster --name l2-challenge

deploy:
	$(KC) apply -k k8s/overlays/local

wait-ready:
	$(KC) wait --for=condition=available deployment --all -n challenge-l2 --timeout=300s

smoke-test:
	curl -fsS http://localhost:30000/ | grep -q "Hot Products" && echo "Smoke test superato" || { echo "Smoke test fallito"; exit 1; }

verify:
	$(KC) get pods -n challenge-l2
	$(KC) get svc frontend-external -n challenge-l2

trigger-incident-1:
	$(KC) apply -k k8s/overlays/incident-1

trigger-incident-2:
	$(KC) apply -k k8s/overlays/incident-2

recover:
	$(KC) apply -k k8s/overlays/local
	$(KC) wait --for=condition=available deployment --all -n challenge-l2 --timeout=300s

demo-scale:
	$(KC) scale deployment frontend --replicas=2 -n challenge-l2
	$(KC) get pods -l app=frontend -n challenge-l2

demo-scale-undo:
	$(KC) scale deployment frontend --replicas=1 -n challenge-l2
	$(KC) get pods -l app=frontend -n challenge-l2
