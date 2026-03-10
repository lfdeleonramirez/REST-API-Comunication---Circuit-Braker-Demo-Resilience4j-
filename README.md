# REST API Communication - Circuit Breaker Demo

[![Java](https://img.shields.io/badge/Java-8-orange.svg)](https://www.oracle.com/java/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-2.7.18-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![Resilience4j](https://img.shields.io/badge/Resilience4j-1.7.0-blue.svg)](https://resilience4j.readme.io/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED.svg)](https://www.docker.com/)

Proyecto de demostración que implementa patrones de resiliencia en comunicaciones REST usando **Circuit Breaker** con Resilience4j. Incluye simulación de fallos de red mediante Toxiproxy para pruebas de estrés y comportamiento bajo condiciones adversas.

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Arquitectura](#-arquitectura)
- [Requisitos Previos](#-requisitos-previos)
- [Instalación y Ejecución](#-instalación-y-ejecución)
- [Uso](#-uso)
- [Configuración del Circuit Breaker](#-configuración-del-circuit-breaker)
- [Pruebas de Resiliencia](#-pruebas-de-resiliencia)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Tecnologías](#-tecnologías)
- [Contribuir](#-contribuir)
- [Licencia](#-licencia)

## 🚀 Características

- ✅ **Circuit Breaker Pattern** implementado con Resilience4j
- ✅ **Fallback automático** cuando el servicio externo falla
- ✅ **Logging detallado** de peticiones HTTP con tiempos de respuesta
- ✅ **Simulación de fallos** con Toxiproxy (latencia, timeouts, errores)
- ✅ **Configuración de timeouts** personalizables
- ✅ **Documentación API** con Swagger
- ✅ **Entorno Dockerizado** completo con Docker Compose
- ✅ **Scripts de prueba** para saturación y estrés

## 🏗️ Arquitectura

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐      ┌──────────────┐
│   Cliente   │─────▶│  Spring Boot │─────▶│  Toxiproxy  │─────▶│ External API │
│             │      │     App      │      │   (Proxy)   │      │   (httpbin)  │
└─────────────┘      └──────────────┘      └─────────────┘      └──────────────┘
                            │
                            │
                     ┌──────▼──────┐
                     │  PostgreSQL │
                     │      DB     │
                     └─────────────┘
```

### Componentes

1. **Spring Boot App**: Aplicación principal con Circuit Breaker
2. **Toxiproxy**: Proxy para simular problemas de red
3. **External API (httpbin)**: API externa simulada para pruebas
4. **PostgreSQL**: Base de datos (configurada pero no utilizada en esta demo)

## 📦 Requisitos Previos

- **Docker** y **Docker Compose** instalados
- **Maven** 3.6+ (si deseas compilar localmente)
- **Java 8** o superior (si deseas ejecutar sin Docker)
- **curl** (para ejecutar los scripts de prueba)

## 🔧 Instalación y Ejecución

### Opción 1: Usando el script de inicio (Recomendado)

```bash
# Dar permisos de ejecución al script
chmod +x start-all.sh

# Ejecutar
./start-all.sh
```

### Opción 2: Manualmente con Docker Compose

```bash
# Compilar el proyecto Maven
cd rest-api-comunication
mvn clean package
cd ..

# Levantar todos los servicios
docker-compose up -d --build
```

### Verificar que los servicios están corriendo

```bash
docker-compose ps
```

Deberías ver 4 servicios activos:
- `app` (puerto 8080)
- `db` (puerto 5432)
- `external-api`
- `toxiproxy` (puertos 8474 y 8081)

## 📖 Uso

### Endpoints Disponibles

#### 1. Health Check
```bash
curl http://localhost:8080/api/v1/test-rest/ping
```

**Respuesta esperada:**
```
¡Prueba inicial de funcionamiento!
```

#### 2. Llamada a API Externa (con Circuit Breaker)
```bash
curl http://localhost:8080/api/v1/test-rest/api/probar-ruta
```

**Respuesta exitosa:**
```json
{
  "args": {},
  "data": "",
  "files": {},
  ...
}
```

**Respuesta cuando el Circuit Breaker está abierto:**
```
El servicio externo no está disponible temporalmente. Se protegió el hilo.
```

#### 3. Documentación Swagger

Accede a la documentación interactiva de la API:
```
http://localhost:8080/swagger-ui.html
```

## ⚙️ Configuración del Circuit Breaker

La configuración se encuentra en `application.properties`:

```properties
# Ventana deslizante de 10 llamadas para calcular tasas de fallo
resilience4j.circuitbreaker.instances.externalApi.slidingWindowSize=10

# Se abre el circuito si 50% de las llamadas fallan
resilience4j.circuitbreaker.instances.externalApi.failureRateThreshold=50

# Se abre si 50% de las llamadas son lentas (>4 segundos)
resilience4j.circuitbreaker.instances.externalApi.slowCallRateThreshold=50
resilience4j.circuitbreaker.instances.externalApi.slowCallDurationThreshold=4000

# Permanece abierto 20 segundos antes de intentar recuperarse
resilience4j.circuitbreaker.instances.externalApi.waitDurationInOpenState=20000

# Permite 3 llamadas en estado semi-abierto para probar recuperación
resilience4j.circuitbreaker.instances.externalApi.permittedNumberOfCallsInHalfOpenState=3
```

### Estados del Circuit Breaker

1. **CLOSED** (Cerrado): Funcionamiento normal, todas las peticiones pasan
2. **OPEN** (Abierto): Circuito abierto, se ejecuta el fallback sin intentar la llamada
3. **HALF_OPEN** (Semi-abierto): Permite algunas llamadas de prueba para verificar recuperación

## 🧪 Pruebas de Resiliencia

### 1. Prueba de Saturación

Envía 500 peticiones concurrentes para probar el comportamiento bajo carga:

```bash
cd tests
chmod +x test-api.sh
./test-api.sh
```

### 2. Agregar Latencia Extrema

Simula una latencia de 30 segundos en la API externa:

```bash
cd tests
chmod +x add-primary-latency.sh
./add-primary-latency.sh
```

Verifica que se agregó:
```bash
curl http://localhost:8474/proxies/proxy_hacia_api_externo/toxics
```

### 3. Actualizar Latencia

Cambia la latencia a 60 segundos:

```bash
cd tests
chmod +x update-latency-toxic.sh
./update-latency-toxic.sh
```

### 4. Eliminar Latencia

```bash
curl -X DELETE http://localhost:8474/proxies/proxy_hacia_api_externo/toxics/latencia_extrema
```

### 5. Monitorear Logs

```bash
# Ver logs de la aplicación
docker-compose logs -f app

# Ver logs de Toxiproxy
docker-compose logs -f toxiproxy
```

## 📁 Estructura del Proyecto

```
.
├── docker-compose.yml              # Orquestación de servicios
├── start-all.sh                    # Script de inicio rápido
├── rest-api-comunication/
│   ├── Dockerfile                  # Imagen Docker de la app
│   ├── pom.xml                     # Dependencias Maven
│   └── src/
│       └── main/
│           ├── java/
│           │   └── org/example/
│           │       ├── Main.java                    # Punto de entrada
│           │       ├── SwaggerConfig.java           # Configuración Swagger
│           │       └── org/
│           │           ├── controller/
│           │           │   ├── TestController.java       # Endpoints REST
│           │           │   └── RestClientConfig.java     # Config RestTemplate
│           │           ├── service/
│           │           │   └── ExternalApiService.java   # Lógica Circuit Breaker
│           │           └── log/
│           │               └── LoggingInterceptor.java   # Interceptor HTTP
│           └── resources/
│               └── application.properties          # Configuración Spring
└── tests/
    ├── test-api.sh                 # Script de saturación
    ├── add-primary-latency.sh      # Agregar latencia
    ├── update-latency-toxic.sh     # Actualizar latencia
    └── json/
        ├── toxiproxy.json          # Config inicial Toxiproxy
        ├── toxic.json              # Config latencia 30s
        └── update_toxic.json       # Config latencia 60s
```

## 🛠️ Tecnologías

| Tecnología | Versión | Propósito |
|-----------|---------|-----------|
| Java | 8 | Lenguaje de programación |
| Spring Boot | 2.7.18 | Framework web |
| Resilience4j | 1.7.0 | Circuit Breaker |
| Swagger | 2.9.2 | Documentación API |
| PostgreSQL | 13 | Base de datos |
| Toxiproxy | latest | Simulación de fallos |
| httpbin | latest | API externa de prueba |
| Docker | - | Contenedorización |
| Maven | - | Gestión de dependencias |

## 🔍 Conceptos Clave

### Circuit Breaker Pattern

El patrón Circuit Breaker protege tu aplicación de fallos en cascada cuando un servicio externo falla o se vuelve lento. Funciona como un interruptor eléctrico:

- **Detecta fallos**: Monitorea las llamadas y cuenta errores
- **Abre el circuito**: Cuando se supera el umbral, deja de intentar llamadas
- **Fallback**: Ejecuta una respuesta alternativa
- **Recuperación automática**: Intenta recuperarse después de un tiempo

### Toxiproxy

Toxiproxy es un proxy TCP que permite simular condiciones de red adversas:

- **Latencia**: Retrasos en las respuestas
- **Timeout**: Conexiones que nunca responden
- **Bandwidth**: Limitación de ancho de banda
- **Slow close**: Cierre lento de conexiones

## 📊 Métricas y Monitoreo

### Ver estado del Circuit Breaker

Los logs de la aplicación muestran:
- ✅ Llamadas exitosas con tiempo de respuesta
- ❌ Llamadas fallidas con detalles del error
- 🔄 Cambios de estado del Circuit Breaker

### Ejemplo de logs

```
✅ OK | URI: http://toxiproxy:8080/delay/1 | Tiempo: 1234 ms | Status: 200
❌ FALLO/TIMEOUT | URI: http://toxiproxy:8080/delay/1 | Tiempo: 30000 ms | Error: Read timed out
```

## 🐛 Troubleshooting

### La aplicación no inicia

```bash
# Verificar que los puertos no estén ocupados
netstat -an | grep 8080
netstat -an | grep 5432

# Limpiar contenedores anteriores
docker-compose down -v
docker-compose up -d --build
```

### El Circuit Breaker no se abre

- Verifica que la latencia configurada en Toxiproxy sea mayor a `slowCallDurationThreshold` (4000ms)
- Asegúrate de hacer al menos 10 llamadas (tamaño de la ventana deslizante)
- Revisa los logs para ver el estado del circuito

### Toxiproxy no aplica la latencia

```bash
# Verificar que el toxic esté configurado
curl http://localhost:8474/proxies/proxy_hacia_api_externo/toxics

# Eliminar y volver a crear
curl -X DELETE http://localhost:8474/proxies/proxy_hacia_api_externo/toxics/latencia_extrema
cd tests && ./add-primary-latency.sh
```

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto es de código abierto y está disponible bajo la licencia MIT.

## 📧 Contacto

Si tienes preguntas o sugerencias, no dudes en abrir un issue en el repositorio.

---

⭐ Si este proyecto te fue útil, considera darle una estrella en GitHub
