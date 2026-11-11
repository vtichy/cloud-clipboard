FROM eclipse-temurin:11.0.33_10-jdk-noble
EXPOSE 9876:9876
RUN mkdir /app
COPY ./build/install/cloud-clipboard/ /app/
WORKDIR /app/bin
CMD ["./cloud-clipboard"]