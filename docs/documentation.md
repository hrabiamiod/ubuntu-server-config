# Dokumentacja Serwera mk.devops.wroclaw.pl

## Informacje ogólne

- **Domena**: mk.devops.wroclaw.pl
- **System operacyjny**: Ubuntu 24.04
- **Data inicjalnej konfiguracji**: [UZUPEŁNIJ DATĘ]
- **Administratorzy**: [UZUPEŁNIJ KONTAKT]

## 1. Architektura systemu

### 1.1 Komponenty podstawowe
- Ubuntu 24.04 LTS
- Docker i Docker Compose
- Nginx (w kontenerze) jako reverse proxy
- UFW jako główna zapora sieciowa
- Fail2ban do ochrony przed atakami
- Cloudflare jako CDN i ochrona

### 1.2 Schemat architektury
```
Internet --> Cloudflare --> UFW --> Docker/Nginx --> Aplikacje/Usługi
```

## 2. Konfiguracja systemu operacyjnego

### 2.1 Aktualizacje systemu
System jest skonfigurowany z automatycznymi aktualizacjami bezpieczeństwa poprzez unattended-upgrades.

### 2.2 Zabezpieczenia systemowe
- **SSH**: Wyłączone logowanie jako root, limit prób autoryzacji, wyłączone przekierowania X11
- **Kernel**: Parametry jądra dostosowane dla poprawy bezpieczeństwa (ochrona przed SYN flood, SMURF, IP spoofing)
- **Zapora ogniowa**: UFW z precyzyjnymi regułami dla poszczególnych usług
- **Fail2ban**: Ochrona przed atakami na SSH, Dockera i Nginx
- **Monitorowanie**: Zainstalowany LogWatch i auditd do monitorowania zmian systemu

### 2.3 Limity systemowe
- Zwiększone limity otwartych plików i procesów (65535)
- Zoptymalizowane ustawienia kernela dla dużych transferów danych

## 3. Docker i kontenery

### 3.1 Konfiguracja Docker
Docker jest zainstalowany i skonfigurowany w taki sposób, aby nie interferwał z regułami UFW:
```json
{
  "iptables": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ]
}
```

### 3.2 Docker Compose
Główny stack Docker Compose znajduje się w `/home/turbo/docker/docker-compose.yml` i zawiera:
- Nginx jako główny serwer HTTP/HTTPS
- [Tu dodać inne uruchomione kontenery]

### 3.3 Struktura katalogów Docker
```
/home/turbo/docker/
├── docker-compose.yml
├── nginx/
│   ├── conf.d/
│   │   └── default.conf
│   ├── html/
│   │   └── index.html
│   ├── logs/
│   └── ssl/
│       ├── cert.pem
│       └── key.pem
```

## 4. Konfiguracja sieci

### 4.1 UFW (Zapora)
Zapora jest skonfigurowana, aby:
- Domyślnie blokować cały ruch przychodzący
- Zezwalać na cały ruch wychodzący
- Zezwalać na SSH (port 22)
- Zezwalać na HTTP/HTTPS (porty 80/443) tylko z IP Cloudflare
- Zezwalać na porty Docker Swarm (2377, 7946, 4789)

### 4.2 Cloudflare
- Ruch HTTP/HTTPS jest kierowany przez Cloudflare
- Nginx jest skonfigurowany do pobierania rzeczywistych IP klientów z nagłówków Cloudflare
- Wszystkie adresy IP Cloudflare są dozwolone w regułach UFW dla portów 80 i 443

### 4.3 HTTPS/SSL
- Tymczasowy self-signed certyfikat w `/home/turbo/docker/nginx/ssl/`
- Nginx skonfigurowany z przekierowaniem HTTP na HTTPS
- Usługi dostępne tylko przez HTTPS

## 5. Fail2ban

### 5.1 Główna konfiguracja
- Domyślny czas bana: 12 godzin (43200 sekund)
- Czas obserwacji: 10 minut (600 sekund)
- Maksymalna liczba prób: 3

