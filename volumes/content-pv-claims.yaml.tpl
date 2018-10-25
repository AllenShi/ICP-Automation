kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: cpe-icp-cfgstore
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
  name: cpe-icp-logstore
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
  name: cpe-icp-filestore
  annotations:
    volume.beta.kubernetes.io/storage-class: "{{ STORAGE_CLASS }}"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: cpe-icp-icmrulesstore 
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
  name: cpe-icp-textextstore
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
  name: cpe-icp-bootstrapstore
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
  name: cpe-icp-fnlogstore
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
  name: icn-icp-cfgstore
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
  name: icn-icp-logstore
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
  name: icn-icp-pluginstore
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
  name: icn-icp-vw-cachestore
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
  name: icn-icp-vw-logstore
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
  name: css-icp-cfgstore
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
  name: css-icp-logstore
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
  name: css-icp-tempstore
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
  name: css-icp-indexstore
  annotations:
    volume.beta.kubernetes.io/storage-class: "{{ STORAGE_CLASS }}"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: cmis-icp-cfgstore
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
  name: cmis-icp-logstore
  annotations:
    volume.beta.kubernetes.io/storage-class: "{{ STORAGE_CLASS }}"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
