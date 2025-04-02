# Ubuntu 24.04 Server Configuration

Repozytorium zawiera kod Ansible do automatycznej konfiguracji serwera Ubuntu 24.04 dostępnego pod domeną mk.devops.wroclaw.pl przez Cloudflare.

## Zawartość

- `playbook.yml` - główny playbook Ansible
- `inventory.ini` - plik inwentarza Ansible
- `docs/` - dokumentacja
  - `documentation.md` - pełna dokumentacja serwera
- `scripts/` - pomocnicze skrypty bash
  - `server_setup.sh` - alternatywny skrypt bash dla przypadku braku Ansible

## Funkcje

- Aktualizacja i zabezpieczenie systemu
- Konfiguracja SSH
- Instalacja i konfiguracja Docker oraz Docker Compose
- Konfiguracja UFW (zapora)
- Konfiguracja Fail2ban (ochrona przed atakami)
- Integracja z Cloudflare
- Nginx jako reverse proxy
- Automatyczne aktualizacje bezpieczeństwa

## Wymagania

- Ansible 2.9+ na maszynie lokalnej
- Dostęp SSH do serwera Ubuntu 24.04
- Użytkownik z uprawnieniami sudo na serwerze

## Użycie

1. Sklonuj repozytorium:
   ```
   git clone https://github.com/TWÓJ_UŻYTKOWNIK/ubuntu-server-config.git
   cd ubuntu-server-config
   ```

2. Dostosuj plik `inventory.ini` dodając dane swojego serwera:
   ```
   [servers]
   mk ansible_host=ADRES_IP ansible_user=turbo ansible_ssh_pass=HASŁO
   ```

3. Uruchom playbook:
   ```
   ansible-playbook -i inventory.ini playbook.yml --ask-become-pass
   ```

## Bezpieczeństwo

**UWAGA**: Nie commituj pliku `inventory.ini` z rzeczywistymi danymi logowania! Dodaj go do `.gitignore`.

## Licencja

[Dodaj wybraną licencję]
