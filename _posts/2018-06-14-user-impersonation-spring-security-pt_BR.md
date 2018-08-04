---
layout: post
title: Personificação de usuário com Spring Security
bigimg: /img/caution-cone-control-compressed.jpg
share-img: /img/caution-cone-control-compressed.jpg
gh-repo: weekly-drafts/user-impersonation-spring-security
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-security, security, java, tutorial]
permalink: /user-impersonation-with-spring-security/
lang: pt_BR
---

Esse tutorial the guiará no processo de criação de um user impersonation a partir de super / admin usuários
com [spring security](https://spring.io/projects/spring-security).

### Introdução

É um caso de uso comum para aplicações seguras que um `admin` /  `super` usuário seja capaz de fazer login
como qualquer outro usuário. Isso pode ser muito útil em casos como análise de suporte ao cliente onde o
analista pode acessar o sistema como o usuário real.

Uma possível solução para isso seria pedir a senha para o cliente ou então procurar por isso no banco de dados.
Essa solução não é nada além de uma falha de segurança. Se o armazenamento de senhas é implementado correntamente
deveria ser [impossível recuperar a senha de um cliente](https://nakedsecurity.sophos.com/2013/11/20/serious-security-how-to-store-your-users-passwords-safely/).

Para resolver esse problema deveria ser possível para um `super` / `admin` usuário personificar qualquer outro
usuário específico sem a necessidade da senha do usuário final. Com uma implementação de personificação de usuário
o sistema sabe quem estava realmente autenticado e isso pode ser usado para rastrear as ações do super usuário se
houver um log de auditoria.

Implementar uma funcionalidade de personificação de usuário é muito trabalhoso, por sorte essa funcionalidade
está presente no [spring security](https://spring.io/projects/spring-security).

### Conheça o SwitchUserFilter

[SwitchUserFilter](https://github.com/spring-projects/spring-security/blob/master/web/src/main/java/org/springframework/security/web/authentication/switchuser/SwitchUserFilter.java)
é um filtro responsável por fazer a troca de contexto dos usuários.

Do javadoc:

>Esse filtro é similar ao Unix 'su' entretanto para aplicações web gerenciadas pelo Spring Security
>Um caso de uso comum para essa funcionalidade é a habilidade de permitir usuários com autoridades altas
>(ex: ROLE_ADMIN) trocar para um usuário comum (ex: ROLE_USER).

Esse filtro requer as seguintes propriedades:

|Propriedade        |Descrição                                                     |
|-------------------|--------------------------------------------------------------|
|switchUserUrl      |A URL de processamento para a personificação do usuário       |
|switchFailureUrl   |A URL de redirecionamento caso a personificação falhe         |
|targetUrl          |A URL de redirecionamento caso a personificação tenha sucesso |
|userDetailsService |Uma referencia para o `@Bean` `userDetailsService`            |

<br />

```java
@Bean
public SwitchUserFilter switchUserFilter() {
    SwitchUserFilter filter = new SwitchUserFilter();
    filter.setUserDetailsService(userDetailsService());
    filter.setSwitchUserUrl("/impersonate");
    filter.setSwitchFailureUrl("/switchUser");
    filter.setTargetUrl("/hello");
    return filter;
}
```

### SwitchUserFilter Form

Agora nós precisamos definir um formulário HTML que será usado para fazer a troca dos usuários.

```html
<form method="GET" th:action="@{/impersonate}" class="form">
    <label for="usernameField">User name:</label>
    <input type="text" name="username" id="usernameField" />
    <input type="submit" value="Switch User" />
</form>
```

Algumas observações:
  * O valor definido na `action` do formulário precisa ser o mesmo definido na propriedade `SwitchUserFilter#switchUserUrl`.
  * Isso pode ser um request do tipo `GET`.
  * O request é interceptado pelo filtro `SwitchUserFilter`.

### Aplicando segurança ao formulário

É necessário fazer com que somente usuários `ADMIN` sejam capazes de acessar o formulário de personificação, caso contrário,
qualquer usuário será capaz de personificar outro usuário sem a necessidade de uma senha.

Adicione o seguinte código na configuração do spring security.


```java
http.authorizeRequests()
        .antMatchers("/switchUser").access("hasRole('ADMIN')");
```

Agora, se qualquer outro usuário tentar acessar o endpoint `/switchUser`, eles receberão uma resposta `HTTP 403 Forbidden`.

### Quem realmente está logado?

Esse mecanismo troca totalmente o objecto `Authentication` no `SecurityContext`, isso quer dizer que se você olhar
para as permissões e roles do usuário atual, você recebrá os valores do usuário personificado, não o usuário `ADMIN`.

Spring Security por padrão adiciona uma nova role `ROLE_PREVIOUS_ADMINISTRATOR` para o usuário personificado. Para facilitar
a volta para o usuário `ADMIN` nós precisamos adicionar essa role para a configuração.

```java
http.authorizeRequests()
        .antMatchers("/switchUser").access("hasAnyRole('ADMIN', 'ROLE_PREVIOUS_ADMINISTRATOR')");
```

### Sumário
Parabéns! Você acabou de criar uma personificação de usuário usando spring security.

### Nota de rodapé
  - O código utilizado nesse tutorial pode ser encontrado no [GitHub](https://github.com/weekly-drafts/user-impersonation-spring-security)