kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ibm-bai-pv
  annotations:
    volume.beta.kubernetes.io/storage-class: "{{ STORAGE_CLASS }}"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ibm-bai-ek-pv-1e
  annotations:
    volume.beta.kubernetes.io/storage-class: "{{ STORAGE_CLASS }}"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
