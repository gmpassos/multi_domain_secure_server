## Using the `shelf` Package with `MultiDomainSecureServer`

This example demonstrates how to use `MultiDomainSecureServer.bind` along with `HttpServer.listenOn`.

### Using Your SSL/TLS Certificates

To run this example, you need to modify it and specify the paths to your domain certificates in the
`hostnamesSecurityContexts` map.

### Running the Example

To start the server, run the following command:

```bash
dart run shelf_example.dart
```

This will start an HTTP server on port `8443`.

### Testing the Server

You can test the server by using the following `curl` command:

```bash
curl -v -k --resolve your-domain.com:8443:127.0.0.1 https://your-domain.com:8443/foo
```

This command sends a request to `your-domain.com` on port `8443` and resolves it to `127.0.0.1` (localhost).

You should receive the following response:

```text
Hello, Secure World!
```
