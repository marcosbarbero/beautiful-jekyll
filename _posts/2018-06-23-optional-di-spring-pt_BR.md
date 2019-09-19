---
layout: post
title: Injeção de Dependencias Opcionais usando Spring
gh-repo: weekly-drafts/spring-optional-dependency-injection
gh-badge: [star, fork, follow]
bigimg: /img/optional-di-spring.jpg
share-img: /img/optional-di-spring.jpg
tags: [spring-framework, di, java, tutorial]
permalink: /optional-di-spring/
lang: pt_BR
---

Esse tutorial mostra as opções disponíveis para injetar dependencias opcionais usando
[Spring DI](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-spring-beans-and-dependency-injection.html).

### Introduction

Existem vários casos de uso onde é necessário tornar opcional algumas das dependencias injetadas, aqui alguns exemplos:

 * Prover uma implementação padrão sempre que uma dependencias obrigatória de infraestutura não é provida, tal como `DataSource`s.
 * Previnir o uso de dependencias de estratégia de monitoramento dependendo do ambiente.
 * Se você está construindo o seu [próprio component spring-boot auto-configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/boot-features-developing-auto-configuration.html), algumas vezes é necessário ter dependencias opcionais.

### @Autowired

A abordagem mais comum para conseguir uma injeção opcional é simplesmente usar o `@Autowired(required = false)`, 
por exemplo:

```java
@Autowired(required = false)
private HelloService helloService;
```

Isso funciona e nos leva onde queríamos, entretanto, eu não recomendo o uso de `field` injection e uma das razões
para isso é a camada de `test` da aplicação. Sempre que field injection for usado é obrigatório o uso de `reflection`
para injetar uma implementação diferente baseado no caso de teste.

### Java 8 Optional

Você já deve estar familiarizado com o tipo `Optional` do Java 8, ele também pode ser usado para fazer `DI` no Spring,
por exemplo:

```java
@RestController
public class HelloController {

    private Optional<HelloService> optionalHelloService;

    public HelloController(Optional<HelloService> helloService) {
        this.optionalHelloService = helloService;
    }

    @GetMapping("/hello")
    public String hello() {
        return optionalHelloService.map(HelloService::hello)
                .orElse("Hello there, fallback!");
    }

}
```

A implementação acima te da um `Optional` monad onde pode-se fazer uma validação para saber se a há implementação
antes de usá-la.

### Spring's ObjectProvider

Desde o Spring 4.3 existe uma classe chamada [ObjectProvider](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/beans/factory/ObjectProvider.html)
criada especificamente para pontos de injeção. 

Do javadoc:

>A variant of `ObjectFactory` designed specifically for injection points, allowing for programmatic optionality and lenient not-unique handling.

Usando o mesmo exemplo anterior:

```java
@RestController
public class HelloController {

    private HelloService helloService;

    public HelloController(ObjectProvider<HelloService> helloServiceProvider) {
        this.helloService = helloServiceProvider.getIfAvailable(DefaultHelloService::new);
    }

    @GetMapping("/hello")
    public String hello() {
        return helloService.hello();
    }

    class DefaultHelloService implements HelloService {

        @Override
        public String hello() {
            return "Hello there, fallback!";
        }
    }

}
```

Nesse exemplo, além de opcional também é provida uma implementação padrão como fallback.

### Summary
Parabéns! Você acabou de aprender algumas maneiras de fazer DI opcionais com Spring.

### Footnote
  - O código usado nesse tutorial pode ser encontrado no [GitHub](https://github.com/weekly-drafts/spring-optional-dependency-injection)
  - Mais sobre [IoC e DI](http://www.baeldung.com/inversion-control-and-dependency-injection-in-spring)