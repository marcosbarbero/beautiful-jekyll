---
layout: post
title: HA and Zone Affinity With Spring Cloud Netflix Eureka
bigimg: /img/ha-discovery.jpg
share-img: /img/ha-discovery.jpg
gh-repo: weekly-drafts/spring-cloud-eureka-zone-affinity
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-cloud, ha, netflix, tutorial]
permalink: /ha-and-zone-affinity-spring-cloud-eureka/
lang: pt_BR
---

Esse tutorial te guiará no processo de configurar zonas de afinidade usando Spring Cloud Netflix Eureka.

### O que você irá construir
Você construirá três aplicações

 * API Gateway - [Spring Cloud Netflix Zuul](https://cloud.spring.io/spring-cloud-netflix/)
 * Service Registry - [Spring Cloud Netflix Eureka](https://cloud.spring.io/spring-cloud-netflix/)
 * REST Service - [Spring Cloud](http://projects.spring.io/spring-cloud/)

Todas as três aplicações são necessárias para ter certeza que a nossa configuração está correta. Cada uma dela
será deployada duas vezes, uma por zona.

### Pre-Req

 * [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)
 * Editor de texto ou IDE
 * [Maven 3.0+](https://maven.apache.org/download.cgi)

### Afinidade de Zonas
Não importa em qual estilo de arquitetura uma aplicação está usando, é um caso de uso muito comum ter a mesma aplicação deployada
em multiplas regiões/data centers e usar algumas técnicas para manter os requests dentro da mesma zona.

Numa arquitetura de microservices, também existe a necessidade de manter o request dentro da mesma zona e isso precisa ser aplicado
usando o [Design Pattern - Service Registry](http://microservices.io/patterns/service-registry.html).

### Spring Cloud Netflix
[Spring Cloud Netflix](https://cloud.spring.io/spring-cloud-netflix/) torna fácil a implementação dos 
[design patterns para microservices](http://microservices.io/patterns/).

### Criando as Aplicações
Nesse tutorial nós criaremos três aplicações, se você tem familiaridade com `spring-cloud` isso será muito fácil,
todas as aplicações criadas não são nada além de uma simples aplicação `spring-boot`.

A parte principal são os arquivos de configurações que serão mostrados adiante.

### Dependencias Base
Adicione as seguintes dependencias para todas as aplicações. Se houver alguma dependência específica para alguma aplicação isso 
será mencionado em cada tópico específico.

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
A primeira aplicação que criaremos será o API Gateway usando
[Spring Cloud Netflix Zuul](https://cloud.spring.io/spring-cloud-netflix).
Primeiro adicione a seguinte dependencia no `pom.xml`.

```java
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-zuul</artifactId>
</dependency>
```

#### Java Config
Agora basta criar a classe principal e adicionar a anotação `@EnableZuulProxy`.

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
A segunda aplicação que criaremos é o Service Registry usando
[Spring Cloud Netflix Eureka](https://cloud.spring.io/spring-cloud-netflix).
Primeiro adicione a seguinte dependência ao `pom.xml`.

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-eureka-server</artifactId>
</dependency>
```

#### Java Config
Agora basta criar a classe principal e adicionar a anotação `@EnableEurekaServer`.

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

### REST Service
A terceira aplicação contém nada além de um endoint REST que retorna a `zona` onde a aplicação está rodando,
apenas para termos certeza de que cada request se manterá na mesma região.

Para essa aplicação não há necessidade de acrescentar nenhuma dependência específica.

#### Java Config
Para facilitar as coias eu estou criando uma classe aninhada que será nosso `RestController`, esse controller retornará a zona onde a 
aplicação foi deployada.

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

#### Properties
Como ceitei anteriormente, cada aplicação precisa ser deployada duas vezes para simular duas zonas distintas,
para facilitar nós criaremos as configurações baseadas em [profiles](https://docs.spring.io/spring-boot/docs/current/reference/html/boot-features-profiles.html), 
para cada aplicação nós criaremos os seguintes três arquivos:

```bash
src/main/resources/application.yml
src/main/resources/application-zone1.yml
src/main/resources/application-zone2.yml
```

{: .box-note}
O sufixo no nome do arquivo será usado como nome do profile.

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

Todas as seguintes propriedades estão debaixo da propriedade `eureka.client`.

|Property           | Description    |
|-------------------|----------------|
|region             |Uma String contendo o nome da região onde a aplicação será deployada |
|service-url        |Um mapa contendo uma lista URLs com as zonas de disponibilidade para a região |
|availability-zones |Um mapa contendo uma lista delimitada por vírgula contendo uma lista de zonas |


As propriedades `register-with-eureka` e `fetch-registry` estão previnindo que o Eureka Server seja adicionado para a lista de aplicações,
mas isso não é tão importante para esse tutorial.

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

Para os profiles `-zone1` e `-zone2` a única diferença é o `server.port`, a zona está configurada em
`eureka.metadataMap.zone`, e nesse caso o hostname, cada Eureka Server precisa rodar em hosts diferentes,
como eu estou executando ambos no mesmo host eu estou nomeando como `127.0.0.1` e `localhost`.

{: .box-note}
Não é necessário adicionar o hostname caso você esteja rodando em hosts diferentes.

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

Como antes, a única mudança entre os perfis são a zona de disponibilidade e a porta.

#### REST Service
Esse serviço tem a mesma configuração do API Gateway.

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
Agora é hora de compilar as aplicações, se (assim como eu) você está usando maven então apenas execute:

```bash
$ mvn clean package
```

Logo após isso execute cada aplicação adicionando o profile específico, por exemplo:

```bash
$ java -jar target/*.jar --spring.profiles.active=zone1
```

{: .box-note}
Lembre-se que você precisará executar duas vezes cada aplicação, uma para cada profile: `zone1` e `zone2`.


### Validando
Para validar se cada request está respeitando as zonas nós faremos o request através do Gateway.

```bash
$ curl http://localhost:8080/simple-service/zone
{"zone"="zone1"}
$ curl http://localhost:8081/simple-service/zone
{"zone"="zone2"}
```

{: .box-note}
A única diferença entre cada zona é a porta onde o serviço está rodando.

### Validando o failover das zonas
Para validar o failover entre as zonas você so precisa parar uma das instancias e fazer o request na zona oposta, exemplo:

 1. Pare o serviço `simple-service` na zone2.
 1. Faça um request para o `simple-service` na zone2 através do Gateway.

```bash
$ curl http://localhost:8081/simple-service/zone
```

Agora o resultado experado é um `JSON` contendo `{"zone"="zone1"}`.  
Uma vez que o `simple-service` volte a rodar e está registrado no Eureka Server o mesmo request deve voltar a responder `{"zone"="zone2"}`.

{: .box-note}
Leva algum tempo até que o `simple-service` esteja disponível na zona oposta, seja paciente e divirta-se!

### Sumário
Parabéns! Você acabou de criar e configurar um API Gateway, Service Registry e um serviço REST que resposta zonas de afinidade
trazendo mais resiliencia e disponibilidade para os teus microservices.

### Nota de Rodapé
  - O código usado nesse tutorial pode ser encontrado no [GitHub](https://github.com/weekly-drafts/spring-cloud-eureka-zone-affinity)