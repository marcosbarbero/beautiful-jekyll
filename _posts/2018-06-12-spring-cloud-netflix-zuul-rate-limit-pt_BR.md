---
layout: post
title: Adicionando Rate Limit no Spring Cloud Netflix Zuul
bigimg: /img/spring-cloud-ratelimit-thumb.jpg
share-img: /img/spring-cloud-ratelimit-thumb.jpg
gh-repo: marcosbarbero/spring-cloud-zuul-ratelimit
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-cloud, netflix, rate-limit, java]
permalink: /spring-cloud-netflix-zuul-rate-limit/
lang: pt_BR
---

No desenvolvimento de APIs algumas vezes é necessário controlar a taxa de trafego que é recebido pela rede
para previnir ataques como [DoS](https://en.wikipedia.org/wiki/Denial-of-service_attack) ou limitar o número
de requests que um único usuário/origem pode fazer para um dado recurso.

Numa arquitetura de microservices o API Gateway é o ponto de entrada para toda aplicação e aplicar regras para
limitar o número de acessos nessa camada se encaixa perfeitamente.

### Spring Cloud Netflix Zuul

[Spring Cloud Netflix Zuul](https://github.com/spring-cloud/spring-cloud-netflix) é um API Gateway Open Source que
encapsula [Netflix Zuul](https://github.com/Netflix/zuul) e adiciona várias funcionalidades, infelizmente rate limiting 
não é algo presente por padrão.

### Adicionando Rate Limit no Zuul

Para corrigir esse problema é possível usar [essa biblioteca OSS](https://github.com/marcosbarbero/spring-cloud-zuul-ratelimit)
junto com `Spring Cloud Netflix Zuul` no qual irá adicionar suporte para fazer rate-limiting dos requests.

### Limitadores Suportados

A implementação atual suporta uma lista de configurações por serviço assim como uma configuração padrão para todos os outros serviços
caso seja necessário.

| Rate Limit Type     | Descrição                                      |
|---------------------|------------------------------------------------|
|`Usuário autenticado` | Usa o username do usuário autenticado ou 'anonymous' |
|`Origem do request    | Usa o IP de origem do usuário                  |
|`URL`                | Usa o caminho do request para o downstream service|
|`Configuração global por serviço` | Esse não valida origem do request, autenticação ou URI. Para usar essa abordagem basta não setar nenhum tipo |

### Armazenamentos Suportados

  - [In Memory](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ConcurrentHashMap.html)
  - [Consul](https://www.consul.io/)
  - [Redis](https://redis.io/)
  - JDBC (using spring-data-jpa)
  - [Bucket4j](https://github.com/vladimir-bukhtoyarov/bucket4j)
    - JCache
    - [Hazelcast](https://hazelcast.com/)
    - [Ignite](https://ignite.apache.org/)
    - [Infinispan](http://infinispan.org/)

### Implementação 

Todas as implementações de rate-limiting são feitas usando [Zuul Filters](https://github.com/Netflix/zuul/wiki/Filters) e
aplicando validações baseadas nas configurações por serviço, no caso de não existir uma configuração os filtros não são acionados.

Quando um limite é alcançado o API Gateway retorna o status code `429 Too Many Requests` para o cliente.

### Configuração

Tudo o que foi descrito acima pode ser 
[configurado usando arquivo properties ou YAML](https://docs.spring.io/spring-boot/docs/current/reference/html/boot-features-external-config.html)
e não há necessidade de adicionar nenhum código para fazer funcionar.

### Mais Detalhes

Para mais detalhes na implementação e uso, por favor visite o [repositório do projeto](https://github.com/marcosbarbero/spring-cloud-zuul-ratelimit).
