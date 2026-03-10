package org.example.org.controller;

import org.example.org.log.LoggingInterceptor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

import java.util.Collections;

@Configuration
public class RestClientConfig {

    @Bean
    public RestTemplate restTemplate() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(3000); // 3 segundos para conectar
        factory.setReadTimeout(30000);    // 5 segundos máximo esperando respuesta
        // Aquí inyectamos el interceptor que acabamos de crear
        RestTemplate restTemplate = new RestTemplate(factory);
        // Aquí inyectamos el interceptor que acabamos de crear
        restTemplate.setInterceptors(Collections.singletonList(new LoggingInterceptor()));

        return restTemplate;
    }
}