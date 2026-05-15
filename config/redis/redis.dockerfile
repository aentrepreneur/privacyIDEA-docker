# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Cache Redis 7 para sesiones y colas
# =================================================================
ARG REDIS_VERSION=7-alpine
FROM redis:${REDIS_VERSION}

RUN echo "Puerto 6379 expuesto" > /tmp/redis.build

EXPOSE 6379

CMD ["redis-server"]

#End Development By AEntrepreneur [PI-docker 2026]