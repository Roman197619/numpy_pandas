# BOM SQL Query Execution Guide

Этот раздел содержит SQL-запрос для рекурсивного расширения BOM (Bill of Materials) с использованием PostgreSQL в Docker.

## 📋 Структура

- `docker-compose.yaml` — конфигурация контейнеров PostgreSQL и pgAdmin
- `init.sql` — инициализирующий скрипт БД (создание таблиц и загрузка данных)
- `bom_exploded_export.sql` — основной запрос расширения BOM с COPY в CSV
- `pgdata/` — хранилище PostgreSQL (в `.gitignore`)
- `pgadmin_data/` — хранилище pgAdmin с сохраненными запросами (в `.gitignore`)
- `data/` — входные и выходные файлы (смонтированы как `/tmp/reports` в контейнере)

## 🚀 Быстрый старт

### 1. Запустить контейнеры

```bash
cd bom_sql
docker compose up -d
```

Это создаст:
- **PostgreSQL** на `localhost:5432` (пользователь: `user`, пароль: `password`)
- **pgAdmin** на `http://localhost:8080` (email: `admin@admin.com`, пароль: `admin`)

### 2. Инициализация БД

При первом запуске `init.sql` автоматически:
- Создает таблицу `BOM_RAW`
- Загружает данные из `../data/task_2_data_ex.csv`

Если нужна переинициализация:
```bash
docker compose down -v
docker compose up -d
```

### 3. Открыть pgAdmin

1. Перейдите на `http://localhost:8080`
2. Логин: `admin@admin.com`, пароль: `admin`
3. В левой панели откройте: **Servers → bom_postgres → Databases → manufacturing_db**

### 4. Запустить BOM-запрос

#### Вариант A: Через pgAdmin UI (рекомендуется для сохранения)

1. Правой кнопкой на базу → **Query Tool**
2. Сверху нажмите **Open File** (значок папки)
3. Выберите `storage → admin_admin.com → bom_exploded_export.sql`
4. Нажмите **F5** или **Execute**
5. Результат сразу сохранится в `/data/bom_exploded_result_sql.csv`

#### Вариант B: Через консоль Docker

```bash
docker exec bom_postgres psql -U user -d manufacturing_db -f /docker-entrypoint-initdb.d/bom_exploded_export.sql
```

⚠️ **Важно**: Скрипт использует `COPY TO '/tmp/reports/...'`, поэтому файл автоматически попадет в `../data/`.

## 📊 Результаты

После выполнения запроса в папке `../data/` появится:
```
bom_exploded_result_sql.csv
```


