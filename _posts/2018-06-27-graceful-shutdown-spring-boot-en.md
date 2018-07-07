---
layout: post
title: Graceful Shutdown Spring Boot Applications
gh-repo: weekly-drafts/graceful-shutdown-spring-boot
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-boot, tomcat, java, tutorial]
bigimg: /img/unplug.jpg
<!-- share-img: /img/unplug.jpg -->
permalink: /graceful-shutdown-spring-boot-apps/
lang: en
---

This guide walks through the process of graceful shutdown a [Spring Boot](https://spring.io/projects/spring-boot)
application.

{: .box-note}
The implementation of this blog post is originally created by [Andy Wilkinson](https://twitter.com/ankinson) 
and adapted by me to Spring Boot 2. The code is based on this 
[GitHub comment](https://github.com/spring-projects/spring-boot/issues/4657#issuecomment-161354811).


### Introduction

A lot of developers and architects discuss about the application design, traffic load, frameworks, patterns 
to apply, but very few of them are discussing about the shutdown phase.

Let's considere this scenario, there's an application in which has a long blocking process and this app needs
to be shutdown to be replaced with a newer version. Wouln't be nice if instead of killing all the connections
it just gracefully wait then to finish before the shutdown?

That's what we are going to cover in this guide!

### Pre-req

 - [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
 - Text editor or your favorite IDE
 - [Maven 3.0+](https://maven.apache.org/download.cgi)

### Spring Boot, Tomcat 

To make this feature work, the first step is to implement `TomcatConnectorCustomizer`.

```java
import org.apache.catalina.connector.Connector;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.web.embedded.tomcat.TomcatConnectorCustomizer;
import org.springframework.context.ApplicationListener;
import org.springframework.context.event.ContextClosedEvent;

import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

public class GracefulShutdown implements TomcatConnectorCustomizer, ApplicationListener<ContextClosedEvent> {

    private static final Logger log = LoggerFactory.getLogger(GracefulShutdown.class);

    private static final int TIMEOUT = 30;

    private volatile Connector connector;

    @Override
    public void customize(Connector connector) {
        this.connector = connector;
    }

    @Override
    public void onApplicationEvent(ContextClosedEvent event) {
        this.connector.pause();
        Executor executor = this.connector.getProtocolHandler().getExecutor();
        if (executor instanceof ThreadPoolExecutor) {
            try {
                ThreadPoolExecutor threadPoolExecutor = (ThreadPoolExecutor) executor;
                threadPoolExecutor.shutdown();
                if (!threadPoolExecutor.awaitTermination(TIMEOUT, TimeUnit.SECONDS)) {
                    log.warn("Tomcat thread pool did not shut down gracefully within "
                            + TIMEOUT + " seconds. Proceeding with forceful shutdown");

                    threadPoolExecutor.shutdownNow();

                    if (!threadPoolExecutor.awaitTermination(TIMEOUT, TimeUnit.SECONDS)) {
                        log.error("Tomcat thread pool did not terminate");
                    }
                }
            } catch (InterruptedException ex) {
                Thread.currentThread().interrupt();
            }
        }
    }

}
```

In the implementation above the `ThreadPoolExecutor` will be waiting `30` seconds prior to proceed to the shutdown, pretty simple, right?
With that in place it's now necessary to register this bean to the `application context` and inject it to `Tomcat`.

To do that, just create the following Spring `@Bean`s.

```java
@Bean
public GracefulShutdown gracefulShutdown() {
    return new GracefulShutdown();
}

@Bean
public ConfigurableServletWebServerFactory webServerFactory(final GracefulShutdown gracefulShutdown) {
    TomcatServletWebServerFactory factory = new TomcatServletWebServerFactory();
    factory.addConnectorCustomizers(gracefulShutdown);
    return factory;
}
```

### How to test?

To test this implementation I just created a `LongProcessController` in which has a `Thread.sleep` of `10` seconds.

```java
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class LongProcessController {

    @RequestMapping("/long-process")
    public String pause() throws InterruptedException {
        Thread.sleep(10000);
        return "Process finished";
    }

}
```

Now it's just a matter of run your spring boot application, make a request to the `/long-process` endpoint
and in the meantime kill it with a `SIGTERM`.

#### Locate the process id

When you start the application, you can locate the process id in the logs, in my case it's `6578`.

```bash
2018-06-28 20:37:28.292  INFO 6578 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http) with context path ''
2018-06-28 20:37:28.296  INFO 6578 --- [           main] c.m.wd.gracefulshutdown.Application      : Started Application in 2.158 seconds (JVM running for 2.591)
```

#### Request and shutdown

Perform a request to the `/long-process` endpoint, I'm using `curl`for that:

```bash
$ curl -i localhost:8080/long-process
```

Send a `SIGTERM` to the process:

```bash
$ kill 6578
```

The `curl` request still needs to respond as below:

```bash
HTTP/1.1 200
Content-Type: text/plain;charset=UTF-8
Content-Length: 14
Date: Thu, 28 Jun 2018 18:39:56 GMT

Process finished
```

### Summary
Congratulations! You just learned how to graceful shutdown Spring Boot apps.

### Footnote
  - The code used for this tutorial can be found on [GitHub](https://github.com/weekly-drafts/graceful-shutdown-spring-boot)
  - This implementation was based on this [comment](https://github.com/spring-projects/spring-boot/issues/4657#issuecomment-161354811)