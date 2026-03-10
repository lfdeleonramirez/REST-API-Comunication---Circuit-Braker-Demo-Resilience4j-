package org.example.org.service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class ExternalApiService {

    private final RestTemplate restTemplate;

    @Value("${EXTERNAL_API_URL}")
    private String apiUrl;

    public ExternalApiService(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    // "externalApi" es el nombre del circuito que configuraremos en el properties
    @CircuitBreaker(name = "externalApi", fallbackMethod = "fallbackResponse")
    public String callExternalApi() {
        // httpbin.org/delay/x simula un endpoint que tarda, pero en tu caso apuntará a toxiproxy
        return restTemplate.getForObject(apiUrl + "/delay/1", String.class);
    }

    public String fallbackResponse(Exception e) {
        // Aquí puedes retornar datos cacheados, un mensaje de error controlado, etc.
        return "El servicio externo no está disponible temporalmente. Se protegió el hilo.";
    }
}