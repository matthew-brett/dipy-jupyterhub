# Source this file
# Source vars
. vars.sh
# Set project ID, region, zone (just in case)
gcloud config set project $PROJECT_ID
gcloud compute project-info add-metadata \
    --metadata google-compute-default-region=$REGION,google-compute-default-zone=$ZONE
# Chceck for helm v2
HELM_VER=$(helm version --client --template '{{ .Client.SemVer }}')
if [ "${HELM_VER:0:3}" != "v2." ]; then
    echo run install_helm.sh for helm 2
    return 1
fi
# Reinit helm
helm init --service-account tiller --history-max 100 --wait
# Reinit jupyterhub helm chart repo
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
# optional autocompletion
kubectl config set-context $(kubectl config current-context) --namespace ${NAMESPACE:-jhub}
# Reinit command
alias rehelm='helm upgrade $RELEASE jupyterhub/jupyterhub  --version=$JHUB_VERSION --values config.yaml'
# Show what's running
kubectl get pod --namespace $NAMESPACE
