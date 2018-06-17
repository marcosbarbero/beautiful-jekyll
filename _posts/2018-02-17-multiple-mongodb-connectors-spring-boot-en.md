---
layout: post
title: Multiple MongoDB connectors with Spring Boot
bigimg: /img/mongodb-leaf.jpeg
share-img: /img/mongodb-leaf.jpeg
gh-repo: weekly-drafts/spring-boot-multi-mongo
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-boot, spring-data, spring-data-mongodb, java, tutorial]
permalink: /multiple-mongodb-connectors-in-spring-boot/
lang: en
---

This tutorial will guide you in the process to connect to multiple [`MongoDBs`](https://www.mongodb.com/).

### What you will build
You will build an application that connects to multiple `MongoDBs`.

### Pre-req
  
  - [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
  - Text editor or your favorite IDE
  - [Maven 3.0+](https://maven.apache.org/download.cgi)
  - [MongoDB](https://www.mongodb.com/)

>The sample project uses [Project Lombok](https://projectlombok.org/) to generate getters, setters, contructors, etc.

### Spring Boot MongoDB connection
To create a `MongoTemplate` instance through Spring Boot we only need to provide Mongo Server details in Spring Boot specific property keys and Spring Boot on startup automatically creates a Mongo Connection with `MongoTemplate` wrapper and let's us auto wire wherever we want to use.

Below are the basic properties required for creating a `MongoTemplate`.

```yaml
spring:
  data.mongodb:
    host: # hostname
    port: # port
    uri: #uri
    database: #db
```

Spring Boot has a class called as `MongoProperties.java` which defines the mandatory property key prefix as `spring.data.mongodb` (can be seen in the above properties extract). The `MongoProperties.java` holds all the mongo properties that we wrote in the 
`application.yml`. Then there is another class called as `MongoDataAutoConfiguration.java` which uses the `MongoProperties.java` as its Properties Configuration Class and is responsible for actually creating the MongoTemplate through one of its factory methods.

To connect to two different mongo server it's required to override all these classes and their behaviors.

### Disabling Spring Boot AutoConfig
To be able to create multiple `MongoTemplate` objects it's necessary to disable the Spring Boot autoconfig for mongodb. It can
be achieved just by adding the following property in the `application.yml` file.

```yml
spring:
  autoconfigure:
    exclude: org.springframework.boot.autoconfigure.mongo.MongoAutoConfiguration
```

### Configuring multiple MongoTemplates
First of all create the following `@ConfigurationProperties` class.

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

And then add the following properties in the `application.yml`

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

Now it's necessary to create the `MongoTemplate`s to bind the given configuration in the previous step.

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

With the configuration above you'll be able to have two different `MongoTemplate`s based in the custom configuration properties
that we provided previously in this guide.

### Using multiple templates
In the previous step we created two `MongoTemplate`s, `primaryMongoTemplate` and `secondaryMongoTemplate`. In this section we'll
make some data model and make it all work together.

### Creating the data model and repositories

First we will create two data models to access different `collections`.

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

```java
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

Now we'll need to create one repository per data model.

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

### Enabling mongo repositories
Now we already have the properties configuration classes and data model classes, we need to configure which `MongoTemplate` will
be responsible for each defined `repository`.

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

### Running
To test the application I just added the following code to the main class in the project.

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

As this project was built using [Spring Boot](https://projects.spring.io/spring-boot/), to run it just execute the following commands:

`Build`
```bash
$ ./mvnw clean package
```

`Run`
```bash
$ java -jar target/multiple-mongo-connectors-0.0.1-SNAPSHOT.jar
```

The process prints the following output:

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
This guide requires a `MongoDB` instance up and running in `localhost` and `27017` port.

### Summary
Congratulations! You just created a spring-boot project that connects to multiple `MongoDB` instances.

#### Footnote
 - The code used for this tutorial can be found on [github](https://github.com/weekly-drafts/spring-boot-multi-mongo)