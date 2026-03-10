# FROM amazoncorretto:8
FROM eclipse-temurin:8-jre-jammy

# Instalar herramientas para monitoreo interno usando yum
RUN apt-get update && apt-get install -y htop procps curl net-tools && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ./target/rest-api-comunication-1.0-SNAPSHOT.jar app.jar

# Exponer puerto de la app y
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
