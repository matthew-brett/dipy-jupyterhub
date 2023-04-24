# Setting up the Nipraxis JupyterHub

## Introduction

These are somewhat finessed versions of the commands in:

<https://zero-to-jupyterhub.readthedocs.io/en/latest/>

In summary, the scripts here are slightly modified versions of the commands
there, wrapped into scripts, and configured by environment variables sourced
from a `vars.sh` file, and various sub-files.

As usual, the setup of the JupyterHub Helm chart is via a `config.yaml` file,
pointed to via the `vars.sh` environment variables.

In what follows, GCE stands for Google Compute Engine.

## Scripts, starting from scratch

If you've already done the configuration here, go to "Start and configure".

These are instructions on getting started, assuming you have read the rest of
this document, explaining how the scripts work.

* Create a new GCE *project* to house the cluster and other resources.  The
  default one I used here is the project `dipy-jupyterhub`.
* Use GCE to reserve an IP for your cluster to host at; see the "Static IP"
  section below.
* Configure your DNS to point some domain to the IP above, using an "A" record.

You will then want to
* Edit `vars.sh` to give hub name
* Edit `hubs/vars.sh.<hub-name>` to record IP, Google project name and other
  edits to taste.
* Edit `jh-secrets/config.yaml.<hub-name>` to record domain name etc.
* Run the "Start and configure" steps below.

My `config.yaml.cleaned` and `vars.sh` are for a fairly low-spec, but scalable
cluster.

## Start and configure

Consider setting your email, if you are a GCE administrator for the relevant project:

```
GCE_EMAIL=matthew.brett@gmail.com
```

```
# Initialize cluster
source init_gcloud.sh
```

```
# Initialize Helm
source setup_helm.sh
```

```
# Initialize NFS
source init_nfs.sh
```

```
# (Re-) Configure cluster by applying Helm chart
source configure_jhub.sh
```

Test https.   You might need to:

```
# Check the HTTPS logs
./log_autohttps.sh
```

Then you might want to:

```
# Reset https on cluster
source reset_autohttps.sh
```

See the message from `reset_autohttps.sh` for suggestions, if HTTPS isn't
working.

To apply a configuration change in the relevant `config.yaml.*` file on a running cluster:

```
# (Re-) Configure cluster by applying Helm chart
source configure_jhub.sh
```

See the `teardown_everything.sh` script for tearing stuff down.

## Testing the cluster

To test the cluster, try a big scale-up.  See the next section "Before a live
session in a course".  Try scaling up to a large number.  Review any scaling
messages in the Google Cloud Console.  In particular, you will likely want to
ask for increases in some quotas.

## Before a live session in a course

Once your cluster is running, you might consider a preventive scale-up, maybe something like this:

```bash
# Anticipating 25 students or so.
# Add an extra 10 placeholders on top to make lots of scaling happen.
./tools/scale_placeholder.sh 10
```

Don't forget to scale down again after the end of the course, e.g.:

```bash
./tools/scale_placeholder.sh 0
```

## In more detail

### First - GCE setup

