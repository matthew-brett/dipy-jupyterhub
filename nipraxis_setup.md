# Specific setup for Nipraxis

Log into NFS pod:

```
./show_pods.sh
```

Then:

```
./tools/kexec.sh nfs-server-<the-rest-of-the-pod-name> bash
```

```
# If necessary
yum install -y git
```

Now check what data version you need in the `nipraxis/registry.yaml` file.  Say it is "0.5".

```
cd exports/data
git clone https://github.com/nipraxis/nipraxis-data
ln -s nipraxis-data 0.5   # The data version you found you needed.
```
