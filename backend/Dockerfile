# ---- build stage ------------------------------------------------------------------------------
# Full JDK + Maven toolchain lives here only; none of it ships in the runtime image.
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

# Dependency layer first so `docker build` can cache it across source-only changes.
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN chmod +x mvnw && ./mvnw -q -B dependency:go-offline

COPY src src
RUN ./mvnw -q -B clean package -DskipTests

# ---- runtime stage ------------------------------------------------------------------------------
# Slim JRE (no javac/Maven) + tesseract-ocr (native dep of the tess4j OCR fallback) + curl (for the
# HEALTHCHECK below). Debian/Ubuntu-based, not Alpine, so tess4j's native/leptonica libs link against
# the glibc they expect.
FROM eclipse-temurin:21-jre AS runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends tesseract-ocr curl && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --system splitpay && \
    useradd --system --gid splitpay --home-dir /app --shell /usr/sbin/nologin splitpay

WORKDIR /app

COPY --from=build /app/target/*.jar app.jar
COPY eng.traineddata ./eng.traineddata
RUN mkdir -p uploads && chown -R splitpay:splitpay /app

USER splitpay

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
    CMD curl -fsS http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
