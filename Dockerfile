FROM openjdk:11-jdk
EXPOSE 9876:9876
RUN mkdir /app
COPY ./build/install/cloud-clipboard/ /app/
WORKDIR /app/bin
CMD ["./cloud-clipboard"]