### 5.2 Aktywne filtry
- **sshd**: Ochrona przed atakami na SSH (autentykacja)
- **sshd-ddos**: Ochrona przed atakami DDoS na SSH
- **docker-login**: Własny filtr dla prób logowania do Dockera
- **docker-authentication**: Własny filtr dla błędów autentykacji Dockera
- **nginx-http-auth**: Ochrona przed atakami na autentykację HTTP
- **nginx-botsearch**: Ochrona przed skanowaniem serwera
- **nginx-bad-request**: Ochrona przed złośliwymi żądaniami HTTP

### 5.3 Niestandardowe filtry
- **docker-login**:
  ```
  failregex = ^.*Failed publickey for .* from <HOST> port [0-9]+ ssh2$
              ^.*authentication failure; logname=.* uid=.* euid=.* tty=.* ruser=.* rhost=<HOST>.*$
              ^.*refused connect from \S+ \(<HOST>\).*$
  ignoreregex =
  ```

- **docker-authentication**:
  ```
  failregex = ^.*docker.*(Authentication failure|Failed authentication|Authentication failed) .* from <HOST>.*$
              ^.*dockerd.*Unable to authenticate user .* from <HOST>.*$
  ignoreregex =
  ```

- **nginx-bad-request**:
  ```
  failregex = ^<HOST> .* "(GET|POST|HEAD).*HTTP.*" (400|403|404|405)
  ignoreregex =
  ```

## 6. Nginx

### 6.1 Konfiguracja wirtualnych hostów
```nginx
server {
    listen 80;
    server_name mk.devops.wroclaw.pl;
    
    # Przekierowanie HTTP na HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name mk.devops.wroclaw.pl;
    
    # SSL configuration
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    
    # Cloudflare real IP
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    # [pozostałe adresy IP Cloudflare...]
    real_ip_header CF-Connecting-IP;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ =404;
    }
    
    # Nagłówki bezpieczeństwa
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self'; img-src 'self'; style-src 'self'; font-src 'self'; connect-src 'self'";
    add_header Referrer-Policy strict-origin-when-cross-origin;
}
```

### 6.2 Nagłówki bezpieczeństwa
- X-Content-Type-Options: nosniff
- X-Frame-Options: SAMEORIGIN
- X-XSS-Protection: 1; mode=block
- Content-Security-Policy: Restrykcyjna polityka
- Referrer-Policy: strict-origin-when-cross-origin

## 7. Instrukcje administracyjne

### 7.1 Restarty usług
- SSH: `sudo systemctl restart sshd`
- UFW: `sudo systemctl restart ufw`
- Fail2ban: `sudo systemctl restart fail2ban`
- Docker: `sudo systemctl restart docker`
- Docker Compose stack: `cd /home/turbo/docker && docker-compose restart`

### 7.2 Logowanie
- SSH: `/var/log/auth.log`
- UFW: `/var/log/ufw.log`
- Fail2ban: `/var/log/fail2ban.log`
- Docker: `docker logs [nazwa_kontenera]`
- Nginx: `/home/turbo/docker/nginx/logs/`

### 7.3 Kopie zapasowe
[Tu dodać informacje o kopiach zapasowych, gdy zostaną skonfigurowane]

### 7.4 Aktualizacje
- System: Automatyczne przez unattended-upgrades
- Docker: `sudo apt update && sudo apt upgrade`
- Obrazy kontenerów: `cd /home/turbo/docker && docker-compose pull && docker-compose up -d`

## 8. Dziennik zmian

### [DATA INICJALNEJ KONFIGURACJI]
- Inicjalna konfiguracja serwera Ubuntu 24.04
- Instalacja i konfiguracja Dockera
- Konfiguracja Nginx jako reverse proxy
- Konfiguracja zabezpieczeń: UFW, Fail2ban
- Integracja z Cloudflare
- Skonfigurowanie domeny mk.devops.wroclaw.pl

### [PRZYSZŁE DATY]
[Miejsce na dodawanie wpisów przy kolejnych modyfikacjach]
