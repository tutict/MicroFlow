FROM maven:3.9.11-eclipse-temurin-21 AS build

WORKDIR /workspace

COPY pom.xml ./
COPY src ./src

RUN mvn -B -DskipTests package

FROM eclipse-temurin:21-jre-jammy

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/microflow

ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75" \
    MICROFLOW_DATA_DIR=/opt/microflow/data \
    MICROFLOW_DB_PATH=/opt/microflow/db/microflow.db \
    MICROFLOW_AGENT_CONFIG_PATH=/opt/microflow/data/agents.json

RUN mkdir -p /opt/microflow/data /opt/microflow/db

COPY --from=build /workspace/target/*.jar /opt/microflow/app.jar

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl --fail --silent http://127.0.0.1:8080/api/v1/system/health > /dev/null || exit 1

ENTRYPOINT ["sh", "-c", "exec java $JAVA_TOOL_OPTIONS -jar /opt/microflow/app.jar"]
