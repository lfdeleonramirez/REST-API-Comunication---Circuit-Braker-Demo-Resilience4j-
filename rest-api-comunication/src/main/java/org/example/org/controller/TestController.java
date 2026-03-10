package org.example.org.controller;
import org.example.org.service.ExternalApiService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/test-rest")
public class TestController {


    private final ExternalApiService externalApiService;

    public TestController(ExternalApiService externalApiService) {
        this.externalApiService = externalApiService;
    }

    @GetMapping("/ping")
    public String hacerPing() {
        return "¡Prueba inicial de funcionamiento!";
    }

    // Esta es la ruta que tú vas a consumir en local para iniciar la prueba
    @GetMapping("/api/probar-ruta")
    public String probarRutaExterna() {
        return externalApiService.callExternalApi();
    }
}
