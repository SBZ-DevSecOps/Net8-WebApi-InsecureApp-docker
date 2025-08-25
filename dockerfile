# VULN: tag 'latest' (non épinglé), base potentiellement vulnérable
FROM mcr.microsoft.com/dotnet/sdk:latest AS build

# VULN: proxies HTTP non sûrs + fuite d'info env
ENV http_proxy=http://68.167.255.01.gold.com:80 \
    https_proxy=http://68.167.255.01.gold.com:80 \
    no_proxy=127.0.0.1

WORKDIR /src
# VULN: copie large du contexte (risque de secrets)
ADD . .

# VULN: exécution d'un script distant non authentifié
RUN curl -s http://insecure.example.com/install.sh | bash

# VULN: désactivation TLS
RUN wget https://myweb.com/my_cert.crt --no-check-certificate -O /usr/local/share/ca-certificates/my_cert.crt

# VULN: secrets codés en dur / variables sensibles
ARG GITHUB_TOKEN=ghp_example_leaked_token_1234567890
ENV ConnectionStrings__Default="Server=db;User Id=sa;Password=P@ssw0rd!;Encrypt=False"

# VULN: usage de 'latest' + pas d’empreintes/pinning
RUN dotnet publish "Net8-WebApi-InsecureApp.csproj" -c Release -o /src/publish /p:BuildAngular=false

# --------- Stage final ---------
FROM mcr.microsoft.com/dotnet/aspnet:latest

# VULN: root explicite
USER root

# VULN: séparation 'apt-get update' / 'install', pas de pinning, pas de nettoyage, allow-unauthenticated
RUN apt-get update
RUN apt-get install -y --allow-unauthenticated openssh-server ca-certificates

# VULN: SSH root + permissions laxistes
RUN echo 'root:root' | chpasswd && \
    sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    mkdir -p /var/run/sshd

# VULN: copie d’une clé privée (même si le fichier n’existe pas, la règle sera détectée en SAST)
COPY secrets/id_rsa /root/.ssh/id_rsa

WORKDIR /app
COPY --from=build /src/publish .

# VULN: droits 777 + setuid sur /bin/bash
RUN chmod -R 777 /app && chmod u+s /bin/bash

EXPOSE 22 80 443
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS="http://0.0.0.0:80"

# VULN: pas de HEALTHCHECK
ENTRYPOINT ["dotnet", "Net8-WebApi-InsecureApp.dll"]