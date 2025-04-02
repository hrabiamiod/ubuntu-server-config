#!/bin/bash
# Skrypt do instalacji Ansible i uruchomienia playbooka konfiguracyjnego
# dla serwera Ubuntu 24.04 pod domeną mk.devops.wroclaw.pl
# Autor: [Twoje Imię]
# Data: [Data utworzenia]
# Wersja: 1.0

set -e  # Przerwij działanie skryptu przy błędzie

# Kolory do lepszej czytelności
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funkcja do logowania
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] BŁĄD:${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] UWAGA:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Sprawdzenie uprawnień root
if [ "$EUID" -ne 0 ]; then
    error "Ten skrypt musi być uruchomiony jako root. Użyj sudo."
fi

# Sprawdzenie systemu operacyjnego
if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
    error "Ten skrypt jest przeznaczony do Ubuntu. Wykryto inny system operacyjny."
fi

log "Rozpoczynam konfigurację serwera"

# 1. Aktualizacja systemu
log "Aktualizacja repozytoriów..."
apt update || error "Nie można zaktualizować repozytoriów"

# 2. Instalacja wymaganych pakietów
log "Instalacja wymaganych pakietów..."
apt install -y python3 python3-pip git sshpass || error "Nie można zainstalować wymaganych pakietów"

# 3. Instalacja Ansible
log "Instalacja Ansible..."
apt install -y ansible || error "Nie można zainstalować Ansible"

# Sprawdzenie wersji Ansible
ANSIBLE_VERSION=$(ansible --version | head -n1)
log "Zainstalowano $ANSIBLE_VERSION"

# 4. Pobieranie playbooka z GitHub (jeśli nie istnieje lokalnie)
REPO_DIR="$HOME/ubuntu-server-config"

if [ -d "$REPO_DIR" ]; then
    log "Znaleziono lokalne repozytorium w $REPO_DIR"
    cd "$REPO_DIR"
    
    read -p "Czy chcesz zaktualizować lokalne repozytorium? (t/n): " UPDATE_REPO
    if [[ "$UPDATE_REPO" =~ ^[Tt]$ ]]; then
        log "Aktualizacja repozytorium..."
        git pull || warning "Nie można zaktualizować repozytorium"
    fi
else
    log "Klonowanie repozytorium z GitHub..."
    git clone https://github.com/TWOJ_UZYTKOWNIK/ubuntu-server-config.git "$REPO_DIR" || error "Nie można sklonować repozytorium"
    cd "$REPO_DIR"
fi

# 5. Tworzenie pliku inventory, jeśli nie istnieje
if [ ! -f "inventory.ini" ]; then
    log "Tworzenie pliku inventory.ini"
    
    # Pobierz IP serwera
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "Wykryto IP serwera: ${YELLOW}$SERVER_IP${NC}"
    read -p "Czy to poprawne IP dla inventory.ini? (t/n): " CORRECT_IP
    
    if [[ ! "$CORRECT_IP" =~ ^[Tt]$ ]]; then
        read -p "Podaj poprawne IP serwera: " SERVER_IP
    fi
    
    # Utwórz plik inventory.ini
    cat > inventory.ini << EOF
[servers]
mk ansible_host=$SERVER_IP ansible_user=turbo ansible_connection=local

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
    
    log "Utworzono plik inventory.ini z lokalnym połączeniem"
fi

# 6. Sprawdź, czy istnieje plik playbook.yml
if [ ! -f "playbook.yml" ]; then
    error "Brak pliku playbook.yml. Sprawdź repozytorium."
fi

# 7. Uruchomienie playbooka
log "Uruchamiam playbook Ansible..."
ansible-playbook -i inventory.ini playbook.yml --connection=local || error "Wykonanie playbooka nie powiodło się"

log "Konfiguracja zakończona pomyślnie!"
info "Zalecane jest ponowne uruchomienie systemu. Wykonaj: sudo reboot"

# Dodaj wpis do dokumentacji o wykonanej instalacji
if [ -f "docs/documentation.md" ]; then
    CURRENT_DATE=$(date +'%Y-%m-%d')
    echo -e "\n### $CURRENT_DATE\n- Automatyczna instalacja i konfiguracja przy użyciu skryptu setup.sh\n" >> docs/documentation.md
    log "Dodano wpis do dokumentacji."
fi

exit 0
