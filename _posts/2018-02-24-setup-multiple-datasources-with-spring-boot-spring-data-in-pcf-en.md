---
layout: post
title: Setup multiple DataSources with Spring Boot and Spring Data in PCF
bigimg: /img/cloud-lamp-bulb.jpg
share-img: /img/cloud-lamp-bulb.jpg
gh-repo: weekly-drafts/pcf-spring-boot-multiple-datasources
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-boot, spring-data, pcf, java, pivotal, cloud, cloud-foundry, tutorial]
permalink: /setup-multiple-datasources-with-spring-boot-spring-data-in-pcf/
lang: en
---

This tutorial will guide you in the process to setup Spring Data to access `multiple SQL` services
in `PCF`.

### What you will build
You will build an application that connects to multiple MySQL services in PCF.

### Pre-req

  - [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
  - Text editor or your favorite IDE
  - [Maven 3.0+](https://maven.apache.org/download.cgi)
  - [PCF](https://pivotal.io/pcf-dev)

>For this guide I'm using a [PCF Dev](https://pivotal.io/pcf-dev) installation.

### Spring Boot with Spring Data

[Spring Boot](https://projects.spring.io/spring-boot/) with 
[Spring Data](http://projects.spring.io/spring-data/)
makes it easy to access a database through [Repositories](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#repositories) and [Spring Boot auto-configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-auto-configuration.html). However, if your application needs to access multiple `DataSources` it's not something provided out of the box.  

### PCF Services

PCF offers a [marketplace of services](http://docs.pivotal.io/pivotalcf/1-12/devguide/services/) to be 
provisioned on-demand. To connect a `spring application` to the PCF services there's 
[Spring Cloud Connectors](https://cloud.spring.io/spring-cloud-connectors/) in which makes so called 
[Auto-Reconfiguration](https://docs.run.pivotal.io/buildpacks/java/configuring-service-connections/spring-service-bindings.html#auto-reconfiguration). However, the `Auto-Reconfiguration` doesn't work in
case you have multiple services of the same type e.g. multiple SQL database services and for that there's a 
need to make a [manual configuration](https://docs.run.pivotal.io/buildpacks/java/configuring-service-connections/spring-service-bindings.html#manual-configuration).

### Configuring multiple DataSources

To connect to multiple `DataSources` in PCF we'll need to use the [Manual Configuration](https://docs.run.pivotal.io/buildpacks/java/configuring-service-connections/spring-service-bindings.html#manual-configuration)
approach. 

First add the following dependency in the `pom.xml`.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-cloud-connectors</artifactId>
</dependency>
```

#### Java Configuration

To connect to multiple DataSources we need to create a new class extending the `AbstractCloudConfig` provided by
`Spring Cloud Connectors` and then add two service `@Bean`s.

`src/main/java/com/marcosbarbero/wd/pcf/multidatasources/config`

```java
import org.springframework.cloud.config.java.AbstractCloudConfig;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;

@Configuration
public class CloudConfig extends AbstractCloudConfig {

    @Primary
    @Bean(name = "first-db")
    public DataSource firstDataSource() {
        return connectionFactory().dataSource("first-db");
    }

    @Bean(name = "second-db")
    public DataSource secondDataSource() {
        return connectionFactory().dataSource("second-db");
    }
}
```

#### Java package

Create a Java package for each `DataSource` with two nested packages: `domain` and `repository`

```bash
── com
    └── marcosbarbero
        └── wd
            └── pcf
                └── multidatasources
                    ├── first
                    │   ├── domain
                    │   └── repository
                    └── second
                        ├── domain
                        └── repository
```

#### Configuration classes per Database

As we have two `DataSource`s, it's needed to have a configuration class per database connection, in our example it will be
two configuration classes.  

For the first database connection create the following class.

`src/main/java/com/marcosbarbero/wd/pcf/multidatasources/config`

```java
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.orm.jpa.EntityManagerFactoryBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import javax.persistence.EntityManagerFactory;
import javax.sql.DataSource;

import static java.util.Collections.singletonMap;

@Configuration
@EnableJpaRepositories(
        entityManagerFactoryRef = "firstEntityManagerFactory",
        transactionManagerRef = "firstTransactionManager",
        basePackages = "com.marcosbarbero.wd.pcf.multidatasources.first.repository"
)
@EnableTransactionManagement
public class FirstDsConfig {

    @Primary
    @Bean(name = "firstEntityManagerFactory")
    public LocalContainerEntityManagerFactoryBean firstEntityManagerFactory(final EntityManagerFactoryBuilder builder,
                                                                            final @Qualifier("first-db") DataSource dataSource) {
        return builder
                .dataSource(dataSource)
                .packages("com.marcosbarbero.wd.pcf.multidatasources.first.domain")
                .persistenceUnit("firstDb")
                .properties(singletonMap("hibernate.hbm2ddl.auto", "create-drop"))
                .build();
    }

    @Primary
    @Bean(name = "firstTransactionManager")
    public PlatformTransactionManager firstTransactionManager(@Qualifier("firstEntityManagerFactory")
                                                              EntityManagerFactory firstEntityManagerFactory) {
        return new JpaTransactionManager(firstEntityManagerFactory);
    }
}
```

For the second database connection create the following class.

`src/main/java/com/marcosbarbero/wd/pcf/multidatasources/config`

```java
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.orm.jpa.EntityManagerFactoryBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import javax.persistence.EntityManagerFactory;
import javax.sql.DataSource;

import static java.util.Collections.singletonMap;

@Configuration
@EnableJpaRepositories(
        entityManagerFactoryRef = "secondEntityManagerFactory",
        transactionManagerRef = "secondTransactionManager",
        basePackages = "com.marcosbarbero.wd.pcf.multidatasources.second.repository"
)
@EnableTransactionManagement
public class SecondDsConfig {

    @Bean(name = "secondEntityManagerFactory")
    public LocalContainerEntityManagerFactoryBean secondEntityManagerFactory(final EntityManagerFactoryBuilder builder,
                                                                             final @Qualifier("second-db") DataSource dataSource) {
        return builder
                .dataSource(dataSource)
                .packages("com.marcosbarbero.wd.pcf.multidatasources.second.domain")
                .persistenceUnit("secondDb")
                .properties(singletonMap("hibernate.hbm2ddl.auto", "create-drop"))
                .build();
    }

    @Bean(name = "secondTransactionManager")
    public PlatformTransactionManager secondTransactionManager(@Qualifier("secondEntityManagerFactory")
                                                               EntityManagerFactory secondEntityManagerFactory) {
        return new JpaTransactionManager(secondEntityManagerFactory);
    }
}
```

{: .box-note}
For this tutorial I'm using the property value `hibernate.hbm2ddl.auto=create-drop` just to make it easier, in a production
application it may not have this value and should have a proper way to initialize the database schemas using a proper framework
for it.  

#### Model and Repositories

Now it's time to create the `model` and `repository` class that will be connected to each configuration class described above.

`src/main/java/com/marcosbarbero/wd/pcf/multidatasources/first/domain`

```java
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "first")
public class First {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String text;

    public First(String text) {
        this.text = text;
    }

    public First() {
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    @Override
    public String toString() {
        return "First{" +
                "id=" + id +
                ", text='" + text + '\'' +
                '}';
    }
}
```

`src/main/java/com/marcosbarbero/wd/pcf/multidatasources/first/repository`

```java
import com.marcosbarbero.wd.pcf.multidatasources.first.domain.First;

import org.springframework.data.jpa.repository.JpaRepository;

public interface FirstRepository extends JpaRepository<First, Long> {
}
```

`src/main/java/com/marcosbarbero/wd/pcf/multidatasources/second/domain`

```java
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "second")
public class Second {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String text;

    public Second(String text) {
        this.text = text;
    }

    public Second() {
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    @Override
    public String toString() {
        return "Second{" +
                "id=" + id +
                ", text='" + text + '\'' +
                '}';
    }
}
```

`src/main/java/com/marcosbarbero/wd/pcf/multidatasources/second/repository`

```java
import com.marcosbarbero.wd.pcf.multidatasources.second.domain.Second;

import org.springframework.data.jpa.repository.JpaRepository;

public interface SecondRepository extends JpaRepository<Second, Long> {
}
```

### Running

To test the application I just added the following code to the main class in the project.

`src/main/java/com/marcosbarbero/wd/pcf/multidatasources`

```java
import com.marcosbarbero.wd.pcf.multidatasources.first.domain.First;
import com.marcosbarbero.wd.pcf.multidatasources.first.repository.FirstRepository;
import com.marcosbarbero.wd.pcf.multidatasources.second.domain.Second;
import com.marcosbarbero.wd.pcf.multidatasources.second.repository.SecondRepository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application implements CommandLineRunner {

    private static final Logger logger = LoggerFactory.getLogger(Application.class);

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }

    @Autowired
    private FirstRepository firstRepository;

    @Autowired
    private SecondRepository secondRepository;

    @Override
    public void run(String... args) throws Exception {
        First firstSaved = this.firstRepository.save(new First("first database"));
        Second secondSaved = this.secondRepository.save(new Second("second database"));

        logger.info(firstSaved.toString());
        logger.info(secondSaved.toString());
    }
}
```

### Deploying to PCF

To deploy this application to PCF I'm using the `manifest.yml` file approach.

```yaml
applications:
- name: multiple-db
  memory: 512MB
  instance: 1
  path: ./target/your-jar-name.jar
  services:
   - first-db
   - second-db
```

{: .box-note}
For this sample I've created in PCF two `p-mysql` instances named `first-db` and `second-db`.

`Build`
```bash
$ ./mvnw clean package
```

`Deploy`
```bash
$ cf push
```

When the application is deployed it will print the following output:

```bash
First{id=1, text='first database'}
Second{id=1, text='second database'}
```

### Summary
Congratulations! You just created a Spring Boot application that connects to multiple Database 
instances in `PCF` using Spring Data.

### Footnote
  - The code used for this tutorial can be found on [github](https://github.com/weekly-drafts/pcf-spring-boot-multiple-datasources)