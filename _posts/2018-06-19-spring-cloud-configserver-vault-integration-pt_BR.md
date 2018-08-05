---
layout: post
title: Integrando Vault com Spring Cloud Config Server
bigimg: /img/chain-key-lock.jpg
share-img: /img/chain-key-lock.jpg
gh-repo: weekly-drafts/spring-cloud-configserver-vault
gh-badge: [star, fork, follow]
tags: [spring-framework, security, spring-cloud, vault, java, tutorial]
permalink: /integrating-vault-spring-cloud-config/
lang: pt_BR
---

Esse tutorial te guiará no processo de criação de um gerenciamento centralizado de configurações
para microservices usando [Spring Cloud Config](https://cloud.spring.io/spring-cloud-config/)
integrando com [HashiCorp Vault](https://www.vaultproject.io/).

### Introduction

Atualmente é comum que softwares sejam entregues como serviço e não importa qual linguagem de
programação foi escolhia, é sempre uma boa pratica seguir a metodologia [dos doze fatores](https://12factor.net/).

O primeiro fator fala sobre o [código](https://12factor.net/codebase), ele começa dizendo:

>One codebase tracked in revision control, many deploys

Se eu traduzir literalmente para português vai ficar bem estranho, mas a ideia é que
o mesmo código deve ser deployado várias vezes em vários ambientes sem nenhuma mudança no 
código além das configurações, e isso nos leve para configurações externalizadas.

Se você está trabalhando com microservices em um ambiente elástico, você provavelmente notou a
necessidade de um local centralizado para gerenciamento das configurações, e isso também é 
[um dos doze fatores](https://12factor.net/config).

### Pre-req
 
 * [JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)
 * Editor de texto ou sua IDE favorita
 * [Maven 3.0+](https://maven.apache.org/download.cgi)
 * [Docker](https://www.docker.com/)

### Spring Cloud Config

[Spring Cloud Config](https://cloud.spring.io/spring-cloud-config/) provê server e client-side suporte para
configurações externalizadas em sistemas distribuídos e ele tem alguns tipos de armazenamentos suportados,
nesse tutorial nós vamos cobrir os seguintes:

  * [File System](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html#_file_system_backend)
  * [Git](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html#_git_backend)
  * [Vault](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html#vault-backend)

#### Config Server 

O jeito mais fácil de criar um Config Server é acessando [start.spring.io](http://start.spring.io/), procure por `Config Server`
no campo de busca de dependências e click no botão `Generate Project`, isso irá gerar um arquivo zip contendo o projeto com todas
as dependências necessárias. Unzip o projeto, abra a classe principal e adicione a anotação `@EnableConfigServer` na classe.

Examplo:

```java
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.config.server.EnableConfigServer;

@EnableConfigServer
@SpringBootApplication
public class ConfigServerApplication {

  public static void main(String[] args) {
    SpringApplication.run(ConfigServerApplication.class, args);
  }

}
```

{: .box-note}
O projeto gerado contém um arquivo `application.properties` localizado em `src/main/resources`, por preferencias
pessoais eu renomeei esse arquivo para `application.yml`.

Abra o arquivo `application.yml` e adicione a seguinte configuração, como eu estou rodando todas as aplicações na
mesma máquina é importante alterar o `server.port`.

```yaml
server:
  port: 8888

spring:
  application:
    name: configserver
```

#### Profiles & Implementações padrão

Spring Cloud Config Server usa `profiles` para prover multiplas estratégias de armazenamento, vamos falar de algumas delas.

##### File System Backend

Existe um profile `native` disponível onde o `Config Server` procura por arquivos properties/YAML no classpath ou no file system.

```yaml
spring:
  profiles:
    active: native
```

{: .box-note}
O valor padrão do `searchLocations` é idêntico à uma aplicação Spring Boot (`[classpath:/, classpath:/config, file:./, file:./config]`). 
Isso não expõe o `application.properties` do server para todos os clientes, porque qualquer property source presente no server é
removido antes de ser enviado para o cliente.

Você pode apontar para qualquer localização usando `spring.cloud.config.server.native.searchLocations`.

{: .box-note}
Lembre-se de usar o prefixo `file:` para arquivos no file system (o padrão sem prefixo é o classpath).  
Como em qualquer configuração Spring Boot você pode usar placeholders `${}` para o ambiente, mas lembre-se
que caminhos absolutos no Windows requerem uma `/` extra (por exemplo, `file:///${user.home}/config-repo`).

Para esse tutorial eu criarei um diretório chamado `config-repo` no `${user.home}`, esse novo diretório é
criado para armazenar os arquivos de configuração do profile native.

Agora adicione a seguinte configuração no `application.yml`.

```yaml
spring:
  cloud:
    config:
      server:
        native:
          searchLocations: file://${user.home}/config-repo
```

Agora crie o arquivo `config-repo/configclient.yml`, esse arquivo armazena a configuração para o nosso
microservice (será criado adiante nesse tutorial) chamado `configclient`, e adicione a seguinte configuração:

```
client:
  pseudo:
    property: Property value loaded from File System
```

Agora você pode iniciar a aplicação e acessar o endpoint `http://localhost:8888/configclient/default`, a resposta será:

```json
{  
   "name":"configclient",
   "profiles":[  
      "default"
   ],
   "label":null,
   "version":null,
   "state":null,
   "propertySources":[  
      {  
         "name":"file:///Users/my-user/config-repo/configclient.yml",
         "source":{  
            "client.pseudo.property":"Property value loaded from File System"
         }
      }
   ]
}
```

{: .box-warning}
O profile `native` é um bom jeito de começar a usar o `Config Server` em um ambiente local,
mas eu não recomendo que alguém use um armazenamento em file system para produção.

##### Git Backend

Também existe um `git` profile onde você pode apontar um repositório git que contém todos os arquivos de configurações
para os seus microservices. Para fazer isso funcionar você pode adicionar o profile `git` para os profiles ativos ou então
remover completamente a property `spring.profiles.active`. Se você escolher manter essa propriedade, a última especificada
tem prioridade e sobreescreve o que está definido na anterior.

Adicione a seguinte configuração:

```yaml
spring:
  profiles:
    active: native, git
  cloud:
    config:
      server:
        git:
          uri: https://github.com/weekly-drafts/config-repo-spring-cloud-configserver-vault
```

Aqui a configuração completa para referencia:

```yaml
spring:
  profiles:
    active: native, git
  application:
    name: configserver
  cloud:
    config:
      server:
        native:
          searchLocations: file://${user.home}/config-repo
        git:
          uri: https://github.com/weekly-drafts/config-repo-spring-cloud-configserver-vault
```

Agora se você acessar `http://localhost:8888/configclient/default`, o resultado será:

```json
{  
   "name":"configclient",
   "profiles":[  
      "default"
   ],
   "label":null,
   "version":null,
   "state":null,
   "propertySources":[  
      {  
         "name":"file:///Users/my-user/config-repo/configclient.yml",
         "source":{  
            "client.pseudo.property":"Property value loaded from File System"
         }
      },
      {  
         "name":"https://github.com/weekly-drafts/config-repo-spring-cloud-configserver-vault/configclient.yml",
         "source":{  
            "client.pseudo.property":"Property value loaded from Git"
         }
      }
   ]
}
```

{: .box-note}
Se um profile não foi escolhido `git` é o valor padrão.

##### Vault Backend

Sobre o [Vault](https://www.vaultproject.io/):

{: .box-note}
Vault é uma ferramenta para seguramente acessar _secrets_. Um _secret_ é qualquer coisa que você queira ter controle sobre o acesso, como API keys, senhas, certificados e
qualquer outra informação sensível. Valut provê uma interface unificada para qualquer _secret_ enquanto fornece um log de autotoria detalhado e um controle de acesso.

Também há um profile `vault` que habilita a integração com [Vault](https://www.vaultproject.io/) para seguramente armazenar as
propriedades das aplicações, e nesse tópico nós usaremores `docker` para criar o container do `vault`.

Crie um container Vault:

```bash
docker run -d -p 8200:8200 --name vault -e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault
```

{: .box-warning}
Aqui está especificado um token root, **não** faça isso em produção.

Entre no container e autentique no Vault:

```bash
docker exec -i -t vault sh
export VAULT_ADDR='http://localhost:8200'
vault auth myroot
```

Agora é hora de escrevermos nossas propriedades:

```bash
vault write secret/configclient client.pseudo.property="Property value loaded from Vault"
```

Agora que temos tudo configurado é hora de configurar a comunicação entre o `Config Server` e o `Vault`, adicione
as seguintes propriedades:

```yaml
spring:
  profiles:
    active: vault
  cloud:
    config:
      server:
        vault:
          port: 8200
          host: 127.0.01
```

Configuração completa para referência:

```yaml
spring:
  profiles:
    active: native, git, vault
  application:
    name: configserver
  cloud:
    config:
      server:
        native:
          searchLocations: file://${user.home}/config-repo
        git:
          uri: https://github.com/weekly-drafts/config-repo-spring-cloud-configserver-vault
        vault:
          port: 8200
          host: 127.0.01
```

{: .box-note}
Você também pode armazenar as propriedades de uma maneira segura
sem o Vault usando [encryption](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html#_encryption_and_decryption).

#### Config Client

Como antes, o jeito mais fácil de criar um `config client` é acessando [start.spring.io](http://start.spring.io/) 
e adicionando `Config Client` e `Web` nas dependencias. Abra o arquivo gerado e crie o arquivo `resources/bootstrap.yml` 
com o seguinte conteúdo:

```yaml
spring:
  application:
    name: configclient
  cloud:
    config:
      token: myroot
      uri: http://localhost:8888
```

{: .box-note}
É importante adicionar exatamente `configclient` como `spring.application.name` porque esse é o nome usado para conectar com 
as configurações externalizadas.

Agora abra a classe principal e adicione uma anotaçõa `@Value` para recuperar nossa propriedade, aqui minha classe principal
para referência:

```java
@RestController
@SpringBootApplication
public class ConfigClientApplication {

    public static void main(String[] args) {
        SpringApplication.run(ConfigClientApplication.class, args);
    }

    @Value("${client.pseudo.property}")
    private String pseudoProperty;

    @GetMapping("/property")
    public ResponseEntity<String> getProperty() {
        return ResponseEntity.ok(pseudoProperty);
    }
}
```

Depois de iniciar a aplicação será possível acessar `http://localhost:8080/property` e o resultado esperado é:

```bash
Property value loaded from Vault
```

### Sumário
Parabéns! Você acabou de criar um gerenciamento de configurações centralizado usando 
[Spring Cloud Config](https://cloud.spring.io/spring-cloud-config/)
e protegeu a senhas usando [HashiCorp Vault](https://www.vaultproject.io/). 

### Nota de rodapé
  - O código usado nesse tutorial pode ser encontrado no [GitHub](https://github.com/weekly-drafts/spring-cloud-configserver-vault)
  - [Documentação do Spring Cloud Config](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html)