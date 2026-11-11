FROM gradle:7.6-jdk11 AS build
WORKDIR /workspace
COPY build.gradle.kts settings.gradle.kts gradle.properties ./
COPY src src
RUN gradle --no-daemon installDist

FROM eclipse-temurin:11-jre-noble
USER 0
COPY security/distrust-emudhra.sh /tmp/distrust-emudhra.sh
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates openssl \
    && rm -rf /var/lib/apt/lists/* \
    && sh /tmp/distrust-emudhra.sh \
    && rm /tmp/distrust-emudhra.sh
COPY --from=build /workspace/build/install/cloud-clipboard/ /app/
WORKDIR /app/bin
EXPOSE 9876
CMD ["./cloud-clipboard"]
