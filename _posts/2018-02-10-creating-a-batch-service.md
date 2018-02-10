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
    name VARCHAR(20),
    car VARCHAR(20)
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