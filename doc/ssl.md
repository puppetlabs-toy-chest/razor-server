# How to Use TLS/SSL in Razor

## Security Overview

Since Razor deals with installing machines from scratch (no existing knowledge
of what should be considered secure), the messages to the /svc namespace will
not be secured. /api calls, however, are allowed to change the state of the
Razor server and are eligible for some basic security measures.

The recommended configuration then is to leave /svc on port 8150 over HTTP and
do all /api calls on port 8151 over HTTPS with TLS/SSL. This guide will offer
a walk-through for how to do this.

## Configure razor-server

1. Disallow insecure access to /api. `secure_api` is a config property that
   determines whether calls to /api must be secure in order to be processed.
   This should be set to `true` in config.yaml.
2. Self-sign a certificate. There are several ways to do this; the most basic
   is to use the Java `keytool` command, filling in properties like so:

   ```
   keytool -genkey -keyalg RSA -alias selfsigned -keystore keystore.jks -storepass password -keypass password -validity 3600 -keysize 2048 -dname "CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, S=Unknown, C=Unknown"
   ```
   This will create a certificate file called `keystore.jks` in the current
   working directory. The default password in that command is simply
   `password`.
3. Configure Torquebox via `standalone.xml`. The exact location of this file
   may vary; the command `find / -name standalone.xml` should locate the file.
   In that file, two things need to change:
   * Add a web connector for HTTPS. Make these changes in the web connector:

     ```
       <connector name='http' protocol='HTTP/1.1' scheme='http' socket-binding='http'/>
       <connector name="https" protocol="HTTP/1.1" scheme="https" socket-binding="https" secure="true">
           <ssl name="https" key-alias="selfsigned" password="password" certificate-key-file="$PATH_TO_FILE" />
       </connector>
     ```
     The `$PATH_TO_FILE` should be modified to a permanent location for the
     keystore.jks file. `selfsigned` and `password` are both from the command
     above and may need to change.
   * Add a socket binding to the existing socket binding group. It should
     include these two lines:

     ```
        <socket-binding name='http' port='8150'/>
        <socket-binding name='https' port='8151'/>
     ```
4. Restart the razor-server service. This is `service razor-server restart` on
   most distributions.

The Razor server is now configured to accept HTTP communication on 8150 and
HTTPS communication on 8151.

## Connect razor-client with the new razor-server configuration

Now, the client needs to hook into this new configuration. This requires a
few changes:

1. Set the RAZOR_API parameter to reference port 8151 over HTTPS. This looks
   something like `export RAZOR_API="https://$server:8151/api"`, where $server
   is substituted for the Razor server address.
2. Choose a certificate verification preference.
   * Bypass certificate verification. The `razor` command can receive the `-k`
     argument to skip this checking procedure. This is less secure but still
     ensures the transmission of encrypted data over the network.
   * Use a CA file. The exact steps for this are outside the scope of this
     document. If you have a `.pem` file that includes the server certificate
     above, that file can be referenced via
     `export RAZOR_CA_FILE="$PATH/ca.pem"`.

After these changes, the `razor` command will communicate with the Razor server
over TLS/SSL.
