---
layout: post
title: Conectando multiplos MongoDBs usando Spring Boot
bigimg: /img/mongodb-leaf.jpeg
gh-repo: weekly-drafts/spring-boot-multi-mongo
gh-badge: [star, fork, follow]
tags: [spring, spring-framework, spring-boot, spring-data, spring-data-mongodb, java]
permalink: /multiple-mongodb-connectors-in-spring-boot/
lang: pt_BR
---

Esse tutorial te guiará no processo de conectar uma aplicação com multiplos [`MongoDBs`](https://www.mongodb.com/).

### O que você construirá
Você construirá uma aplicação que se conecta à multiplos `MongoDB`s.

### Pre-req
  
  - [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
  - Editor de texto ou sua IDE favorita
  - [Maven 3.0+](https://maven.apache.org/download.cgi)
  - [MongoDB](https://www.mongodb.com/)

>O projeto de examplo usa [Project Lombok](https://projectlombok.org/) para gerar getters, setters, contructors, etc.

### Spring Boot - Conexão com MongoDB
Para criar uma instância do `MongoTemplate`através do Spring Boot nós só precisamos adicionar algumas propriedades específicas
que o `AutoConfiguration` do Spring Boot se encarregará de criar tudo automaticamente.

Abaixo estão as propriedades básicas obrigatórias para criação de um `MongoTemplate`.

```yaml
spring:
  data.mongodb:
    host: # hostname
    port: # port
    uri: #uri
    database: #db
```

Spring Boot tem uma class chamada `MongoProperties.java` que define os campos obrigatórios com o prefixo `spring.data.mongodb`. (acima). A classe `MongoProperties.java` armazena todas as propriedades que nós escrevemos no `application.yml`. Então, exist outra classe chamada `MongoDataAutoConfiguration.java` que usa a anterior para criar um `MongoTemplate`.

Para conectar em dois diferentes servidores de `MongoDB` é necessário sobreescrever todas essas classes e comportamento.

### Desligando Spring Boot AutoConfig
Para criar multiplos `MongoTemplate`s é necessário desabilitar a auto-configuração provida pelo Spring Boot. Isso pode ser
conseguido adicionando a seguinte propriedade no arquivo `application.yml`.

```yml
spring:
  autoconfigure:
    exclude: org.springframework.boot.autoconfigure.mongo.MongoAutoConfiguration
```

### Configurando multiplos MongoTemplates
Primeiro crie a seguinte `@ConfigurationProperties` classe.

`src/main/java/com/marcosbarbero/wd/multiplemongo/config/MultipleMongoProperties`

```java
import org.springframework.boot.autoconfigure.mongo.MongoProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;

import lombok.Data;

@Data
@ConfigurationProperties(prefix = "mongodb")
public class MultipleMongoProperties {

    private MongoProperties primary = new MongoProperties();
    private MongoProperties secondary = new MongoProperties();
}
```

E então adicione as seguintes propriedades no `application.yml`

```yaml
mongodb:
  primary:
    host: localhost
    port: 27017
    database: second
  secondary:
    host: localhost
    port: 27017
    database: second
```

Agora é necessário criar o `MongoTemplate`s para ligar as configurações dadas no passo anterior.

`src/main/java/com/marcosbarbero/wd/multiplemongo/config/MultipleMongoConfig`

```java
package com.marcosbarbero.wd.multiplemongo.config;

import com.mongodb.MongoClient;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.mongo.MongoProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.mongodb.MongoDbFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.SimpleMongoDbFactory;

import lombok.RequiredArgsConstructor;

@Configuration
@RequiredArgsConstructor
@EnableConfigurationProperties(MultipleMongoProperties.class)
public class MultipleMongoConfig {

    private final MultipleMongoProperties mongoProperties;

    @Primary
    @Bean(name = "primaryMongoTemplate")
    public MongoTemplate primaryMongoTemplate() throws Exception {
        return new MongoTemplate(primaryFactory(this.mongoProperties.getPrimary()));
    }

    @Bean(name = "secondaryMongoTemplate")
    public MongoTemplate secondaryMongoTemplate() throws Exception {
        return new MongoTemplate(secondaryFactory(this.mongoProperties.getSecondary()));
    }

    @Bean
    @Primary
    public MongoDbFactory primaryFactory(final MongoProperties mongo) throws Exception {
        return new SimpleMongoDbFactory(new MongoClient(mongo.getHost(), mongo.getPort()),
                mongo.getDatabase());
    }

    @Bean
    public MongoDbFactory secondaryFactory(final MongoProperties mongo) throws Exception {
        return new SimpleMongoDbFactory(new MongoClient(mongo.getHost(), mongo.getPort()),
                mongo.getDatabase());
    }

}
```

Com a configuração acima você terá dois diferentes `MongoTemplate`s baseados nas configurações personalizadas que criamos
anteriormente.

### Usando multiplos templates
No passo anterior nós criamos dois `MongoTemplate`s, `primaryMongoTemplate` e `secondaryMongoTemplate`. Nessa sessão nós
criaremos alguns modelos de dados e faremos tudo funcionar.

### Creating the data model and repositories
Primeiro nós precisamos criar dois modelos de dados para acessar duas `collections` diferentes.

`src/main/java/com/marcosbarbero/wd/multiplemongo/repository/primary/PrimaryModel`

```java
package com.marcosbarbero.wd.multiplemongo.repository.primary;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Document(collection = "first_mongo")
public class PrimaryModel {

	@Id
	private String id;

	private String value;

	@Override
	public String toString() {
        return "PrimaryModel{" + "id='" + id + '\'' + ", value='" + value + '\''
				+ '}';
	}
}
```

`src/main/java/com/marcosbarbero/wd/multiplemongo/repository/secondary/SecondaryModel`

```
package com.marcosbarbero.wd.multiplemongo.repository.secondary;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Document(collection = "second_mongo")
public class SecondaryModel {

    @Id
    private String id;

    private String value;

    @Override
    public String toString() {
        return "SecondaryModel{" + "id='" + id + '\'' + ", value='" + value + '\''
                + '}';
    }
}

```

Agora nós precisamos criar um repositório par cada modelo de dados.

`src/main/java/com/marcosbarbero/wd/multiplemongo/repository/primary/PrimaryRepository`

```java
package com.marcosbarbero.wd.multiplemongo.repository.primary;

import org.springframework.data.mongodb.repository.MongoRepository;

public interface PrimaryRepository extends MongoRepository<PrimaryModel, String> {

}
```

`src/main/java/com/marcosbarbero/wd/multiplemongo/repository/secondary/SecondaryRepository`

```java
package com.marcosbarbero.wd.multiplemongo.repository.secondary;

import org.springframework.data.mongodb.repository.MongoRepository;

public interface SecondaryRepository extends MongoRepository<SecondaryModel, String> {

}
```

### Habilitando os repositórios Mongo
Agora nós já temos as classes para configuração das propriedades e os modelos de dados, nós precisamos configurar qual
`MongoTemplate` será responsável para cada `repository` definido.

`src/main/java/com/marcosbarbero/wd/multiplemongo/config/PrimaryMongoConfig`

```java
package com.marcosbarbero.wd.multiplemongo.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories;

@Configuration
@EnableMongoRepositories(basePackages = "com.marcosbarbero.wd.multiplemongo.repository.primary",
        mongoTemplateRef = "primaryMongoTemplate")
public class PrimaryMongoConfig {

}

```

`src/main/java/com/marcosbarbero/wd/multiplemongo/config/SecondaryMongoConfig`

```java
package com.marcosbarbero.wd.multiplemongo.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories;

@Configuration
@EnableMongoRepositories(basePackages = "com.marcosbarbero.wd.multiplemongo.repository.secondary",
        mongoTemplateRef = "secondaryMongoTemplate")
public class SecondaryMongoConfig {

}
```

### Executando
Para testar a aplicação eu adicionei o seguinte código na classe principal do projeto.

`src/main/java/com/marcosbarbero/wd/multiplemongo/Application`

```java
package com.marcosbarbero.wd.multiplemongo;

import com.marcosbarbero.wd.multiplemongo.repository.primary.PrimaryModel;
import com.marcosbarbero.wd.multiplemongo.repository.primary.PrimaryRepository;
import com.marcosbarbero.wd.multiplemongo.repository.secondary.SecondaryModel;
import com.marcosbarbero.wd.multiplemongo.repository.secondary.SecondaryRepository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import java.util.List;

import lombok.extern.slf4j.Slf4j;

@Slf4j
@SpringBootApplication
public class Application implements CommandLineRunner {

    @Autowired
    private PrimaryRepository primaryRepository;

    @Autowired
    private SecondaryRepository secondaryRepository;

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }

    @Override
    public void run(String... args) throws Exception {
        log.info("************************************************************");
        log.info("Start printing mongo objects");
        log.info("************************************************************");
        this.primaryRepository.save(new PrimaryModel(null, "Primary database plain object"));

        this.secondaryRepository.save(new SecondaryModel(null, "Secondary database plain object"));

        List<PrimaryModel> primaries = this.primaryRepository.findAll();
        for (PrimaryModel primary : primaries) {
            log.info(primary.toString());
        }

        List<SecondaryModel> secondaries = this.secondaryRepository.findAll();

        for (SecondaryModel secondary : secondaries) {
            log.info(secondary.toString());
        }

        log.info("************************************************************");
        log.info("Ended printing mongo objects");
        log.info("************************************************************");

    }
}
```

Como esse projeto foi construído usando [Spring Boot](https://projects.spring.io/spring-boot/), para executá-lo basta apenas
executar os seguintes comandos:

`Build`
```bash
$ ./mvnw clean package
```

`Run`
```bash
$ java -jar target/multiple-mongo-connectors-0.0.1-SNAPSHOT.jar
```

O processo imprimá a seguinte saída:

```bash
************************************************************
Start printing mongo objects
************************************************************
Opened connection [connectionId{localValue:3, serverValue:11}] to localhost:27017
Opened connection [connectionId{localValue:4, serverValue:12}] to localhost:27017
PrimaryModel{id='5a8834ee536b1d604345da4e', value='Primary database plain object'}
SecondaryModel{id='5a884cc8536b1da4468466a7', value='Secondary database plain object'}
************************************************************
Ended printing mongo objects
************************************************************
```

{: .box-note}
Para executar esse tutorial é necessário uma instancias de `MongoDB` rodando em `localhost` e na porta `27017`.

### Sumário
Parabéns! Você acabou de criar uma aplicação com spring-boot que conecta à múltiplas instâncias de `MongoDB`.

#### Nota de rodapé
 - O código usado para esse tutorial pode ser encontrado no [github](https://github.com/weekly-drafts/spring-boot-multi-mongo)