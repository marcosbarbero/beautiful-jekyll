---
layout: post
title: Graceful Shutdown em Aplicações Spring Boot
gh-repo: weekly-drafts/graceful-shutdown-spring-boot
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-boot, tomcat, java, tutorial]
bigimg: /img/unplug.jpg
share-img: /img/unplug.jpg
permalink: /graceful-shutdown-spring-boot-apps/
lang: pt_BR
---

Esse tutorial te guiará no processo de desligar graciosamente uma aplicação [Spring Boot](https://spring.io/projects/spring-boot).

{: .box-note}
A implementação nesse post foi criada originalmente por [Andy Wilkinson](https://twitter.com/ankinson) 
e adaptada por mim para Spring Boot 2. O código é baseado nesse 
[comentário no GitHub](https://github.com/spring-projects/spring-boot/issues/4657#issuecomment-161354811).

### Introdução

Muitos desenvolvedores e arquitetos discutem sobre o design de uma aplicação, tráfego, frameworks, design patterns
que serão aplicados, mas bem poucos discutem sobre a como desligar a aplicação.

Vamos considerar esse cenário, há uma aplicação com um longo processo sincrono e essa aplicação precisa ser desligada
e substituída por uma nova versão. Não seria melhor se ao invés de matar todas as conexões a aplicação esperasse os
processos terminarem antes de desligar?

É isso o que nós vamos cobrir nesse tutorial!

### Pre-req

 - [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
 - Editor de texto ou sua IDE favorita
 - [Maven 3.0+](https://maven.apache.org/download.cgi)

### Spring Boot, Tomcat 

Para fazer essa funcionalidade funcionar, o primeiro passo é implementar `TomcatConnectorCustomizer`.

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

Na implementação acima o `ThreadPoolExecutor` esperará `30` segundos antes de prosseguir com o desligamento, simples, correto?
Agora é necessário registrar esse bean ao `contexto da aplicação` e injetá-lo no `Tomcat`.

Para isso, apenas crie os seguintes Spring `@Bean`s.

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

### Como testar?

Para testar essa implementação eu criei um `LongProcessController` que contem uma `Thread.sleep` de `10` segundos.

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

Agora é só uma questão de iniciar a aplicação, fazer um request para o endpoint `/long-process` e nesse
meio tempo derrubar a aplicação com um `SIGTERM`.

#### Encontre o id do processo

Quando a aplicação é iniciada você pode encontrar o id do processo nos logs, no meu caso é `6578`.

```bash
2018-06-28 20:37:28.292  INFO 6578 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http) with context path ''
2018-06-28 20:37:28.296  INFO 6578 --- [           main] c.m.wd.gracefulshutdown.Application      : Started Application in 2.158 seconds (JVM running for 2.591)
```

#### Request e shutdown

Execute um request para o endpoint `/long-process`, Eu estou usando [curl](https://curl.haxx.se/) para isso:

```bash
$ curl -i localhost:8080/long-process
```

Envie um `SIGTERM` para o processo:

```bash
$ kill 6578
```

O request que fizemos usando `curl` ainda precisa responder como abaixo:

```bash
HTTP/1.1 200
Content-Type: text/plain;charset=UTF-8
Content-Length: 14
Date: Thu, 28 Jun 2018 18:39:56 GMT

Process finished
```

### Sumário
Parabéns! Você acabou de aprender como graciosamente desligar uma aplicação spring-boot (eu sei, essa tradução é estranha).

### Nota de rodapé
  - O código usado nesse tutorial pode ser encontrado no [GitHub](https://github.com/weekly-drafts/graceful-shutdown-spring-boot)
  - Essa implementação foi baseada nesse [comentário](https://github.com/spring-projects/spring-boot/issues/4657#issuecomment-161354811)