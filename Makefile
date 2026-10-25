.PHONY: doctor cluster-up cluster-down deploy wait-ready verify trigger-incident-1 trigger-incident-2 recover

doctor:
	@echo "=== Controllo prerequisiti di sistema ==="
	@command -v docker >/dev/null 2>&1 || { echo >&2 "Docker non trovato."; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo >&2 "Kubectl non trovato."; exit 1; }
	@command -v kind >/dev/null 2>&1 || { echo >&2 "Kind non trovato."; exit 1; }
	@echo "Tutti i prerequisiti (Docker, Kubectl, Kind) sono installati e funzionanti."

cluster-up:
	kind create cluster --name l2-challenge --config kind-config.yaml
	kubectl create namespace challenge-l2 --dry-run=client -o yaml | kubectl apply -f -

cluster-down:
	kind delete cluster --name l2-challenge

deploy:
	kubectl apply -k k8s/overlays/local

wait-ready:
	kubectl wait --for=condition=ready pod -l app=frontend -n challenge-l2 --timeout=120s

verify:
	kubectl get pods -n challenge-l2
	kubectl get svc frontend-external -n challenge-l2

trigger-incident-1:
	kubectl apply -k k8s/overlays/incident-1

trigger-incident-2:
	kubectl apply -k k8s/overlays/incident-2

recover:
	kubectl apply -k k8s/overlays/local
	kubectl rollout restart deployment/frontend -n challenge-l2
	kubectl wait --for=condition=ready pod -l app=frontend -n challenge-l2 --timeout=120s