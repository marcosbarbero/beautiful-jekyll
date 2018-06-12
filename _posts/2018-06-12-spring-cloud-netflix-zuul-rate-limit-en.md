---
layout: post
title: Rate Limit - Spring Cloud Netflix Zuul
bigimg: /img/leaking-tap.jpg
gh-repo: marcosbarbero/spring-cloud-zuul-ratelimit
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-cloud, netflix, rate-limit, java]
permalink: /spring-cloud-netflix-zuul-rate-limit/
lang: en
---

In the development of APIs sometimes it's necessary to control the rate of the traffic received by the network 
to prevent attacks such as [DoS](https://en.wikipedia.org/wiki/Denial-of-service_attack) or to limit the number
of requests a single user/origin can make to a certain endpoint.

In a microservices architecture the API Gateway is the entry point for the whole application and having a rate 
limiting in this layer suits perfectly.

### Spring Cloud Netflix Zuul

[Spring Cloud Netflix Zuul](https://github.com/spring-cloud/spring-cloud-netflix) is an Open Source API Gateway that 
wraps [Netflix Zuul](https://github.com/Netflix/zuul) and add quite few funcionalities, sadly rate limiting is something
that's not provided out of the box.

### Adding Rate Limit on Zuul

To fix that problem it's possible to use [this OSS Rate Limit library](https://github.com/marcosbarbero/spring-cloud-zuul-ratelimit)
along with `Spring Cloud Netflix Zuul` in which will add an out of the box support for rate limiting the requests.

### Supported Limiters

The current implementation supports a list of rate limit policies per service as well as an default configuration for every other
service if necessary.

| Rate Limit Type     | Description                                    |
|---------------------|------------------------------------------------|
|`Authenticated User` | Uses the authenticated username or 'anonymous' |
|`Request Origin`     | Uses the user origin request                   |
|`URL`                | Uses the request path of the downstream service|
|`Global configuration per service` |This one does not validate the request Origin, Authenticated User or URI. To use this approach just don’t set any type |

### Supported storage

  - [In Memory](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ConcurrentHashMap.html)
  - [Consul](https://www.consul.io/)
  - [Redis](https://redis.io/)
  - JDBC (using spring-data-jpa)
  - [Bucket4j](https://github.com/vladimir-bukhtoyarov/bucket4j)
    - JCache
    - [Hazelcast](https://hazelcast.com/)
    - [Ignite](https://ignite.apache.org/)
    - [Infinispan](http://infinispan.org/)

### Implementation 

All the rate limiting implementation is done using [Zuul Filters](https://github.com/Netflix/zuul/wiki/Filters) and 
applying the validations based on the configuration set per service, in case there's no policy set then the rate 
limit filters are not triggered.

When a limit is reached the API Gateway returns `429 Too Many Requests` status code to the client.

### Configuration

Everything described above can be [configured using properties or yaml files](https://docs.spring.io/spring-boot/docs/current/reference/html/boot-features-external-config.html)
and there's no need to add any custom code to make it work.

### Further Details

For further details in the implementation and usage, please go to the [project repo](https://github.com/marcosbarbero/spring-cloud-zuul-ratelimit).
