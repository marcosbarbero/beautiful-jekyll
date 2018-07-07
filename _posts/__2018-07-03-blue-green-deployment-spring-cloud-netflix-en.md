---
layout: post
title: Blue-Green Deployment with Spring Cloud Netflix Stack
gh-repo: weekly-drafts/blue-green-deployment-spring-cloud-netflix
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-cloud, ha, java, tutorial]
permalink: /blue-green-deployment-spring-cloud-netflix/
lang: en
---

This guide walks through the process of achieving [Blue Green Deployment](https://martinfowler.com/bliki/BlueGreenDeployment.html)
with [Spring Cloud Netflix](https://cloud.spring.io/spring-cloud-netflix/) stack.

### Introduction

Blue-Green deployment is a technique used for [CI](https://martinfowler.com/articles/continuousIntegration.html) /
[CD](https://martinfowler.com/bliki/ContinuousDelivery.html) where you have two environments with different versions
of your app deployed and one of the environments you use for production and the second one you can you for the final
test phase before sending the real traffic. This approach gives you a way for a rapid rollback if for some reason 
anything goes wrong.

There are quite few ways to achive blue-green deployment, in this guide I'll describe how to do that using 
[Spring Cloud Netflix](https://cloud.spring.io/spring-cloud-netflix/) stack.

### Pre-req

 - [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
 - Text editor or your favorite IDE
 - [Maven 3.0+](https://maven.apache.org/download.cgi)
 - [Spring Cloud CLI](https://cloud.spring.io/spring-cloud-cli/)

### Architecture overview

In our architecture we will have an `API Gateway` routing all the traffic to the downstream applications,
we will be also using [Service Registry Design Pattern](http://microservices.io/patterns/service-registry.html)
to enable [Client-Side Load Balancing](http://microservices.io/patterns/client-side-discovery.html).


<div style="text-align:center">
    <img src="/img/blue-green-arch-overview.png" />
</div>

### Discovery Service
We will be using `Spring Cloud Netflix Eureka` to solve the 
[Service Registry Design Pattern](http://microservices.io/patterns/service-registry.html). The easiest way
to have an `Eureka Server` up and running is installing [Spring Cloud CLI](https://cloud.spring.io/spring-cloud-cli/),
with that in place just run the following command:

```bash
$ spring cloud eureka
```

This command will spin up an `Eureka Server` running at `http://localhost:8761`.

### Downstream Service

The downstream service is very simple, it only shows which environment the application is deployed, it can
be either `green` or `blue`.

To create this app I just went to [start.spring.io](http://start.spring.io/) and selected `Web` and 
`Eureka Discovery` as dependency, and then I added the following configuration:


`src/main/resources/application.yml`

```yaml
spring:
  application:
    name: bluegreen

eureka:
  instance:
    metadata-map:
      env: green

---
spring:
  profiles: blue

server:
  port: 8081

eureka:
  instance:
    metadata-map:
      env: blue
```

The configuration above contains two profiles, the `default` profile is used for the `green` environment,
and `blue` profile that's used for the `blue` environment. Another important piece in this configuration 
is the `eureka.instance.metadata-map`, it will be used by the `API Gateway` to route the requests to the
correct environment.

To validate the environment just create a `controller` that returns its deployed environment.

```java
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MetadataController {

    @Value("${eureka.instance.metadata-map.env}")
    private String env;

    @GetMapping("/metadata/env")
    public String env() {
        return env;
    }
}
```

Now just build and run this application twice, once for each environment.

#### Build

```bash
$ mvn clean package
```

#### Green Environment

##### Run

```bash
$ java -jar target/blue-green-0.0.1-SNAPSHOT.jar
```

##### Validate
The `Green app` runs on `localhost:8080`, to validate its response just request the `endpoint` that we
created above.

```bash
$ curl -i localhost:8080/metadata/env
HTTP/1.1 200
Content-Type: text/plain;charset=UTF-8
Content-Length: 5
Date: Tue, 03 Jul 2018 20:10:55 GMT

green
```

#### Blue environment

##### Run

```bash
$ java -jar target/blue-green-0.0.1-SNAPSHOT.jar --spring.profiles.active=blue
```

##### Validate
The `Blue app` runs on `localhost:8081`, to validate its response just request the `endpoint` that we
created above.

```bash
$ curl -i localhost:8081/metadata/env
HTTP/1.1 200
Content-Type: text/plain;charset=UTF-8
Content-Length: 4
Date: Tue, 03 Jul 2018 20:12:23 GMT

blue
```

### API Gateway




### Summary
Congratulations! You just created a blue green deployment using `Spring Cloud Netflix` stack.

### Footnote
  - The code used for this tutorial can be found on [GitHub](https://github.com/weekly-drafts/blue-green-deployment-spring-cloud-netflix)