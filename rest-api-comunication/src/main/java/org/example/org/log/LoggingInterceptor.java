package org.example.org.log;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpRequest;
import org.springframework.http.client.ClientHttpRequestExecution;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.ClientHttpResponse;

import java.io.IOException;

public class LoggingInterceptor implements ClientHttpRequestInterceptor {

    private static final Logger log = LoggerFactory.getLogger(LoggingInterceptor.class);

    @Override
    public ClientHttpResponse intercept(HttpRequest request, byte[] body, ClientHttpRequestExecution execution) throws IOException {

        long startTime = System.currentTimeMillis();

        try {
            // Intenta ejecutar la petición
            ClientHttpResponse response = execution.execute(request, body);
            long duration = System.currentTimeMillis() - startTime;

            log.info("✅ OK | URI: {} | Tiempo: {} ms | Status: {}",
                    request.getURI(), duration, response.getRawStatusCode());

            return response;

        } catch (IOException e) {
            // Si hay un timeout o error de red, cae aquí
            long duration = System.currentTimeMillis() - startTime;

            log.error("❌ FALLO/TIMEOUT | URI: {} | Tiempo: {} ms | Error: {}",
                    request.getURI(), duration, e.getMessage());

            // Volvemos a lanzar la excepción para que el CircuitBreaker (Resilience4j) la atrape y active el Fallback
            throw e;
        }
    }
}