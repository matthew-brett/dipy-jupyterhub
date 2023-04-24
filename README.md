# Setup for Nipraxis JupyterHub

## Setting up the repository

There should be a pre-commit hook to prevent committing not-encrypted
files with `secret` in their path see [sops pre-commit
hook](https://github.com/yuvipanda/pre-commit-hook-ensure-sops).

```
pip install pre-commit
pre-commit install
```

## Setting up the JupyterHub

* Open [Google Cloud web console](https://console.cloud.google.com), and
  start the web shell, or install the [Google Cloud
  SDK](https://cloud.google.com/sdk) locally.
* If not done already: `git clone matthew-brett/dipy-jupyterhub`
* `cd dipy-jupyterhub`
* If setting up configuration from scratch see: "Scripts, starting from
  scratch" section in `./notes.md`.
* If running or reconfiguring a configured cluster, see: "Start and
  configure" section in `./notes.md`.

* If resuming: `source setup_helm.sh`
* To apply changes in `config.yaml` to running instance: `./rehelm.sh`.
* See other scripts in repo directory for setup / teardown utilities.

See `./notes.md` for description and other procedure.

In the future, consider [hubploy](https://github.com/yuvipanda/hubploy) for managing the cluster.
