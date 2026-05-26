# Spring Kubernetes ServiceAccount Flow

This guide explains how a Spring Boot app can call the Kubernetes API from inside the cluster by using a Kubernetes ServiceAccount.

## Big Picture

```text
Spring Pod
  uses serviceAccountName
    |
    v
Kubernetes mounts ServiceAccount token into the Pod
    |
    v
Fabric8 KubernetesClient reads the token automatically
    |
    v
Spring calls https://kubernetes.default.svc
    |
    v
Kubernetes checks RBAC permissions
    |
    v
Request succeeds or returns 403 Forbidden
```

## Important Concepts

```text
ServiceAccount = identity for a Pod
Role / ClusterRole = permissions
RoleBinding / ClusterRoleBinding = connects permissions to ServiceAccount
Pod serviceAccountName = tells the Pod which identity to use
```

A ServiceAccount does not run by itself. It becomes useful when a Pod uses it.

## 1. Create ServiceAccount And RBAC

Use this when your Spring backend needs to create database credential Secrets in many namespaces.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: backend
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spring-k8s-api
  namespace: backend
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: spring-db-secret-manager
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spring-db-secret-manager-binding
subjects:
- kind: ServiceAccount
  name: spring-k8s-api
  namespace: backend
roleRef:
  kind: ClusterRole
  name: spring-db-secret-manager
  apiGroup: rbac.authorization.k8s.io
```

Apply it:

```bash
kubectl apply -f spring-k8s-rbac.yaml
```

## 2. Use The ServiceAccount In Spring Deployment

Your Spring Deployment must include:

```yaml
spec:
  template:
    spec:
      serviceAccountName: spring-k8s-api
```

Full example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-backend
  namespace: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spring-backend
  template:
    metadata:
      labels:
        app: spring-backend
    spec:
      serviceAccountName: spring-k8s-api
      containers:
      - name: spring-backend
        image: your-spring-image:latest
        ports:
        - containerPort: 8080
```

## 3. Add Fabric8 Dependency

For Maven:

```xml
<dependency>
  <groupId>io.fabric8</groupId>
  <artifactId>kubernetes-client</artifactId>
  <version>6.13.4</version>
</dependency>
```

## 4. Create KubernetesClient Bean

```java
package com.example.demo.config;

import io.fabric8.kubernetes.client.KubernetesClient;
import io.fabric8.kubernetes.client.KubernetesClientBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class KubernetesConfig {

    @Bean
    public KubernetesClient kubernetesClient() {
        return new KubernetesClientBuilder().build();
    }
}
```

When the app runs inside Kubernetes, Fabric8 automatically reads:

```text
/var/run/secrets/kubernetes.io/serviceaccount/token
/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
/var/run/secrets/kubernetes.io/serviceaccount/namespace
```

So you do not need to manually pass a certificate or token.

## 5. Create PostgreSQL Credential Secrets From Spring

```java
package com.example.demo.kubernetes;

import io.fabric8.kubernetes.api.model.Namespace;
import io.fabric8.kubernetes.api.model.NamespaceBuilder;
import io.fabric8.kubernetes.api.model.Secret;
import io.fabric8.kubernetes.api.model.SecretBuilder;
import io.fabric8.kubernetes.client.KubernetesClient;
import org.springframework.stereotype.Service;

@Service
public class KubernetesSecretService {

    private final KubernetesClient kubernetesClient;

    public KubernetesSecretService(KubernetesClient kubernetesClient) {
        this.kubernetesClient = kubernetesClient;
    }

    public void createPostgresSecrets(
            String namespace,
            String releaseName,
            String appUsername,
            String appPassword,
            String superuserPassword
    ) {
        createNamespaceIfMissing(namespace);

        createOrUpdateBasicAuthSecret(
                namespace,
                releaseName + "-postgresql-app",
                appUsername,
                appPassword
        );

        createOrUpdateBasicAuthSecret(
                namespace,
                releaseName + "-postgresql-credentials",
                "postgres",
                superuserPassword
        );
    }

    private void createNamespaceIfMissing(String namespace) {
        Namespace existing = kubernetesClient.namespaces()
                .withName(namespace)
                .get();

        if (existing == null) {
            Namespace ns = new NamespaceBuilder()
                    .withNewMetadata()
                    .withName(namespace)
                    .endMetadata()
                    .build();

            kubernetesClient.namespaces()
                    .resource(ns)
                    .create();
        }
    }

    private void createOrUpdateBasicAuthSecret(
            String namespace,
            String secretName,
            String username,
            String password
    ) {
        Secret secret = new SecretBuilder()
                .withNewMetadata()
                .withName(secretName)
                .withNamespace(namespace)
                .endMetadata()
                .withType("kubernetes.io/basic-auth")
                .addToStringData("username", username)
                .addToStringData("password", password)
                .build();

        kubernetesClient.secrets()
                .inNamespace(namespace)
                .resource(secret)
                .serverSideApply();
    }
}
```

## 6. How This Fixes PostgreSQL External Secrets

If your Helm values contain:

```yaml
postgresql:
  externalSecretRef: seang-postgresql-app
  superuserExternalSecretRef: seang-postgresql-credentials
```

then Helm will not create those Secrets. It expects them to already exist.

Your Spring app can create them first:

```text
seang-postgresql-app
seang-postgresql-credentials
```

Then Argo CD / Helm can deploy the PostgreSQL cluster successfully.

## 7. Verify

Check the ServiceAccount:

```bash
kubectl get serviceaccount spring-k8s-api -n backend
```

Check RBAC:

```bash
kubectl auth can-i create secrets \
  --as=system:serviceaccount:backend:spring-k8s-api \
  -n ns-pengseangsim210-gmail-com-9d7d574c
```

Check the generated Secrets:

```bash
kubectl get secret seang-postgresql-app seang-postgresql-credentials \
  -n ns-pengseangsim210-gmail-com-9d7d574c
```

## Local Versus In-Cluster Behavior

When Spring runs inside Kubernetes:

```text
Fabric8 uses the Pod ServiceAccount token.
```

When Spring runs locally on your laptop:

```text
Fabric8 usually uses your local kubeconfig from ~/.kube/config.
```

That is why code can work locally but fail in production if the production ServiceAccount does not have RBAC permission.

