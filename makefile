cluster-name ?= "gitops-demo-cluster"
region ?= "europe-west9"
port ?= 8080
project ?= "prj-dt-eu-gitops-compute"

start:
	make cluster-exists && make context || make create-cluster
	make argo-setup
	make argo-bootstrap-apps

# Cluster Creation ------------------------------------

cluster-exists:
	@gcloud container clusters list --region $(region) --project $(project) | grep $(cluster-name) > /dev/null && echo cluster $(cluster-name) exists || (echo cluster $(cluster-name) does not exist && false)

delete-cluster:
	gcloud beta container clusters delete $(cluster-name) --region $(region) --project $(project)
	kubectl config delete-context $(cluster-name) || true

create-cluster:
	export USE_GKE_GCLOUD_AUTH_PLUGIN=True
	gcloud components update
	@gcloud container clusters create-auto $(cluster-name) \
		--project $(project) \
		--scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/ndev.clouddns.readwrite" \
		--region $(region)
	make context

context:
	kubectl config delete-context $(cluster-name) || true
	gcloud container clusters get-credentials $(cluster-name) --region $(region) --project $(project)
	kubectl config rename-context $$(kubectl config current-context) $(cluster-name)
	@echo

## Argo

argo-setup:
	make argo-check-if-credentials-exist
	make argo-install
	make argo-bootstrap-creds
	make argo-login
	make argo-ui-localhost-port-forward

argo-check-if-credentials-exist:
	@[ -f ./repo-creds.yml ] || (echo "repo-creds.yml does not exist. Create it from template: repo-creds-template.yml" && false)

argo-install:
	@echo "ArgoCD Install..."
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "Waiting for ArgoCD to get ready..."
	@while ! kubectl wait -A --for=condition=ready pod -l "app.kubernetes.io/name=argocd-server" --timeout=300s; do echo "Waiting for ArgoCD to get ready..." && sleep 10; done
	@sleep 2
	@echo

argo-login:
	@echo "ArgoCD Login..."
	echo "killing all port-forwarding" && pkill -f "port-forward" || true
	kubectl port-forward svc/argocd-server --pod-running-timeout=100m0s -n argocd $(port):443 &>/dev/null &
	@argocd login --port-forward --insecure --port-forward-namespace argocd --username=admin --password=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)
	@export ARGOCD_OPTS='--port-forward-namespace argocd' 
	@echo

argo-ui-localhost-port-forward: argo-login-credentials
	kubectl get nodes &>/dev/null
	@echo "killing all port-forwarding" && pkill -f "port-forward" || true
	kubectl port-forward svc/argocd-server --pod-running-timeout=60m0s -n argocd $(port):443 &>/dev/null &
	@open http://localhost:$(port)
	@echo

argo-login-credentials:
	@echo "username: admin, password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)"

argo-bootstrap-creds:
	@echo "Bootstrapping credentials..."
	@kubectl apply -f ./repo-creds.yml

argo-bootstrap-apps:
	@echo "Bootstrapping apps..."
	@kubectl apply -f ./argo/bootstrap/bootstrap.yml

## webpage

open-frontend:
	@open http://$$(kubectl get service frontend-svc-external | awk '{print $$4}' | grep -v EXTERNAL-IP)