---
layout: post
title: User impersonation with Spring Security
bigimg: /img/caution-cone-control-compressed.jpg
share-img: /img/caution-cone-control-compressed.jpg
gh-repo: weekly-drafts/user-impersonation-spring-security
gh-badge: [star, fork, follow]
tags: [spring-framework, spring-security, security, java, tutorial]
permalink: /user-impersonation-with-spring-security/
lang: en
---

This guide walks through the process of creating an user impersonation from super / admin users with 
[spring security](https://spring.io/projects/spring-security).

### Overview

It's a common use-case for secured applications that the `admin` / `super` users to be able to login
as any other user. It can be helpful for use cases such as customer support analysis where the analyst
can access the system as the real user.

A possible solution for that would be asking for the customer's password or get it from the database. This
solution is nothing else than a security breach. If the password storage is implemented correctly it should be
[impossible to recover the customer's password](https://nakedsecurity.sophos.com/2013/11/20/serious-security-how-to-store-your-users-passwords-safely/).

To solve that problem it would be possible for `super` / `admin` users to impersonate any other specific 
user without the need for the target user's password. With a proper user impersonation implementation in
place, the system knows who has really logged in and it can be used to track the super user's action if
there's an audit log in place.

It's a lot to implement from scratch, luckily this feature is present in [spring security](https://spring.io/projects/spring-security).

### Meet SwitchUserFilter

[SwitchUserFilter](https://github.com/spring-projects/spring-security/blob/master/web/src/main/java/org/springframework/security/web/authentication/switchuser/SwitchUserFilter.java)
is a `Filter` responsible for user context switching.

From the javadoc:

>This filter is similar to Unix 'su' however for Spring Security-managed web
>applications. A common use-case for this feature is the ability to allow
>higher-authority users (e.g. ROLE_ADMIN) to switch to a regular user (e.g. ROLE_USER).

This filter requires the following properties:

|Property           |Description                                                  |
|-------------------|-------------------------------------------------------------|
|switchUserUrl      |The processing URL for the user impersonation                |
|switchFailureUrl   |The target URL whenever the user impersonation fails         |
|targetUrl          |The target URL whenever the user impersonation is successful |
|userDetailsService |A reference to the `userDetailsService` `@Bean`              |

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

Now we need to define an HTML form that's going to be used to switch the users.

```html
<form method="GET" th:action="@{/impersonate}" class="form">
    <label for="usernameField">User name:</label>
    <input type="text" name="username" id="usernameField" />
    <input type="submit" value="Switch User" />
</form>
```

Here are some remarks
  * The value defined in the `action` needs the same value defined by the `SwitchUserFilter#switchUserUrl` property.
  * It can be a `GET` request.
  * The request is handled by the `SwitchUserFilter`.

### Securing the form

It's necessary to make sure that only `ADMIN` users will be able to reach the `impersonate form`, otherwise, any
user will be able to switch to another user's account without the need of the password.

Add the following piece of code to the security configuration.

```java
http.authorizeRequests()
        .antMatchers("/switchUser").access("hasRole('ADMIN')");
```

Now, if any other user tries to access the `/switchUser` URL, they will get an `HTTP 403 Forbidden` response.

### Who is really logged in?

This mechanism totally switches the `Authentication` object in the `SecurityContext`, it means, if you look at
the current user's permissions or roles, you'll get the impersonated user's values, not the `ADMIN` user.

Spring Security by default adds a new role `ROLE_PREVIOUS_ADMINISTRATOR` to the impersonated user. So to make it
easier to go back to the `ADMIN` user, we need to add this role to the security configuration.

```java
http.authorizeRequests()
        .antMatchers("/switchUser").access("hasAnyRole('ADMIN', 'ROLE_PREVIOUS_ADMINISTRATOR')");
```

### Summary
Congratulations! You just created a user impersonation filter using spring security.

### Footnote
  - The code used for this tutorial can be found on [github](https://github.com/weekly-drafts/user-impersonation-spring-security)