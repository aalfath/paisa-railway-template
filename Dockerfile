# Paisa on Railway: the official image, pinned by version and digest.
# The "-all" variant ships ledger, hledger and beancount, so every `ledger_cli` option works.
FROM mikefarah/yq:4.54.3@sha256:7834187596ad56fd5a81436114e0b0b9dd54c91bb43946d1f7145b2be5f9c3d2 AS yq

FROM ananthakumaran/paisa:v0.8.0-all@sha256:32d69218d0822076a694df48c1b21a442c05adb36364830b6a9c1ccd21ade627

# yq edits paisa.yaml at start (login account); the start script does the rest.
COPY --from=yq /usr/bin/yq /usr/local/bin/yq
COPY railway-start.sh /usr/local/bin/railway-start.sh
RUN chmod 755 /usr/local/bin/railway-start.sh /usr/local/bin/yq

# Data (paisa.yaml, journal files, sheets, paisa.db) lives here: mount a volume on it.
ENV PAISA_DATA_DIR=/root/Documents/paisa
WORKDIR /root/Documents/paisa
EXPOSE 7500
CMD ["/usr/local/bin/railway-start.sh"]
