---
layout: post
title: Configurando mutiplos DataSources com Spring Boot e Spring Data - PCF
bigimg: /img/cloud-lamp-bulb.jpg
gh-repo: weekly-drafts/pcf-spring-boot-multiple-datasources
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-boot, spring-data, pcf, java, pivotal, cloud, cloud-foundry, tutorial]
permalink: /setup-multiple-datasources-with-spring-boot-spring-data-in-pcf/
lang: pt_BR
---

Esse tutorial te guiará no processo de configurar Spring Data para acessar múltiplos serviços SQL
na PCF.

### O que você irá construir
Você construirá uma aplicação que conecta com vários serviços MySQL na PCF.

### Pre-req

  - [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
  - Editor de texto ou sua IDE favorita
  - [Maven 3.0+](https://maven.apache.org/download.cgi)
  - [PCF](https://pivotal.io/pcf-dev)

>Nesse tutorial eu estou usando a instalação [PCF Dev](https://pivotal.io/pcf-dev).

### Spring Boot com Spring Data

[Spring Boot](https://projects.spring.io/spring-boot/) com 
[Spring Data](http://projects.spring.io/spring-data/)
torna fácil acessar bancos de dados através de [Repositórios](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#repositories) e [Spring Boot auto-configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-auto-configuration.html). Entretando, if a tua aplicação precisa acessar multiplos bancos de dados, isso não é algo
provido pelas auto-configurações.  

### PCF Services

PCF oferece um [marketplace de serviços](http://docs.pivotal.io/pivotalcf/1-12/devguide/services/) que são
provisionados por demanda. Para conectar uma `aplicação spring` em um serviço PCF existe
[Spring Cloud Connectors](https://cloud.spring.io/spring-cloud-connectors/) no qual usa os chamados
[Auto-Reconfiguration](https://docs.run.pivotal.io/buildpacks/java/configuring-service-connections/spring-service-bindings.html#auto-reconfiguration). Entretando, o `Auto-Reconfiguration` não funciona no caso em que
você tem que conectar com vários serviços do mesmo tipo, por exemplo, vários serviços de banco de dados SQL. E para isso
existe a necessidade de fazer uma [configuração manual](https://docs.run.pivotal.io/buildpacks/java/configuring-service-connections/spring-service-bindings.html#manual-configuration).

### Configurando vários DataSources

Para conectar com multiplos `DataSources` na `PCF` nós precisaremos usar a 
[Configuração Manual](https://docs.run.pivotal.io/buildpacks/java/configuring-service-connections/spring-service-bindings.html#manual-configuration).

Primeiro adicione a seguinte dependencia ao `pom.xml`.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-cloud-connectors</artifactId>
</dependency>
```

#### Configuração Java

Para conectar com vários DataSources nós precisamos criar uma nova classe que `extends` a `AbstractCloudConfig` 
do `Spring Cloud Connectors` e então criar dois `@Bean`s, um para cada `serviço PCF`.

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

Crie um pacote java para cada `DataSource`, com dois pacotes internos: `domain` e `repository`

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

#### Classes de configuração por Banco de dados

Como nós temos dois `DataSource`s, é necessário ter uma classe de configuração por conexão. No nosso exemplo serão duas
classes de configuração.

Para a primeira conexão com banco de dados crie a seguinte classe.

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

Para a segunda conexão com banco de dados, crie a seguinte classe.

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
Para esse tutorial eu estou usando a propriedade `hibernate.hbm2ddl.auto=create-drop` somente para deixar as coisas
mais fáceis, numa aplicação real esse valor não deve ser usado e deve-se usar algum método ou framework mais apropriado
para inicialização dos dados e `schemas` dos banco de dados.

#### Modelo e Repositórios

Agora é hora de criar as classes `model` e `repository` que farão conexão com cada class de configuração descrita acima.

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

### Executando

Para testar a aplicação eu adicionei o seguinte código na classe principal do projeto.

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

Para fazer o deploy da aplicação na PCF eu estou usando um arquivo `manifest.yml`.

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
Para esse exemplo eu criei dois serviços `p-mysql` chamados `first-db` e `second-db`.

`Build`
```bash
$ ./mvnw clean package
```

`Deploy`
```bash
$ cf push
```

Quando terminar o deploy da aplicação, ela irá imprimir a seguinte saída:

```bash
First{id=1, text='first database'}
Second{id=1, text='second database'}
```

### Summary
Parabéns! Você criou uma aplicação Spring Boot que conecta com vários bancos de dados na PCF usando Spring Data.

### Nota de rodapé
  - O código desse tutorial pode ser encontrado no [github](https://github.com/weekly-drafts/pcf-spring-boot-multiple-datasources)