FROM python@sha256:0b23cfb7425d065008b778022a17b1551c82f8b4866ee5a7a200084b7e2eafbf AS buildtime

WORKDIR /app

COPY . .


FROM python@sha256:0b23cfb7425d065008b778022a17b1551c82f8b4866ee5a7a200084b7e2eafbf AS runtime

WORKDIR /app 

COPY --from=buildtime /app/index.html /app/index.html

COPY --from=buildtime /app/js/ /app/js

COPY --from=buildtime /app/style/ /app/style 

COPY --from=buildtime /app/entrypoint.sh /app/entrypoint.sh

COPY --from=buildtime /app/server.py /app/server.py

RUN chmod +x /app/entrypoint.sh

RUN groupadd --gid 1000 my_group && useradd --uid 1000 --gid 1000 -m my_user 

RUN chown -R my_user:my_group /app

USER my_user 

# Set LOG_LEVEL via environment variable: DEBUG, INFO, WARN, ERROR, NONE
ENV LOG_LEVEL=INFO

EXPOSE 3000

ENTRYPOINT ["/app/entrypoint.sh"]

