# How to setup Jenkins Kubernetes Authentication and Authorization
## Jenkins running outside kubernetes
1. Authentication: create a service acccount on Kubernetes for Jenkins 
```
kubectl create serviceaccount jenkins -n CI-ns
```
2. Get the service account token and API server CA certificate
```
kubectl get secret $(kubectl get sa jenkins -n CI-ns -o jsonpath={.secrets[0].name}) -n CI-ns -o jsonpath={.data.token} | base64 --decode
kubectl get secret $(kubectl get sa jenkins -n CI-ns -o jsonpath={.secrets[0].name}) -n CI-ns -o jsonpath={.data.'ca\.crt'} | base64 --decode
```
3. Authorization: Create RBAC role with the required permissions for Jenkins kubernetes plugin 
```
cat > jenkins-role.yaml << EOF
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: jenkins
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create","delete","get","list","patch","update","watch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create","delete","get","list","patch","update","watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get","list","watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
EOF

kubectl apply -f jenkins-role.yaml -n CI-ns
```
4. Create Role Binding
```
cat > jenkins-rolebinding.yaml << EOF
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: jenkins
  namespace: CI-ns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: jenkins
subjects:
- kind: ServiceAccount
  name: jenkins
EOF
kubectl apply -f jenkins-rolebinding.yaml -n CI-ns
```   

5. Install kubernetes plugin in Jenkins
"Manage Jenkins" -> "Configure Cloud"->Add a new cloud selects kubernetes, specify kubernetes details
   -  Kubernete URL: get it by kubectl config view --minify | grep server
   -  Kubernete certificate key: the API server CA retrieved by above command
   -  Namespace: CI-ns where the service account and RBAC config was created
   -  Credentials: the secret credential created above

## Launch Jenkins master pod with the servcie account
```
      serviceAccountName: jenkins
      containers:
        - name: jenkins
          image: jenkins/jenkins
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
            - containerPort: 50000
          resources:
            limits:
              cpu: 1
              memory: 1Gi
            requests:
              cpu: 0.5
              memory: 500Mi
          env:
            - name: LIMITS_MEMORY
              valueFrom:
                resourceFieldRef:
                  resource: limits.memory
                  divisor: 1Mi
          volumeMounts:
            - name: jenkins-home
              mountPath: /var/jenkins
          livenessProbe:
            httpGet:
              path: /login
              port: 8080
            initialDelaySeconds: 60
            timeoutSeconds: 5
          readinessProbe:
            httpGet:
              path: /login
              port: 8080
            initialDelaySeconds: 60
            timeoutSeconds: 5
      securityContext:
        fsGroup: 1000
  volumeClaimTemplates:
  - metadata:
      name: jenkins-data
      # annotations:
      #   volume.beta.kubernetes.io/storage-class: anything
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```