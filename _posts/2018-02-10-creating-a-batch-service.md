---
layout: post
title: Criando um serviço batch
bigimg: /img/path.jpg
gh-repo: weekly-drafts/batch-service
gh-badge: [star, fork, follow]
tags: [spring, spring-framework, spring-boot, spring-batch, batch, java]
---

Esse tutorial te guiará no processo de criação de uma solução de processamento batch.

### O que você irá criar
Você irá construir um serviço que importa os dados de uma planilha CSV, transforma em um objeto java e
armazena em um banco de dados SQL.

### Pré-requisitos
  
  - [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
  - Editor de texto ou tua IDE favorita.
  - [Maven 3.0+](https://maven.apache.org/download.cgi)

### Dados para o processamento
Para esse tutorial estou usando a seguinte planilha:  

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

Essa planilha contém o nome do [Autobot](https://ipfs.io/ipfs/QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco/wiki/List_of_Autobots.html) e o carro em que ele se transforma, separados por vírgula.
Este é um padrão muito comum que o [Spring Framework](https://spring.io/) consegue lidar, como você poderá ver.

O próximo passo é escrever um script SQL para armazenar os dados.

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
Spring Boot executa `schema-@@platform@@.sql` automaticamente durante a inicialização. `-all` é o padrão para todas as plataformas.

### Criando a classe de negócio
Agora que sabemos o formato de entrada e saída, escreveremos uma classe que represente cada linha de dados.

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

Você pode instanciar a classe `Autobot` através do construtor adicionando nome e o carro, ou então usando os setters.

### Criando um processador 
Um paradigma comum no processamento batch é ingerir os dados, transformá-los, e então armazená-los em algum lugar. Aqui você
escreverá um simples transformador que converte os nomes e carros para maiúsculo.

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

`AutobotItemProcessor` implementa a interface `ItemProcessor` do Spring Batch. Isto torna mais fácil ligar o código à um processamento batch que iremos definir mais à frente nesse tutorial. De acordo com a interface, você recebe um objeto do tipo 
`Autobot` e depois transforma os dados para maiúsculo retornando novamente um objeto do tipo `Autobot`.
 
 {: .box-note}
Não é obrigatório que os objetos de entrada e saída sejam do mesmo tipo. Na verdade, muitas vezes as aplicações necessitam que o objeto de saída seja diferente do de entrada.

### Criando o processamento batch
Spring Batch provê muitas classes utilitárias que reduzem a necessidade de escrever código customizado.
Ao invés disso você pode focar na lógica de negócio

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
        reader.setLineMapper(new DefaultLineMapper<Autobot>() {{
            setLineTokenizer(new DelimitedLineTokenizer() {{
                setNames(new String[]{"name", "car"});
            }});
            setFieldSetMapper(new BeanWrapperFieldSetMapper<Autobot>() {{
                setTargetType(Autobot.class);
            }});
        }});
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
A anotação `@EnableBatchProcessing` adiciona vários beans críticos para suportar a criação dos `batch jobs` e te ajuda a não 
escrever muitas linhas de código. Esse examplo usa um banco de dados em memória, isso quer dizer que quando o processo termina
os dados se perdem.

Passo a passo:

`src/main/java/com/marcosbarbero/wd/batch/BatchConfiguration`

```java
    @Bean
    public FlatFileItemReader<Autobot> reader() {
        FlatFileItemReader<Autobot> reader = new FlatFileItemReader<>();
        reader.setResource(new ClassPathResource("sample-data.csv"));
        reader.setLineMapper(new DefaultLineMapper<Autobot>() {{
            setLineTokenizer(new DelimitedLineTokenizer() {{
                setNames(new String[]{"name", "car"});
            }});
            setFieldSetMapper(new BeanWrapperFieldSetMapper<Autobot>() {{
                setTargetType(Autobot.class);
            }});
        }});
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

A primeira parte do código define a entrada, processamento e saída. - `reader()` cria um `ItemReader`. Ele procura por um
arquivo chamado `sample-data.csv` e converte cada linha em um `Autobot` - `processor()` cria uma instancia do nosso 
`AutobotItemProcessor` que foi definido anteriormente, para transformar os dados para maiúsculo. - `write(DataSource)` cria
um `ItemWriter`. Esse tem como foco a inserção de dados JDBC.

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

O primeiro método define um processo (job) e o segundo define um passo (step). Processos são construídos à partir de passos,
onde cada passo envolve um `reader`, `processor` e um `writer`.

Na definição desse processo, você precisa de um `incrementer` porque `processos` usam um banco de dados para manter o estado
de execução. Você então lista cada passo, esse processo tem apenas um passo. O processo termina, e a API Java produz um 
processo perfeitamente configurado.

Na definição do passo (step), você definite quantos dados quer escrever ao mesmo tempo. Nesse caso, a aplicação escreve até 10 registros ao mesmo tempo. Depois você configura o `reader`, `processor` e `writer` injetando os métodos definidos mais cedo 
nesse tutorial.

{: .box-note}
`chunk()` está prefixado <Autobot, Autobot>  porque ele é um método genérico. Ele representa os tipos de entrada e saída de
cada "chunk" de processamento, e se alinha com `ItemReader<Autobot>` e `ItemWriter<Autobot>`.

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

Esse código executa quando o processamento está com o status `BatchStatus.COMPLETED`, e então usa o `JdbcTemplate` para
verificar os resultados.

### Executando
Esse projeto foi construído usando [Spring Boot](https://projects.spring.io/spring-boot/), para executá-lo basta compilar o
código com o seguinte comando:

```bash
$ ./mvnw clean package
```

E então executá-lo com o seguinte comando:

```bash
$ java -jar target/batch-service-0.0.1-SNAPSHOT.jar
```

O processo imprime uma linha para cada autobot que é transformado. Depois que o processo termina você também pode ver a saída
a partir da busca ao banco de dados.

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
Os dados acima estão divergentes entre `entrada` e `saída` porque eu removi alguns dados para facilitar a leitura.

### Sumário
Parabéns! Você acabou de construir um processo batch que lê dados de uma planilha, processa e escreve no banco de dados.

#### Nota de rodapé
 - Esse tutorial foi criado baseando-se no seguinte link: [Creating a Batch Service](https://spring.io/guides/gs/batch-processing/)
 - O código desse tutorial está disponível no [github](https://github.com/weekly-drafts/batch-service)