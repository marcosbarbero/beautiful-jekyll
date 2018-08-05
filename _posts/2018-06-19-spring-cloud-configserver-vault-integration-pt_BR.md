---
layout: post
title: Integrating Vault with Spring Cloud Config Server
bigimg: /img/chain-key-lock.jpg
share-img: /img/chain-key-lock.jpg
gh-repo: weekly-drafts/spring-cloud-configserver-vault
gh-badge: [star, fork, follow]
tags: [spring-framework, security, spring-cloud, vault, java, tutorial]
permalink: /integrating-vault-spring-cloud-config/
lang: pt_BR
---

This guide walks through the process of creating a central configuration management
for microservices using [Spring Cloud Config](https://cloud.spring.io/spring-cloud-config/)
integrating with [HashiCorp Vault](https://www.vaultproject.io/).

### Introduction

Nowadays, software is commonly delivered  as a service and doesn't matter the programming
language that was chosen, it's always good to follow [the twelve-factor app](https://12factor.net/) methodology.

The first factor is about the [codebase](https://12factor.net/codebase), it starts saying:

>One codebase tracked in revision control, many deploys

It means that the same codebase needs to be deployed in multiple environments without any change other than the
configuration, which brings us to the externalized configuration.

If you are working (or going to work) with microservices in an elastic environment, you probably
noticed the need for a central place for configuration management, and that's also 
[one of the twelve-factors](https://12factor.net/config).

### Pre-req
 
 * [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)
 * Text editor or your favorite IDE
 * [Maven 3.0+](https://maven.apache.org/download.cgi)
 * [Docker](https://www.docker.com/)

### Spring Cloud Config

[Spring Cloud Config](https://cloud.spring.io/spring-cloud-config/) provides server and client-side support for
externalized configuration in a distributed system and it has quite few backend storage support, this guide covers
the following:

  * [File System](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html#_file_system_backend)
  * [Git](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html#_git_backend)
  * [Vault](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html#vault-backend)

#### Setting the Config Server 

The easiest way to set up a Config Server is reaching [start.spring.io](http://start.spring.io/), search for `Config Server`
in the `dependencies` search box and hit the `Generate Project` button, it will generate a zip file containing the 
`Config Server` project with all the necessary dependencies. Unzip the project, open the main class and add the 
`@EnableConfigServer` on the class level.

You need to end up with something like this:

```java
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.config.server.EnableConfigServer;

@EnableConfigServer
@SpringBootApplication
public class ConfigServerApplication {

  public static void main(String[] args) {
    SpringApplication.run(ConfigServerApplication.class, args);
  }

}
```

{: .box-note}
The generated project has an `application.properties` file placed at `src/main/resources`, for personal preferences 
I renamed it to `application.yml`.

Open the `application.yml` file and add the following configuration, as I'm running all the applications in the same
host it's important to change the `server.port`.

```yaml
server:
  port: 8888

spring:
  application:
    name: configserver
```

#### Profiles & Auto of the box implementations

Spring Cloud Config Server uses `profiles` to provide multiple auto of the box backend storages implementations, let's
walk through some of them.

##### File System Backend

There's a `native` profile available where the `Config Server` searches for the properties/YAML files from the local classpath
or file system.

```yaml
spring:
  profiles:
    active: native
```

{: .box-note}
The default value of the searchLocations is identical to a local Spring Boot application (that is, 
`[classpath:/, classpath:/config, file:./, file:./config]`). This does not expose the application.properties 
from the server to all clients, because any property sources present in the server are removed before being 
sent to the client.

You can point to any location using `spring.cloud.config.server.native.searchLocations`.

{: .box-note}
Remember to use the file: prefix for `file` resources (the default without a prefix is usually the classpath). 
As with any Spring Boot configuration, you can embed `${}`-style environment placeholders, but remember that absolute 
paths in Windows require an extra / (for example, `file:///${user.home}/config-repo`).

For this guide I'll create a folder named `config-repo` in the `${user.home}`, this new folder is created to store the 
configuration files for the native profile.

Now add the following configuration to `application.yml`.

```yaml
spring:
  cloud:
    config:
      server:
        native:
          searchLocations: file://${user.home}/config-repo
```

Now create the file `config-repo/configclient.yml`, this file stores the configuration for our microservice (created later 
in this guide) named `configclient`, and add the following configuration.

```
client:
  pseudo:
    property: Property value loaded from File System
```

Now you can start the application and hit the endpoint `http://localhost:8888/configclient/default`, the response will be:

```json
{  
   "name":"configclient",
   "profiles":[  
      "default"
   ],
   "label":null,
   "version":null,
   "state":null,
   "propertySources":[  
      {  
         "name":"file:///Users/my-user/config-repo/configclient.yml",
         "source":{  
            "client.pseudo.property":"Property value loaded from File System"
         }
      }
   ]
}
```

{: .box-warning}
The `native` profile is a good way to start with `Config Server` on the local environment, but I don't recommend 
anyone to go to production using a file system based storage.

##### Git Backend

There's also a `git` profile where you can point to an external git repository that contains all the configurations files
for your microservices. To make it work you can either add the `git` profile to the active profiles or totally remove the
`spring.profiles.active` properties. If you choose to keep this property, the last specified profile has priority and 
overrides all the previously defined.

Add the following config:

```yaml
spring:
  profiles:
    active: native, git
  cloud:
    config:
      server:
        git:
          uri: https://github.com/weekly-drafts/config-repo-spring-cloud-configserver-vault
```

Here's the full configuration for reference:

```yaml
spring:
  profiles:
    active: native, git
  application:
    name: configserver
  cloud:
    config:
      server:
        native:
          searchLocations: file://${user.home}/config-repo
        git:
          uri: https://github.com/weekly-drafts/config-repo-spring-cloud-configserver-vault
```

Now if you hit the `http://localhost:8888/configclient/default` again, there will be the following result:

```json
{  
   "name":"configclient",
   "profiles":[  
      "default"
   ],
   "label":null,
   "version":null,
   "state":null,
   "propertySources":[  
      {  
         "name":"file:///Users/my-user/config-repo/configclient.yml",
         "source":{  
            "client.pseudo.property":"Property value loaded from File System"
         }
      },
      {  
         "name":"https://github.com/weekly-drafts/config-repo-spring-cloud-configserver-vault/configclient.yml",
         "source":{  
            "client.pseudo.property":"Property value loaded from Git"
         }
      }
   ]
}
```

{: .box-note}
If no profile is set `git` is the default one.

##### Vault Backend

About [Vault](https://www.vaultproject.io/):

{: .box-note}
Vault is a tool for securely accessing secrets. A secret is anything that to which you want to tightly control access, such as API keys, passwords, certificates, and other sensitive information. Vault provides a unified interface to any secret while providing tight access control and recording a detailed audit log.

There's also a `vault` profile that enables integration with [Vault](https://www.vaultproject.io/) to securely store the application properties, 
in this part, we'll be using `docker` to create a `vault` container.

Create a vault container:

```bash
docker run -d -p 8200:8200 --name vault -e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault
```

{: .box-warning}
It's specified the root token here, **do not** do that in production.

Enter in the vault container and authenticate to vault:

```bash
docker exec -i -t vault sh
export VAULT_ADDR='http://localhost:8200'
vault auth myroot
```

Now it's time to write our secret property:

```bash
vault write secret/configclient client.pseudo.property="Property value loaded from Vault"
```

Now we have everything in place, it's time to configure our `Config Server` to talk to `Vault`, add the following properties:

```yaml
spring:
  profiles:
    active: vault
  cloud:
    config:
      server:
        vault:
          port: 8200
          host: 127.0.01
```

Complete configuration for reference:

```yaml
spring:
  profiles:
    active: native, git, vault
  application:
    name: configserver
  cloud:
    config:
      server:
        native:
          searchLocations: file://${user.home}/config-repo
        git:
          uri: https://github.com/weekly-drafts/config-repo-spring-cloud-configserver-vault
        vault:
          port: 8200
          host: 127.0.01
```

{: .box-note}
You can also secure properties without vault using [encryption](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html#_encryption_and_decryption).

#### Setting the Config Client

As before, the easiest way to create the `config client` is reaching [start.spring.io](http://start.spring.io/) and adding 
`Config Client` and `Web` dependencies. Open the generated project, add a `resources/bootstrap.yml` with the following
content.

```yaml
spring:
  application:
    name: configclient
  cloud:
    config:
      token: myroot
      uri: http://localhost:8888
```

{: .box-note}
It's important to add exactly `configclient` as `spring.application.name` because that's the name used to bind to the external configuration.

Now open the main class and add a `@Value` to recover our `pseudo` property and return it to an endpoint, here's my main class for reference.

```java
@RestController
@SpringBootApplication
public class ConfigClientApplication {

    public static void main(String[] args) {
        SpringApplication.run(ConfigClientApplication.class, args);
    }

    @Value("${client.pseudo.property}")
    private String pseudoProperty;

    @GetMapping("/property")
    public ResponseEntity<String> getProperty() {
        return ResponseEntity.ok(pseudoProperty);
    }
}
```

After starting the project, you'll be able to reach `http://localhost:8080/property` and the expected result is:

```bash
Property value loaded from Vault
```

### Summary
Congratulations! You just created a central configuration management using [Spring Cloud Config](https://cloud.spring.io/spring-cloud-config/)
and secured all your secrets with [HashiCorp Vault](https://www.vaultproject.io/). 

### Footnote
  - The code used for this tutorial can be found on [github](https://github.com/weekly-drafts/spring-cloud-configserver-vault)
  - [Spring Cloud Config Docs](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html)