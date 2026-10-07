#!/bin/bash
# Draait de unit tests in een container tegen een tijdelijke MariaDB.
# Uitvoeren vanuit de root van de repo: bash ./test-app.sh
set -euo pipefail

docker rm -f todotestdb 2>/dev/null || true

# Image met de .NET SDK en de broncode
docker build -t todotest -f - . << _EOF_
FROM mcr.microsoft.com/dotnet/sdk:10.0
WORKDIR /src
COPY . .
CMD ["dotnet", "test"]
_EOF_

# Tijdelijke testdatabase
docker run -d --name todotestdb \
  -e MARIADB_ROOT_PASSWORD=sekrit \
  -e MARIADB_DATABASE=todo_db \
  -e MARIADB_USER=todo_usr \
  -e MARIADB_PASSWORD=letmeinplz \
  mariadb:11

# Wachten tot de database klaar is, dan todo_test_db en de tabellen aanmaken
until docker exec todotestdb mariadb -h127.0.0.1 -uroot -psekrit \
  -e "CREATE DATABASE IF NOT EXISTS todo_test_db; GRANT ALL ON todo_test_db.* TO 'todo_usr'@'%';" 2>/dev/null; do
  sleep 2
done
for db in todo_db todo_test_db; do
  docker exec -i todotestdb mariadb -uroot -psekrit "$db" < TodoApp/schema.sql
done

# Tests draaien; "localhost" in de testcontainer is de testdatabase
docker run --rm --network container:todotestdb todotest