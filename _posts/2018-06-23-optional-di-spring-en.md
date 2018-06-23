---
layout: post
title: Optional Dependency Injection with Spring
gh-repo: weekly-drafts/spring-optional-dependency-injection
gh-badge: [star, fork, follow]
tags: [spring-framework, di, java, tutorial]
permalink: /optional-di-with-spring/
lang: en
---

This guide walks through the options available to inject `optional` dependencies with 
[Spring DI](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-spring-beans-and-dependency-injection.html).

### Introduction

There are quite few use-cases where it's needed to make optional some of the dependencies injected, here are some of them:

 * Provide a default implementation whenever a required infrastructure dependency is not provided, such as `DataSource`s.
 * Prevent the usage of dependencies such as monitoring strategies depending on the `environment`.
 * If you are building your [spring-boot own auto-configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/boot-features-developing-auto-configuration.html) component, sometimes it's necessary to have optional dependencies.

### @Autowired

The most know approach to achieve the `optional` injection is simply to use the `@Autowired(required = false)`, 
something like this:

```java
@Autowired(required = false)
private HelloService helloService;
```

It works fine and gets us to where we wanted, however, I don't recommend anyone to use field injection and one 
of the reasons for that is the `test` layer of the application. Whenever field injection is used it's mandatory
to use `reflaction` to inject a different implementation based on the `test case`.

### Java 8 Optional type

You may be familiar with Java 8's `Optional` type, it can also be used while injecting dependencies with Spring,
here a sample:

```java
@RestController
public class HelloController {

    private Optional<HelloService> optionalHelloService;

    public HelloController(Optional<HelloService> helloService) {
        this.optionalHelloService = helloService;
    }

    @GetMapping("/hello")
    public String hello() {
        if (optionalHelloService.isPresent()) {
            return optionalHelloService.get().hello();
        }
       return "default hello message";
    }

}
```

The implementation above gives you an `Optional` monad where you can validate whether the implementention is present
before using it.

### Spring's ObjectProvider

Since Spring 4.3 there's this class named [ObjectProvider](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/beans/factory/ObjectProvider.html)
designed specifically for injection points.

From the javadocs:

>A variant of {@link ObjectFactory} designed specifically for injection points, allowing for programmatic optionality and lenient not-unique handling.

Using the same example from above:

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

In this example, it's not only optional but also it provides an default implementation as fallback.

### Summary
Congratulations! You just learned few ways to optionally inject dependencies within Spring apps.

### Footnote
  - The code used for this tutorial can be found on [GitHub](https://github.com/weekly-drafts/spring-optional-dependency-injection)
  - More about [IoC and DI](http://www.baeldung.com/inversion-control-and-dependency-injection-in-spring)