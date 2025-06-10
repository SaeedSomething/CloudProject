# # # Build stage
# # FROM --platform=linux/amd64 amazoncorretto:17-alpine AS builder

# # # Create maven user/group explicitly
# # # USER root
# # # RUN groupadd -r maven && useradd -r -g maven maven
# # # RUN mkdir -p /app && chown -R maven:maven /app
# # # USER maven

# # WORKDIR /app
# # RUN apk add --no-cache bash protobuf protobuf-dev grpc nano
# # # COPY --chown=maven:maven pom.xml .
# # # COPY --chown=maven:maven src ./src
# # COPY . .
# # RUN sed -i 's/\r$//' mvnw
# # # RUN sh
# # # Build with exact output name
# # # RUN ./mvnw clean package -DskipTests -DfinalName=app 

# # # # Runtime stage
# # # FROM openjdk:17-alpine
# # # WORKDIR /app
# # # # Copy JAR with explicit path
# # # COPY --from=builder /app/target/app.jar .
# # # COPY src/main/resources/application.properties ./config/
# # # EXPOSE 8080
# # # CMD ["java", "-jar", "app.jar"]


# FROM amazoncorretto:17 AS builder

# # Install essential tools
# RUN yum update -y && \
#     yum install -y curl which && \
#     yum clean all

# WORKDIR /app

# # Copy build files
# COPY mvnw .
# COPY .mvn .mvn
# COPY pom.xml .
# RUN sed -i 's/\r$//' mvnw
# # Download dependencies first for caching
# RUN ./mvnw dependency:go-offline -B

# # Copy source code
# COPY src src

# # Build application
# # RUN chmod +x ./target/protoc-plugins/*
# RUN chmod +x mvnw && \
#     ./mvnw clean package -DskipTests 

# RUN chmod 777 "target/fum-cloud-notification-core-0.0.1-SNAPSHOT.jar"

# # ---- Runtime Stage ----
# FROM amazoncorretto:17-alpine

# WORKDIR /app

# # Copy only the built JAR from the builder stage
# COPY --from=builder /app/target/fum-cloud-notification-core-0.0.1-SNAPSHOT.jar app.jar

# EXPOSE 8080
# RUN chmod 777 "app.jar"

# CMD ["java", "-jar", "app.jar"]
# # ---- Build Stage ----
# FROM amazoncorretto:17-alpine AS builder

# WORKDIR /app

# # Install build dependencies
# RUN apk add --no-cache \
#     bash \
#     protoc \
#     protobuf-dev \
#     grpc \
#     make

# # Copy Maven wrapper and project files
# COPY mvnw .
# COPY .mvn .mvn
# COPY pom.xml .

# # Fix line endings and make mvnw executable
# RUN sed -i 's/\r$//' mvnw && chmod +x mvnw

# # Download dependencies for caching
# RUN ./mvnw clean package -DskipTests 

# # Copy source code
# COPY src src

# # Create target directory
# RUN mkdir -p target

# # Build the application with custom protoc path
# RUN ./mvnw clean package -DskipTests \
#     -Dprotobuf.protoc=/usr/bin/protoc \
#     -Dprotobuf.protoc.version=$(protoc --version | cut -d' ' -f2)

# # ---- Runtime Stage ----
# FROM amazoncorretto:17-alpine

# WORKDIR /app

# # Copy only the built JAR from the builder stage
# COPY --from=builder /app/target/fum-cloud-notification-core-0.0.1-SNAPSHOT.jar app.jar

# EXPOSE 8080

# CMD ["java", "-jar", "app.jar"]


FROM maven:3.8.4-openjdk-17 AS builder

WORKDIR /app

# Copy Maven wrapper and project files
COPY .mvn .mvn
COPY mvnw .
COPY pom.xml .

# Download dependencies
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline

# Copy source code
COPY src src
RUN mvn clean
RUN mvn package -DskipTests
# Build the application
RUN --mount=type=cache,target=/root/.m2 \
    mvn clean package -DskipTests

# Runtime stage
FROM openjdk:17-slim

WORKDIR /app

# Copy the built JAR from builder stage
COPY --from=builder /app/target/*.jar app.jar
RUN chmod 777 "app.jar"
EXPOSE 8080

CMD ["java", "-jar", "app.jar"]