# Étape 1 : construction du JAR avec Maven et le JDK complet
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -q -B package -DskipTests

# Étape 2 : découpage du JAR en couches (layertools de Spring Boot)
FROM eclipse-temurin:21-jre AS couches
WORKDIR /couches
COPY --from=build /build/target/*.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract

# Étape 3 : image finale, avec un JRE seul
FROM eclipse-temurin:21-jre
RUN useradd --system --uid 1001 spring
USER 1001
WORKDIR /app

# De la couche la plus stable à la plus changeante
COPY --from=couches /couches/dependencies/ ./
COPY --from=couches /couches/spring-boot-loader/ ./
COPY --from=couches /couches/snapshot-dependencies/ ./
COPY --from=couches /couches/application/ ./

# Version affichée par /api/info (v1 par défaut)
ARG APP_VERSION=v1
ENV APP_VERSION=${APP_VERSION}

EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "org.springframework.boot.loader.launch.JarLauncher"]
