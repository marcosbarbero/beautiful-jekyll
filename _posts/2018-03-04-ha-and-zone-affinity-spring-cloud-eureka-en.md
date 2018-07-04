---
layout: post
title: HA and Zone Affinity With Spring Cloud Netflix Eureka
bigimg: /img/ha-discovery.jpg
share-img: /img/ha-discovery.jpg
gh-repo: weekly-drafts/spring-cloud-eureka-zone-affinity
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-cloud, ha, netflix, tutorial]
permalink: /ha-and-zone-affinity-spring-cloud-eureka/
lang: en
---

This tutorial will guide you through the process to setup zone affinity in Spring Cloud Netflix Eureka.

### What You Will Build
You will build three applications:

 * API Gateway - [Spring Cloud Netflix Zuul](https://cloud.spring.io/spring-cloud-netflix/)
 * Service Registry - [Spring Cloud Netflix Eureka](https://cloud.spring.io/spring-cloud-netflix/)
 * REST Service - [Spring Cloud](http://projects.spring.io/spring-cloud/)

All those are necessary to make sure that our zone affinity setup is correct. Each of them will be deployed 
twice, one per zone.

### Pre-Req

 * [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)
 * Text editor or your favorite IDE
 * [Maven 3.0+](https://maven.apache.org/download.cgi)

### Zone Affinity
It doesn't matter which kind of architectural style the application is using, it's a common use case to have the same application deployed 
in different regions/data centers and use some technique to keep the requests within the same zone.

In microservices architecture, there's also a need to achieve the same thing but the technique needs to be applied using the 
[Service Registry Design Pattern](http://microservices.io/patterns/service-registry.html).

### Spring Cloud Netflix
[Spring Cloud Netflix](https://cloud.spring.io/spring-cloud-netflix/) 
makes it easy to implement the necessary [patterns for microservices](http://microservices.io/patterns/).

### Creating the Applications
In this guide, we'll create three applications, and if you're familiar with spring-cloud, it will be an easy job, 
all the created applications are nothing more than a simple runnable spring-boot jar.

The main part here is the configuration files that will be shown further on.

### Base Dependencies
Add the following dependencies for all the applications. If there's any diff for any specific application, it will be mentioned in each specific thread.

```xml
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>1.5.9.RELEASE</version>
    </parent>
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>Edgware.SR2</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-eureka</artifactId>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
```

### API Gateway
The first application we'll create will be the API Gateway using 
[Spring Cloud Netflix Zuul](https://cloud.spring.io/spring-cloud-netflix).
First, add the following dependency in the pom.xml.

```java
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-zuul</artifactId>
</dependency>
```

#### Java Configuration
Now just create the main SpringApplication class adding `@EnableZuulProxy`.

```java
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.netflix.zuul.EnableZuulProxy;

@EnableZuulProxy
@EnableDiscoveryClient
@SpringBootApplication
public class GatewayApplication {
    public static void main(String... args) {
        SpringApplication.run(GatewayApplication.class, args);
    }
}
```

### Service Registry
The second application we'll create will be the Service Registry using 
[Spring Cloud Netflix Eureka](https://cloud.spring.io/spring-cloud-netflix).
First, add the following dependency in the pom.xml.

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-eureka-server</artifactId>
</dependency>
```

#### Java Configuration
Now just create the main SpringApplication class adding @EnableEurekaServer.

```java
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

@EnableEurekaServer
@SpringBootApplication
public class ServiceDiscoveryApplication {
    public static void main(String... args) {
        SpringApplication.run(ServiceDiscoveryApplication.class, args);
    }
}
```

### Simple REST Service
The third application contains nothing more than a REST endpoint to make sure that each call from each 
region will remain in the requested region. For this application, there's nothing to add to the base pom.xml.

#### Java Configuration
To make things easier, I'm creating the main class with a nested RestController, the following controller returns which zone is this application deployed.

```java
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import static org.springframework.http.MediaType.APPLICATION_JSON_UTF8_VALUE;

@EnableDiscoveryClient
@SpringBootApplication
public class SimpleService {
    public static void main(String... args) {
        SpringApplication.run(SimpleService.class, args);
    }
    @RestController
    class SimpleController {
        @Value("${eureka.instance.metadataMap.zone}")
        private String zone;
        @GetMapping(value = "/zone", produces = APPLICATION_JSON_UTF8_VALUE)
        public String zone() {
            return "{\"zone\"=\"" + zone + "\"}";
        }
    }
}
```

#### Configuration Properties
As it was previously mentioned, each application needs to run twice in order to simulate two distinct regions, 
to make it easier we'll create the configuration based on [profiles](https://docs.spring.io/spring-boot/docs/current/reference/html/boot-features-profiles.html), 
for each application create the following three files:

```bash
src/main/resources/application.yml
src/main/resources/application-zone1.yml
src/main/resources/application-zone2.yml
```

{: .box-note}
The suffix in the filename will be used as the profile name.

#### Service Registry
```yaml
# src/main/resources/application.yml
eureka:
  client:
    register-with-eureka: false
    fetch-registry: false
    region: region-1
    service-url:
      zone1: http://localhost:8761/eureka/
      zone2: http://127.0.0.1:8762/eureka/
    availability-zones:
      region-1: zone1,zone2
spring.profiles.active: zone1
```

All the following properties are in eureka.client namespace.

|Property           | Description    |
|-------------------|----------------|
|region             |A String containing a name for the region where the application will be deployed |
|service-url        |A Map containing the list of available zones for the given region                |
|availability-zones |A Map containing a comma-separated list of zones for the given region      |


The properties register-with-eureka and fetch-registry are disabling the Service Registry to be added in the applications list but it's not that important for this setup.

```yaml
# src/main/resources/application-zone1.yml
server.port: 8761
eureka:
  instance:
    hostname: localhost
    metadataMap.zone: zone1
```

```yaml    
# src/main/resources/application-zone2.yml
server.port: 8762
eureka:
  instance:
    hostname: 127.0.0.1
    metadataMap.zone: zone2
```

For the `-zone1` and `-zone2` profiles the only difference are the server.port, the actual zone 
configured in eureka.metadataMap.zone, and in this case the hostname, each Eureka Server needs 
to run in a different hostname; as I'm running both in the same machine I'm naming it as 127.0.01 and localhost.

{: .box-note}
It's not necessary to add the hostname in case you are running on different machines.

#### Gateway
```yaml
# src/main/resources/application.yml
eureka:
  client:
    prefer-same-zone-eureka: true
    region: region-1
    service-url:
      zone1: http://localhost:8761/eureka/
      zone2: http://127.0.0.1:8762/eureka/
    availability-zones:
      region-1: zone1,zone2
spring:
  profiles.active: zone1
  application.name: gateway
management.security.enabled: false
```

The main difference here is the property `eureka.client.prefer-same-zone-eureka`, it is telling to the application that 
whenever it needs to make a call to another `EurekaClient` it will call it using the same zone where the caller is deployed. 
In case there's no available client in the same zone, it will call from another zone in which it's available.

```yaml
# src/main/resources/application-zone1.yml
server.port: 8080
eureka:
  instance:
    metadataMap.zone: zone1
```

```yaml    
# src/main/resources/application-zone2.yml
server.port: 8081
eureka:
  instance:
    metadataMap.zone: zone2
```

As before, this per profile configuration only changes the availability zone and the running port.

#### Simple REST Service
The configuration for the service itself contains the same configuration as the Gateway.

```yaml
# src/main/resources/application.yml
eureka:
  client:
    prefer-same-zone-eureka: true
    region: region-1
    service-url:
      zone1: http://localhost:8761/eureka/
      zone2: http://127.0.0.1:8762/eureka/
    availability-zones:
      region-1: zone1,zone2
spring:
  profiles.active: zone1
  application.name: simple-service
```

```yaml
# src/main/resources/application-zone1.yml
server.port: 8181
eureka:
  instance:
    metadataMap.zone: zone1
```

```yaml
# src/main/resources/application-zone2.yml
server.port: 8182
eureka:
  instance:
    metadataMap.zone: zone2
```

### Build & Run
It's time to build the applications; if you are building the application using maven (like I did), just build them executing:

```bash
$ mvn clean package
```

Right after that just run each application adding the specific profile to the command line, e.g:

```bash
$ java -jar target/*.jar --spring.profiles.active=zone1
```

{: .box-note}
Remember that you need to run each application twice, once each profile: zone1 and zone2.


### Validation
To validate if the requests are respecting each zone we need to make a request to the simple-service through each gateway.

```bash
$ curl http://localhost:8080/simple-service/zone
{"zone"="zone1"}
$ curl http://localhost:8081/simple-service/zone
{"zone"="zone2"}
```

{: .box-note}
The difference between each zone here is the server.port.

### Zone Failover Validation
To validate the failover between zones you just need to stop one of the instances and make a request to the opposite zone, e.g:

 1. Stop simple-service on zone2.
 1. Make a request to simple-service through the gateway on zone2.

```bash
$ curl http://localhost:8081/simple-service/zone
```

The expected result now will be a `JSON` containing `{"zone"="zone1"}`.  
Once the simple-service for zone1 is up, running and registered in Eureka Server the same curl has to respond `{"zone"="zone2"}` again.

{: .box-note}
It takes a while to the simple-service be available in the opposite zone, be patient and have fun!

### Summary
Congratulations! You just created and configured an API Gateway, Service Registry and a Simple REST Service that respects zone affinity bringing to your microservices more resilience and HA.

### Footnote
  - The code used for this tutorial can be found on [github](https://github.com/weekly-drafts/spring-cloud-eureka-zone-affinity)