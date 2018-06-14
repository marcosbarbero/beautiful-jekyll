---
layout: post
title: Creating a batch service
bigimg: /img/path.jpg
gh-repo: weekly-drafts/batch-service
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-boot, spring-batch, batch, java, tutorial]
permalink: /creating-a-batch-service/
lang: en
---

This tutorial will guide you in the process to create a batch processing solution.

### What you will build
You will build a service that imports a CSV spreadsheet, transform it in a Java object and
stores in a SQL database.

### Pre-req
  
  - [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
  - Text editor or your favorite IDE
  - [Maven 3.0+](https://maven.apache.org/download.cgi)

### Processing data
For this tutorial I'm using the following spreadsheet:

`src/main/resources/sample-data.csv`

```csv
Optimus Prime,Freightliner FL86 COE Semi-trailer Truck
Sentinel Prime,Cybertronian Fire Truck
Bluestreak,Nissan 280ZX Turbo
Hound,Mitsubishi J59 Military Jeep
Ironhide,Nissan Vanette
Jazz,Martini Racing Porsche 935
Mirage,Ligier JS11 Racer
Prowl,Nissan 280ZX Police Car
Ratchet,Nissan C2 First Response
Sideswipe,Lamborghini Countach LP500-2
Sunstreaker,Supercharged Lamborghini Countach LP500S
Wheeljack,Lancia Stratos Turbo
Hoist,Toyota Hilux Tow Truck
Smokescreen,Nissan S130
Tracks,Chevrolet Corvette C3
Blurr,Cybertronian Hovercar
Hot Rod,Cybertronian Race Car
Kup,Cybertronian Pickup Truck
```

This spreadsheet contains the name of a [Autobot](https://ipfs.io/ipfs/QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco/wiki/List_of_Autobots.html) and the car that it transforms itself, comma delimited.
This is a very common pattern that [Spring Framework](https://spring.io/) handles.

The next step you'll write a SQL script with the schema definition to store the data.

`src/main/resources/schema-all.sql`

```sql
DROP TABLE autobot IF EXISTS;

CREATE TABLE autobot  (
    autobot_id BIGINT IDENTITY NOT NULL PRIMARY KEY,
    name VARCHAR(50),
    car VARCHAR(50)
);
```

{: .box-note}
Spring Boot automatically executes `schema-@@platform@@.sql` during its initialization. `-all` is the pattern for all the
platforms.

### Creating your business class
Now that we now the input and output format we will write a class that represents each data line.

`src/main/java/com/marcosbarbero/wd/batch/Autobot`

```java
public class Autobot {

    private String name;
    private String car;

    public Autobot() {
    }

    public Autobot(String name, String car) {
        this.name = name;
        this.car = car;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getCar() {
        return car;
    }

    public void setCar(String car) {
        this.car = car;
    }
}
```

You can instantiate the class `Autobot` using the constructor adding `name` and the `car`, otherwise using the setters.

### Creating a processor
A common paradigm in batch processing is data ingest, transform, and then store it somewhere. Here you will write a
simple transformer that converts the data to uppercase.

`src/main/java/com/marcosbarbero/wd/batch/AutobotItemProcessor`

```java
package com.marcosbarbero.wd.batch;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.item.ItemProcessor;

public class AutobotItemProcessor implements ItemProcessor<Autobot, Autobot> {

    private static final Logger log = LoggerFactory.getLogger(AutobotItemProcessor.class);

    @Override
    public Autobot process(Autobot autobot) throws Exception {
        final String firstName = autobot.getName().toUpperCase();
        final String lastName = autobot.getCar().toUpperCase();

        final Autobot transformed = new Autobot(firstName, lastName);

        log.info("Converting (" + autobot + ") into (" + transformed + ")");

        return transformed;
    }
}
```

`AutobotItemProcessor` implements interface `ItemProcessor` from Spring Batch. It makes easier to link the code to a batch process that we will define further in this tutorial. According to the interface, you receive an incoming `Autobot` object, after which you transform it to an upper-cased `Autobot`.
 
 {: .box-note}
There is no requirement that the input and output types be the same. In fact, after one source of data is read, sometimes the application’s data flow needs a different data type.

### Criando o processamento batch
Spring Batch provides many utility classes that reduce the need to write custom code. Instead, you can focus on the business logic.

`src/main/java/com/marcosbarbero/wd/batch/BatchConfiguration`

```java
package com.marcosbarbero.wd.batch;

import org.springframework.batch.core.Job;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.configuration.annotation.EnableBatchProcessing;
import org.springframework.batch.core.configuration.annotation.JobBuilderFactory;
import org.springframework.batch.core.configuration.annotation.StepBuilderFactory;
import org.springframework.batch.core.launch.support.RunIdIncrementer;
import org.springframework.batch.item.database.BeanPropertyItemSqlParameterSourceProvider;
import org.springframework.batch.item.database.JdbcBatchItemWriter;
import org.springframework.batch.item.file.FlatFileItemReader;
import org.springframework.batch.item.file.mapping.BeanWrapperFieldSetMapper;
import org.springframework.batch.item.file.mapping.DefaultLineMapper;
import org.springframework.batch.item.file.transform.DelimitedLineTokenizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import javax.sql.DataSource;

@Configuration
@EnableBatchProcessing
public class BatchConfiguration {

    private final JobBuilderFactory jobBuilderFactory;

    private final StepBuilderFactory stepBuilderFactory;

    private final DataSource dataSource;

    public BatchConfiguration(JobBuilderFactory jobBuilderFactory,
                              StepBuilderFactory stepBuilderFactory,
                              DataSource dataSource) {
        this.jobBuilderFactory = jobBuilderFactory;
        this.stepBuilderFactory = stepBuilderFactory;
        this.dataSource = dataSource;
    }

    // tag::readerwriterprocessor[]
    @Bean
    public FlatFileItemReader<Autobot> reader() {
        FlatFileItemReader<Autobot> reader = new FlatFileItemReader<>();
        reader.setResource(new ClassPathResource("sample-data.csv"));
        reader.setLineMapper(new DefaultLineMapper<Autobot>() {
            { 
                setLineTokenizer(new DelimitedLineTokenizer() {
                    { setNames(new String[]{"name", "car"}); }
                });
                setFieldSetMapper(new BeanWrapperFieldSetMapper<Autobot>() {
                    { setTargetType(Autobot.class); }
                });
            }
        });
        return reader;
    }

    @Bean
    public AutobotItemProcessor processor() {
        return new AutobotItemProcessor();
    }

    @Bean
    public JdbcBatchItemWriter<Autobot> writer() {
        JdbcBatchItemWriter<Autobot> writer = new JdbcBatchItemWriter<>();
        writer.setItemSqlParameterSourceProvider(new BeanPropertyItemSqlParameterSourceProvider<>());
        writer.setSql("INSERT INTO autobot (name, car) VALUES (:name, :car)");
        writer.setDataSource(this.dataSource);
        return writer;
    }
    // end::readerwriterprocessor[]

    // tag::jobstep[]
    @Bean
    public Job importAutobotJob(JobCompletionNotificationListener listener) {
        return jobBuilderFactory.get("importAutobotJob")
                .incrementer(new RunIdIncrementer())
                .listener(listener)
                .flow(step1())
                .end()
                .build();
    }

    @Bean
    public Step step1() {
        return stepBuilderFactory.get("step1")
                .<Autobot, Autobot>chunk(10)
                .reader(reader())
                .processor(processor())
                .writer(writer())
                .build();
    }
    // end::jobstep[]
}
```

{: .box-note}
The @EnableBatchProcessing annotation adds many critical beans that support jobs and saves you a lot of leg work. This example uses a memory-based database (provided by @EnableBatchProcessing), meaning that when it’s done, the data is gone.

Step by step:

`src/main/java/com/marcosbarbero/wd/batch/BatchConfiguration`

```java
    @Bean
    public FlatFileItemReader<Autobot> reader() {
        FlatFileItemReader<Autobot> reader = new FlatFileItemReader<>();
        reader.setResource(new ClassPathResource("sample-data.csv"));
        reader.setLineMapper(new DefaultLineMapper<Autobot>() {
            {
            setLineTokenizer(new DelimitedLineTokenizer() {
                {
                setNames(new String[]{"name", "car"});
                }
            });
            setFieldSetMapper(new BeanWrapperFieldSetMapper<Autobot>() {
                {
                setTargetType(Autobot.class);
                }
            });
            }
        });
        return reader;
    }

    @Bean
    public AutobotItemProcessor processor() {
        return new AutobotItemProcessor();
    }

    @Bean
    public JdbcBatchItemWriter<Autobot> writer() {
        JdbcBatchItemWriter<Autobot> writer = new JdbcBatchItemWriter<>();
        writer.setItemSqlParameterSourceProvider(new BeanPropertyItemSqlParameterSourceProvider<>());
        writer.setSql("INSERT INTO autobot (name, car) VALUES (:name, :car)");
        writer.setDataSource(this.dataSource);
        return writer;
    }
```

The first chunk of code defines the input, processor, and output. - `reader()` creates an `ItemReader`. It looks for a file called `sample-data.csv` and parses each line item with enough information to turn it into a `Autobot` - `processor()` creates an instance of our`AutobotItemProcessor` that was defined earlier, meant to uppercase the data. - `write(DataSource)` creates
an `ItemWriter`.

The next chunk focuses on the actual job configuration.


`src/main/java/com/marcosbarbero/wd/batch/BatchConfiguration`

```java
    @Bean
    public Job importAutobotJob(JobCompletionNotificationListener listener) {
        return jobBuilderFactory.get("importAutobotJob")
                .incrementer(new RunIdIncrementer())
                .listener(listener)
                .flow(step1())
                .end()
                .build();
    }

    @Bean
    public Step step1() {
        return stepBuilderFactory.get("step1")
                .<Autobot, Autobot>chunk(10)
                .reader(reader())
                .processor(processor())
                .writer(writer())
                .build();
    }
```

The first method defines the job and the second one defines a single step. Jobs are built from steps, where each step can involve a `reader`, a `processor`, and a `writer`.

In this job definition, you need an `incrementer` because jobs use a database to maintain execution state. You then list each step, of which this job has only one step. The job ends, and the Java API produces a perfectly configured job.

In the step definition, you define how much data to write at a time. In this case, it writes up to ten records at a time. Next, you configure the `reader`, `processor`, and `writer` using the injected bits from earlier.


{: .box-note}
`chunk()` is prefixed <Autobot, Autobot> because its a generic method. This represents the input and output types for each "chunk" of processing,  and lines up with `ItemReader<Autobot>` and `ItemWriter<Autobot>`.

`src/main/java/com/marcosbarbero/wd/batch/JobCompletionNotificationListener`

```java
package com.marcosbarbero.wd.batch;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.BatchStatus;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.listener.JobExecutionListenerSupport;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class JobCompletionNotificationListener extends JobExecutionListenerSupport {

    private static final Logger log = LoggerFactory.getLogger(JobCompletionNotificationListener.class);

    private final JdbcTemplate jdbcTemplate;

    public JobCompletionNotificationListener(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void afterJob(JobExecution jobExecution) {
        if (jobExecution.getStatus() == BatchStatus.COMPLETED) {
            log.info("!!! JOB FINISHED! Time to verify the results");

            List<Autobot> results = this.jdbcTemplate.query("SELECT name, car FROM autobot",
                    (rs, row) -> new Autobot(rs.getString(1), rs.getString(2)));

            for (Autobot autobot : results) {
                log.info("Found <" + autobot.toString() + "> in the database.");
            }

        }
    }
}
```	


This code listens for when the job has its status as `BatchStatus.COMPLETED`, and then uses `JdbcTemplate` to verify the results.

### Running
This project was built using [Spring Boot](https://projects.spring.io/spring-boot/), to run it just execute the following commands:

`Build`
```bash
$ ./mvnw clean package
```

`Run`
```bash
$ java -jar target/batch-service-0.0.1-SNAPSHOT.jar
```

The process prints one line for each autobot that was tranformed.

```bash
Converting (Autobot{name='Optimus Prime', car='Freightliner FL86 COE Semi-trailer Truck'}) into (Autobot{name='OPTIMUS PRIME', car='FREIGHTLINER FL86 COE SEMI-TRAILER TRUCK'})
Converting (Autobot{name='Sentinel Prime', car='Cybertronian Fire Truck'}) into (Autobot{name='SENTINEL PRIME', car='CYBERTRONIAN FIRE TRUCK'})
Converting (Autobot{name='Bluestreak', car='Nissan 280ZX Turbo'}) into (Autobot{name='BLUESTREAK', car='NISSAN 280ZX TURBO'})
Converting (Autobot{name='Hound', car='Mitsubishi J59 Military Jeep'}) into (Autobot{name='HOUND', car='MITSUBISHI J59 MILITARY JEEP'})
Converting (Autobot{name='Ironhide', car='Nissan Vanette'}) into (Autobot{name='IRONHIDE', car='NISSAN VANETTE'})
Converting (Autobot{name='Jazz', car='Martini Racing Porsche 935'}) into (Autobot{name='JAZZ', car='MARTINI RACING PORSCHE 935'})
Converting (Autobot{name='Wheeljack', car='Lancia Stratos Turbo'}) into (Autobot{name='WHEELJACK', car='LANCIA STRATOS TURBO'})
Converting (Autobot{name='Hoist', car='Toyota Hilux Tow Truck'}) into (Autobot{name='HOIST', car='TOYOTA HILUX TOW TRUCK'})

Found <Autobot{name='OPTIMUS PRIME', car='FREIGHTLINER FL86 COE SEMI-TRAILER TRUCK'}> in the database.
Found <Autobot{name='SENTINEL PRIME', car='CYBERTRONIAN FIRE TRUCK'}> in the database.
Found <Autobot{name='BLUESTREAK', car='NISSAN 280ZX TURBO'}> in the database.
Found <Autobot{name='HOUND', car='MITSUBISHI J59 MILITARY JEEP'}> in the database.
Found <Autobot{name='IRONHIDE', car='NISSAN VANETTE'}> in the database.
Found <Autobot{name='JAZZ', car='MARTINI RACING PORSCHE 935'}> in the database.
Found <Autobot{name='MIRAGE', car='LIGIER JS11 RACER'}> in the database.
Found <Autobot{name='PROWL', car='NISSAN 280ZX POLICE CAR'}> in the database.
```

{: .box-note}
The data above is just a snapshot from the real result just to facilitate the read.

### Summary
Congratulations! You just created a batch process that `read`, `transform` and `write` the data in a database.

#### Footnote
 - This tutorial was created based in the following link: [Creating a Batch Service](https://spring.io/guides/gs/batch-processing/)
 - The code used for this tutorial can be found on [github](https://github.com/weekly-drafts/batch-service)