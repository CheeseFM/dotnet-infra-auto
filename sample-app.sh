#!/bin/bash
# Bouwt en start de dotnet-demo-app (TodoApp + MariaDB) in containers.
# Uitvoeren vanuit de root van de repo: bash ./dotnet-app.sh
set -euo pipefail

# Opruimen van een vorige build, zodat het script herhaalbaar is in Jenkins
docker rm -f todorunning todoappdb 2>/dev/null || true
docker network rm todonet 2>/dev/null || true
rm -rf tempdir

mkdir tempdir
cp -r TodoApp tempdir/.
rm -rf tempdir/TodoApp/bin tempdir/TodoApp/obj

cat > tempdir/Dockerfile << _EOF_
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ./TodoApp/ .
RUN dotnet publish -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
CMD ["dotnet", "TodoApp.dll"]
_EOF_

cat > tempdir/schema.sql << _EOF_
CREATE TABLE IF NOT EXISTS todos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    is_done BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
_EOF_

cd tempdir || exit
docker build -t todoapp .

# Netwerk zodat de app de database op naam (todoappdb) kan bereiken
docker network create todonet

docker run -d --name todoappdb --network todonet \
  -e MARIADB_ROOT_PASSWORD=sekrit \
  -e MARIADB_DATABASE=todo_db \
  -e MARIADB_USER=todo_usr \
  -e MARIADB_PASSWORD=letmeinplz \
  mariadb:11

# Wachten tot de database klaar is (max. 60 s), dan het schema laden
for i in $(seq 1 30); do
  if docker exec -i todoappdb mariadb -utodo_usr -pletmeinplz todo_db < schema.sql 2>/dev/null; then
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "MariaDB is niet opgestart" >&2
    exit 1
  fi
  sleep 2
done

docker run -t -d -p 8081:8080 --name todorunning --network todonet \
  -e "ConnectionStrings__TodoDb=Server=todoappdb;Port=3306;Database=todo_db;User ID=todo_usr;Password=letmeinplz" \
  todoapp

docker ps -a