Here are the instructions for Google Cloud Engine, starting with the [basic GCE
/ Kubernetes
setup](https://zero-to-jupyterhub.readthedocs.io/en/latest/google/step-zero-gcp.html).

I believe I cannot create a housing organization, because I am not a G-Suite or
Cloud Identity customer - see [this
page](https://cloud.google.com/resource-manager/docs/creating-managing-organization).

I created a project `dipy-jupyterhub`.

I enabled the Kubernetes API via
<https://console.cloud.google.com/apis/library/container.googleapis.com>.

I initially used the web shell via the [web
console](https://console.cloud.google.com).  The web shell wouldn't start on
Firefox, so I went to Chrome.  Later I installed the [Google Cloud
SDK](https://cloud.google.com/sdk) locally, as I got bored of being automatically disconnected from the web shell.

`europe-west2` appears to be the right *region* for the UK.  `us-west1` is OK for the US.  See [GCE regions](https://cloud.google.com/compute/docs/regions-zones/#available).

Regions contain *zones*.  See the
[docs](https://cloud.google.com/sdk/gcloud/reference/container/clusters/create)
I've specified zone `b` --- see the `vars.sh` file.

### Set default region and zone

```
REGION=us-west1
ZONE=us-west1-b
gcloud compute project-info add-metadata \
    --metadata google-compute-default-region=$REGION,google-compute-default-zone=$ZONE
gcloud init
```

### Authenticate

Otherwise you'll get `The connection to the server localhost:8080 was refused`
for various commands.

```
gcloud auth login
```

maybe followed by:

```
. vars.sh
gcloud config set project $PROJECT_ID  # or whatever
CLUSTER=${JHUB_CLUSTER}  # or whatever
gcloud container clusters get-credentials $CLUSTER --zone $ZONE
```

<https://stackoverflow.com/a/57592322/1939576>

### Documentation links

* <https://kubernetes.io/docs/reference/kubectl/cheatsheet>

### Static IP addresses

I believe the standard JupyterHub / Kubernetes setup uses a Service to route
requests from the proxy.  I made a static IP address, following [this
tutorial](https://cloud.google.com/kubernetes-engine/docs/tutorials/configuring-domain-name-static-ip):

```
IP_NAME=my-hub-ip  # Label for reserved ip
gcloud compute addresses create $IP_NAME --region $REGION
gcloud compute addresses describe $IP_NAME --region $REGION
```

Note the IP address from above in the `vars.sh` file and the `loadBalancerIP`
field of your `config.yaml` file - which might be `jh-secrets/config.yaml.<hub-name>`.

Set up DNS to point to this IP.  Wait for it to propagate, at least to the
console you are using, e.g.

```
nslookup dipy.nipraxis.org
```

Set the host name in your `config.yaml`.

### Billing data

You'll need this!  Honestly.  The money runs out quickly if you're not keeping
track of where it's going.

I set up a billing table to export to, via the Google Billing Export panel,
called `uob_jupyterhub_billing`.

### Scaling

Be careful when scaling.  I had a demo crash catastrophically when more than
32 or so people tried to log in - see [this discourse thread for some
excellent help and
discussion](https://discourse.jupyter.org/t/scheduler-insufficient-memory-waiting-errors-any-suggestions/5314).
If you want to scale to more than a few users, you will need to:

* Make sure you have enough nodes in the user pool - see section: "Upgrade
  / downgrade number of nodes"
* Specify minimum memory and CPU requirements carefully.  See [this section of
  the
  docs](https://zero-to-jupyterhub.readthedocs.io/en/latest/customizing/user-resources.html#set-user-memory-and-cpu-guarantees-limits).
  As those docs point out, by default each user is guaranteed 1G of RAM, so
  each new user will add 1G of required RAM.  This in turn means that fewer
  users will fit onto one node (VM), and you'll need more VMs, and therefore
  more money, and more implied CPUs (see below).
* You may very well need to increase your CPU and in-use IP address quotas on
  Google Cloud to allow many users.  Exactly what quotas you need will depend
  on the number and type of user nodes you use - see
  <https://console.cloud.google.com/iam-admin/quotas>; use links there to ask
  for changes to your quotas; check this link when your cluster is scaling to see if you are hitting GKE limits.

### Scaling and regional clusters

I hit repeated problems on scaling when using the [free Zonal cluster
option](https://cloud.google.com/kubernetes-engine/pricing).  Specifically, my
[cluster became unresponsive while
scaling](https://discourse.jupyter.org/t/gke-autoscale-test-failure-cluster-reconciling)
with messages: `The connection to the server <an-ip-address> was refused`.
Switching to the \$0.10 per hour regional cluster option helped, presumably
because regional clusters replicate the [Kubernetes control
plane](https://kubernetes.io/docs/concepts/overview/components) across zones
within the region.  The control plane provides the Kubernetes API server,
meaning that you have some redundancy for the API server, and therefore,
greater availability.

Note that you can (should) specify that the *nodes* be restricted to one *zone*
in the region, to reduce cost, and to make it easier to configure storage, but
the control plane does not live on the nodes.  Restrict node zone locations
with the `--node-locations` option to the cluster creation command.

See the [Berkeley GKE
summary](https://docs.datahub.berkeley.edu/en/latest/admins/cluster-config.html)
for a little more detail.

### Storage

Follow steps in `./storage.md` to create home directories / data
disk, served by NFS.

## Local Helm

Install Helm in `$HOME/usr/local/bin` filesystem:

```
. install_helm.sh
source ~/.bashrc
```

### Examples

There are various examples of configuration in
<https://github.com/berkeley-dsep-infra/datahub/tree/staging/deployments>,
with some overview in the [datahub
docs](https://docs.datahub.berkeley.edu/en/latest/users/hubs.html).

### Keeping secrets

See
<https://discourse.jupyter.org/t/best-practices-for-secrets-in-z2jh-deployments/1292>
and <https://github.com/berkeley-dsep-infra/datahub/issues/596>.

## Securing

<https://zero-to-jupyterhub.readthedocs.io/en/latest/administrator/security.html>

> ... mitigate [root access to pods] by limiting public access to the Tiller API.

This is covered by the command below - already in the recipe above:

```
kubectl --namespace=kube-system patch deployment tiller-deploy --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'
```

The Dashboard can show information about the cluster that should not be public.  Delete the dashboard with:

```
kubectl --namespace=kube-system delete deployment kubernetes-dashboard
```

On my system, this gave a "NotFound" error, and the [following
command](https://stackoverflow.com/a/49427146) gave no output.

```
kubectl get secret,sa,role,rolebinding,services,deployments,pods --all-namespaces | grep dashboard
```

See also [JupyterHub
security](https://jupyterhub.readthedocs.io/en/stable/reference/websecurity.html).

## Security review

Following the headings in the link above:

* HTTPS: enabled via LetsEncrypt
* Secure access to Helm : using Helm 3, patch no longer relevant.
* Audit Cloud Metadata server access: access blocked by default (and not
enabled by me).
* Delete the Kubernetes Dashboard: checked - dashboard not running
* Use Role Based Access Control (RBAC): Google uses RBAC, thus enabled by default.
* Kubernetes API Access: disabled by default (and not enabled by me).
* Kubernetes Network Policies: disabled by default (and not enabled by me).

The Helm charts hosted via <https://jupyterhub.github.io/helm-chart>.  At time
of writing (2020-09-12), I'm using the latest devel version,
`0.9.0-n233.hcd1eff7a` - see `./vars.sh`.

## Tear it all down

```
. vars.sh
helm delete $RELEASE --purge
kubectl delete namespace $NAMESPACE
```

## Dockerfiles

See <https://github.com/jupyter/docker-stacks>

In `config.yaml`, something like:

```
singleuser:
  image:
    # Get the latest image tag at:
    # https://hub.docker.com/r/jupyter/datascience-notebook/tags/
    # Inspect the Dockerfile at:
    # https://github.com/jupyter/docker-stacks/tree/master/datascience-notebook/Dockerfile
    name: jupyter/datascience-notebook
    tag: 54462805efcb
```

Don't forget the tag!

**Make sure that the JupyterHub version installed on the Docker image is the
same as the JupyterHub version in the current Helm chart**.  Otherwise stuff
will go wrong.

## Logging, login

Finding the `autohttps` pod, getting logs:

```
kubectl logs pod/$(kubectl get pods -o custom-columns=POD:metadata.name | grep autohttps-) traefik -f
```

```
kubectl exec --stdin --tty autohttps-77dfc9d56c-8qdtt -- /bin/sh
```

## RStudio

Hmmm.

## Authentication

See
<https://zero-to-jupyterhub.readthedocs.io/en/latest/administrator/authentication.html#authenticating-with-oauth2>.

### For testing

See e.g. <https://zero-to-jupyterhub.readthedocs.io/en/latest/administrator/authentication.html#adding-a-whitelist>

```
# Anyone can log in with any username and any password.
auth:
  type: dummy
```

or, for a little extra security:

```
# Anyone can log in with any username, but they must use this password.
auth:
  type: dummy
  dummy:
    password: 'mypassword'
```


### CILogon authentication

See [Z2JH
section](https://zero-to-jupyterhub.readthedocs.io/en/latest/administrator/authentication.html#cilogon)
and [the CILogon docs](https://www.cilogon.org/oidc#h.p_PEQXL8QUjsQm).

Go to <https://cilogon.org/oauth2/register> and ask for your JupyterHub client to be registered.  As noted in the CILogon docs above, you should ask for these three scopes: *openid*, *email*, and *org.cilogon.userinfo*.  I found their support to be very quick and helpful.

You might want to restrict authentication providers by specifying one from the
list at <https://cilogon.org/include/idplist.xml> (see
`c.CILogonOAuthenticator.idp` below).

Here's a fake version of my eventual config:

```
auth:
  type: cilogon
  cilogon:
    # See: https://www.cilogon.org/oidc#h.p_PEQXL8QUjsQm
    clientId: cilogon:/client_id/a0b1c2d3e4f56789a0b1c2d3e4f56789
    clientSecret: a0b1c2d3e4f56789a0b1c2d3e4f-a0b1c2d3e4f56789a0b1c2d3e4f56789a0b1c2d3e4f56789a0b1c2d3e4
    callbackUrl: https://uobhub.org/hub/oauth_callback

hub:
  extraConfig:
    myAuthConfig: |
      # Default ePPN username claim works for UoB; no need to force "email",
      # but do this anyway for consistency.
      c.CILogonOAuthenticator.username_claim = 'email'
      c.CILogonOAuthenticator.idp = 'https://idp.bham.ac.uk/shibboleth'
      # Stripping only works for a single entry in whitelist below.
      c.CILogonOAuthenticator.strip_idp_domain = True
      # Will soon be "allowed_idps" (from v0.12 of oauthenticator)
      c.CILogonOAuthenticator.idp_whitelist = ['bham.ac.uk',
                                               'student.bham.ac.uk']

```

### Globus authentication

* [JH, Kubernetes auth for Globus](https://zero-to-jupyterhub.readthedocs.io/en/latest/administrator/authentication.html#globus)
* [OAthenticator](https://github.com/jupyterhub/oauthenticator)
* [Globus procedure](https://oauthenticator.readthedocs.io/en/latest/getting-started.html#globus-setup)

Make an app at <https://developers.globus.org>, and follow instructions at [OAuthenticator Globus setup](https://oauthenticator.readthedocs.io/en/latest/getting-started.html#globus-setup).

As instructed, I enabled the scropes "openid profile
urn:globus:auth:scope:transfer.api.globus.org:all".  I set the callback URL as
below, and checked "Require that the user has linked an identity ...", and
"Pre-select a specific identity", both set to my university. I then copied the client id given (see below), and made a new client secret (see below).

Example adapted from [JH, Kubernetes auth for Globus](https://zero-to-jupyterhub.readthedocs.io/en/latest/administrator/authentication.html#globus):

```
auth:
  type: globus
  globus:
    clientId: a0b1c2d3-a0b1-a0b1-a0b1-a0b1c2d3e4f5
    clientSecret: a0b1c2d3e4f56789a0b1c2d3e4f56789a0b1c2d3e4f5
    callbackUrl: https://uobhub.org/hub/oauth_callback
    identityProvider: bham.ac.uk
```

I ran into problems with this auth, for our students, for some reason, so switched to CILogon above.

## Nbgitpuller

Needs to be installed in the Docker container.

There is a [link builder](https://jupyterhub.github.io/nbgitpuller/link.html)
but it didn't refresh the link correctly for me.  I ended up crafting the links by hand, from [the url options](https://jupyterhub.github.io/nbgitpuller/topic/url-options.html).

* A Jupyter notebook link:
  <http://uobhub.org/user/matthew-brett/git-pull?repo=https%3A%2F%2Fgithub.com%2Fmatthew-brett%2Fdatasets&urlpath=mosquito_beer/process_mosquito_beer.ipynb>
* A link opening RStudio:
  <http://uobhub.org/user/matthew-brett/git-pull?repo=https%3A%2F%2Fgithub.com%2Fmatthew-brett%2Ftitanic-r&urlpath=/rstudio>.
  This fetches the [Titanic R exercise from
  Github](https://github.com/matthew-brett/titanic-r/blob/master/titanic.Rmd)
  and opens RStudio. In RStudio, use File - Open to open the
  `titanic-r/titanic.Rmd` notebook.

See the URL options link above; it's not possible, at the moment, to get a
link that opens a particular R notebook directly in RStudio.

## Helm charts

[JupyterHub Helm chart listing](https://jupyterhub.github.io/helm-chart/#development-releases-jupyterhub).

## Upgrade / downgrade number of nodes

Change max number of nodes with the [node-pools update
command](https://cloud.google.com/sdk/gcloud/reference/container/clusters/update):

```
. vars.sh
gcloud container node-pools update user-pool \
   --zone=$ZONE \
   --cluster=${JHUB_CLUSTER}\
   --max-nodes=50
```

Show the change:

```
gcloud container node-pools describe user-pool \
    --zone=$ZONE \
    --cluster=${JHUB_CLUSTER}
```

## Contexts

If futzing around between a couple of clusters, you may have to change
"contexts" - see [this gh
issue](https://github.com/kubernetes/kubernetes/issues/56747).

```
$ kubectl config current-context
error: current-context is not set
$  kubectl config get-contexts
CURRENT   NAME                                           CLUSTER                                        AUTHINFO                                       NAMESPACE
          gke_uob-jupyterhub_europe-west2_jhub-cluster   gke_uob-jupyterhub_europe-west2_jhub-cluster   gke_uob-jupyterhub_europe-west2_jhub-cluster   jhub
$ kubectl config use-context gke_uob-jupyterhub_europe-west2_jhub-cluster
```

## Tuning performance, scaling, cost

Be careful when scaling.  I had a demo crash catastrophically when more than
32 or so people tried to log in - see [this discourse thread for some
excellent help and
discussion](https://discourse.jupyter.org/t/scheduler-insufficient-memory-waiting-errors-any-suggestions/5314).

See also:

* [Discussion of factors increasing
resilience](https://discourse.jupyter.org/t/core-component-resilience-reliability/5433).
* <https://discourse.jupyter.org/t/background-for-jupyterhub-kubernetes-cost-calculations/5289/5>

You can do a preliminary test of scaling by asking for a large number of *user placeholder* pods.  This does some simulation of starting multiple pods at the same time.

For example:

```
scheduling:
  userScheduler:
    enabled: true
  podPriority:
    enabled: true
  userPlaceholder:
    # Specify number of dummy user pods to be used as placeholders
    enabled: true
    replicas: 250
  userPods:
    nodeAffinity:
      # matchNodePurpose valid options:
      # - ignore
      # - prefer (the default)
      # - require
      matchNodePurpose: require

jupyterhub:
  hub:
    # See this link for discussion of these options.
    # https://discourse.jupyter.org/t/core-component-resilience-reliability/5433/4
    activity_resolution: 120  # Default 30
    hub_activity_interval: 600  # Default 300
    last_activity_interval: 300  # Default 300
    init_spawners_timeout: 1  # Default 10
```

The script `./tools/scale_placeholder.sh` will add placeholders without you
having to modify the config file.  Run as:

```bash
./tools/scale_placeholder.sh 50
```

to add 50 placeholders.   This is a useful way to check how scaling is going to work.  Check quotas and other errors after scaling.  Then drop back to fewer placeholders with e.g.

```bash
./tools/scale_placeholder.sh 0
```

At time of writing, I also used a devel release of the JupyterHub Helm chart,
`0.9.0-n233.hcd1eff7a` in order to get an [August 2020 performance fix in the
KubeSpawner library](https://github.com/jupyterhub/kubespawner/issues/423);
see [this
thread](https://discourse.jupyter.org/t/core-component-resilience-reliability/5433/4).

Very good scaling may need a Postgres server rather than the default SQLite; I
haven't tried that.

Other aspects:

* Make sure you have enough nodes in the user pool - see section: "Upgrade /
  downgrade number of nodes"
* Specify minimum memory and CPU requirements carefully.  See [this section of
  the
  docs](https://zero-to-jupyterhub.readthedocs.io/en/latest/customizing/user-resources.html#set-user-memory-and-cpu-guarantees-limits).
  As those docs point out, by default each user is guaranteed 1G of RAM, so
  each new user will add 1G of required RAM.  This in turn means that fewer
  users will fit onto one node (VM), and you'll need more VMs, and therefore
  more money, and more implied CPUs (see below).

Be careful of quotas on your cloud system; see next section.

### Google cloud specifics

Thanks to Min R-K for pointing me to these fixes / links.

* If scaling fails check your [Google quotas
  page](https://console.cloud.google.com/iam-admin/quotas) to see if you've exhausted some quota, such as CPU, or internal IP addresses.
* It may be worth checking
  [GC monitoring](https://console.cloud.google.com/monitoring).
* You may well need to increase your CPU quotas on Google Cloud to allow
  enough nodes.  The number of nodes you need will depend on how many user
  pods can pack into one node.  You can ask to increase your CPU quota via the
  quotas page above.
* You may well need to increase your quota of internal network IP addresses,
  if you have many pods.  Check the quotas page above.
* You might try downgrading the machine types on which the cluster runs, from
  the suggested default of `n1-standard-2`, to save money, but be look out for
  out-of-memory errors stalling the cluster, in the logs and output of
  `kubetcl get pod`.  I managed to get down to `n1-custom-1-6656` (1 CPU,
  6.5GB of RAM), while still scaling to 250 pods, but I couldn't go lower
  without the cluster stalling.  See `DEFAULT_MACHINE` in `./vars.sh`.

The [Kubernetes workload
page](https://console.cloud.google.com/kubernetes/workload) can be useful to
review what the cluster etc is doing.

## Storage volumes

I'm using NFS, with a directory for storing home directories, and another for
storing read-only data.  See `./storage.md` and `./init_nfs.sh`.

See
<https://github.com/berkeley-dsep-infra/datahub/blob/de634c5/docs/admins/storage.rst>
for discussion of NFS.  See also the files there for matching Datahub / Data8x
setup.

See also discussion at <https://discourse.jupyter.org/t/additional-storage-volumes/5012/7>

