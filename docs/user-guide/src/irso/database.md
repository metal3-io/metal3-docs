# External database for Ironic

By default, Ironic uses a local [SQLite](https://sqlite.org/) database, which
is not persisted anywhere. In this mode of operation, all data is lost on a pod
restart. If you want the Ironic database to be persisted, you need to configure
an external [MariaDB](https://mariadb.org/) database.

## Linking to an external database

You can request persistence by providing a link to an external database in the
`database` field:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  database:
    credentialsName: secret-with-user-password
    host: mariadb.hostname.example.com
    name: database-name
  version: "32.0"
```

If your database uses TLS, provide the name of the secret with the CA
certificate in the `tlsCertificateName` field.

## Using mariadb-operator

One of the supported ways to install MariaDB for Ironic is
[mariadb-operator](https://github.com/mariadb-operator/mariadb-operator).
Please refer to [its
examples](https://github.com/mariadb-operator/mariadb-operator/tree/main/examples/manifests)
for information on how to use it in your case. Generally, the process is as
follows:

1. Create a database server (if not already):

   ```yaml
   ---
   apiVersion: v1
   kind: Namespace
   metadata:
     name: mariadb
   ---
   apiVersion: v1
   kind: Secret
   metadata:
     name: root-credentials
     namespace: mariadb
   type: Opaque
   data:
     username: aXJvbmlj
     password: # your password here
   ---
   apiVersion: k8s.mariadb.com/v1alpha1
   kind: MariaDB
   metadata:
     name: database-server
     namespace: mariadb
   spec:
     rootPasswordSecretKeyRef:
       name: root-credentials
       key: password
     storage:
       # configure database storage here
   ```

   **Note:** a lot of parameters can be tuned here - see official examples.

1. Create the database for Ironic:

   ```yaml
   apiVersion: k8s.mariadb.com/v1alpha1
   kind: Database
   metadata:
     name: ironic-database
     namespace: test-ironic
   spec:
     mariaDbRef:
       name: database-server  # matches the server created above
       namespace: mariadb     # matches the namespace of the server (not Ironic)
       waitForIt: true
     characterSet: utf8
     cleanupPolicy: Delete
     collate: utf8_general_ci
   ```

1. Create a user and grant it all privileges to the new database:

   ```yaml
   ---
   apiVersion: v1
   kind: Secret
   metadata:
     name: ironic-user
     namespace: test-ironic
   type: Opaque
   data:
     username: aXJvbmljLXVzZXI=  # this MUST match the name of the User
     password: # your password here
   ---
   apiVersion: k8s.mariadb.com/v1alpha1
   kind: User
   metadata:
     name: ironic-user  # this MUST match the username field in the secret
     namespace: test-ironic
   spec:
     mariaDbRef:
       name: database-server  # matches the server created above
       namespace: mariadb     # matches the namespace of the server (not Ironic)
       waitForIt: true
     cleanupPolicy: Delete
     host: '%'
     maxUserConnections: 100
     passwordSecretKeyRef:
       key: password
       name: ironic-user
   ---
   apiVersion: k8s.mariadb.com/v1alpha1
   kind: Grant
   metadata:
     name: ironic-user-grant
     namespace: test-ironic
   spec:
     mariaDbRef:
       name: database-server  # matches the server created above
       namespace: mariadb     # matches the namespace of the server (not Ironic)
       waitForIt: true
     cleanupPolicy: Delete
     database: ironic-database  # matches the name of the Database object
     host: '%'
     privileges:
     - ALL PRIVILEGES
     table: '*'
     username: ironic-user  # matches the name of the User object
   ```

   **Warning:** mariadb-operator gets the user name from the name of the User
   object, while Ironic uses the `username` field of the secret. If these do
   not match, authentication will fail.

   **Note:** the default `maxUserConnections` of 10 is not enough for a normal
   operation of Ironic. The exact value depends on your environment, 100 is the
   value used in the CI.

1. After making sure that all objects are created and in `Ready` state, you can
   link to the database via its service endpoint:

   ```yaml
   apiVersion: ironic.metal3.io/v1alpha1
   kind: Ironic
   metadata:
     name: ironic
     namespace: test-ironic
   spec:
     database:
       credentialsName: ironic-user
       host: database-server.mariadb.svc
       name: ironic-database
     version: "32.0"
   ```
