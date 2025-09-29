FROM debian:10-slim
ARG TEA_VERSION=1.4.22
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install required packages
RUN apt-get update -y && \
    apt-get --no-install-recommends install -y \
        ca-certificates \
        python3 \
        python3-pip \
        netcat \
        curl \
        && \
    curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl && \
    chmod a+rx /usr/local/bin/youtube-dl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create teaspeak user and directory
RUN groupadd -r teaspeak && useradd -r -g teaspeak teaspeak
RUN mkdir -p /opt/teaspeak && chown teaspeak:teaspeak /opt/teaspeak

# Copy TeaSpeak files from local directory
COPY --chown=teaspeak:teaspeak TeaSpeak-${TEA_VERSION}/ /opt/teaspeak/

# Copy configuration files
COPY --chown=teaspeak:teaspeak config.yml /opt/teaspeak/
COPY --chown=teaspeak:teaspeak protocol_key.txt /opt/teaspeak/

# Set working directory and permissions
WORKDIR /opt/teaspeak
RUN chmod +x /opt/teaspeak/TeaSpeakServer && \
    chmod +x /opt/teaspeak/*.sh && \
    mkdir -p /opt/teaspeak/{logs,files,database,certs} && \
    chown -R teaspeak:teaspeak /opt/teaspeak

# Install music bot if script exists
RUN if [ -f "./install_music.sh" ]; then \
        ./install_music.sh install && \
        rm -rf tmp_files; \
    fi

# Switch to teaspeak user
USER teaspeak

# Expose ports
EXPOSE 10011/tcp 30033/tcp 9987/udp 9987/tcp

# Create volumes
VOLUME ["/opt/teaspeak/files", "/opt/teaspeak/database", "/opt/teaspeak/certs", "/opt/teaspeak/logs"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD nc -z localhost 10011 || exit 1

# Set shell and start command
SHELL ["/bin/bash", "-c"]
CMD ["./teastart_minimal.sh"]
