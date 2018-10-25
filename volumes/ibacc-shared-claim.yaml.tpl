kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ibacc-cfg-pvc
  annotations:
    volume.beta.kubernetes.io/storage-class: "{{ STORAGE_CLASS }}"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
