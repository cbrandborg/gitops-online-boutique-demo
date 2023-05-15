PROJECT_ID=prj-dt-eu-gitops-compute
DOCKER_SERVICE_ACCOUNT=sa-frontend-CICD
LOCATION=europe-west1
PROJECT_ID_NUM=$(gcloud projects describe ${PROJECT_ID} --format "value(projectNumber)")
WORKLOAD_IDENTITY_POOL=wl-pool-frontend-boutique-gh
DVTM_GH_ORG=devoteamgcloud
GH_REPO=dgc-dk-gitops-frontend
WL_PROVIDER=dvtm-gitops-demo-github-provider
ARTIFACT_REGISTRY=dgc-dk-frontend-online-boutique


gcloud services enable artifactregistry.googleapis.com --project=${PROJECT_ID}

gcloud artifacts repositories create $ARTIFACT_REGISTRY \
    --repository-format=docker \
    --project=${PROJECT_ID} \
    --location=${LOCATION} \
    --description="Repository for managing front-end of online boutique demo"

gcloud iam workload-identity-pools create ${WORKLOAD_IDENTITY_POOL} \
    --project=${PROJECT_ID} \
    --location="global" \
    --display-name="Frontend Boutique Github Pool"

gcloud iam workload-identity-pools providers create-oidc ${WL_PROVIDER} \
    --project=${PROJECT_ID} \
    --location="global" \
    --workload-identity-pool=${WORKLOAD_IDENTITY_POOL} \
    --display-name="Github Provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.aud=assertion.aud,attribute.repository=assertion.repository" \
    --issuer-uri="https://token.actions.githubusercontent.com"


gcloud iam service-accounts create ${DOCKER_SERVICE_ACCOUNT} \
    --display-name="Frontend CICD Pipeline Service Account" \
    --project=${PROJECT_ID}

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --project=${PROJECT_ID} \
    --role="roles/artifactregistry.writer" \
    --member=serviceAccount:${DOCKER_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \

gcloud iam service-accounts add-iam-policy-binding ${DOCKER_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
    --project=${PROJECT_ID} \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_ID_NUM}/locations/global/workloadIdentityPools/${WORKLOAD_IDENTITY_POOL}/attribute.repository/${DVTM_GH_ORG}/${GH_REPO}"

