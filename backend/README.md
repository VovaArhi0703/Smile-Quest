# Smile Quest: API данных

FastAPI и PostgreSQL 17 заменяют прежнее подключение к Supabase. API обслуживает аккаунты, профиль, питомца, прогресс, награды, достижения, фотографии, задачи и серию заходов. Фотографии доступны через авторизацию или подписанные ссылки; кадры упражнений обрабатывает отдельный сервис.

## Локальный запуск

Из корня проекта при работающем Docker:

```powershell
docker compose -f backend/compose.yaml up --build -d
docker compose -f backend/compose.yaml ps
curl.exe http://127.0.0.1:8100/health
```

Схема `schema.sql` применяется при первом создании пустой БД. SQL-миграции находятся в `migrations/`. Перезапуск контейнера не запускает начальный SQL повторно.

Volumes `pg_data` и `photo_data` сохраняют БД и фотографии. `docker compose down` сохраняет volumes; флаг `-v` удаляет их вместе с данными. PostgreSQL не публикуется наружу, локальный API доступен только на `127.0.0.1:8100`.

Значения `local_dev_only_*` в Compose предназначены только для разработки. Для сервера используйте [deploy/README.md](../deploy/README.md), отдельные секреты и HTTPS. Полное приложение запускается по [корневому README](../README.md).

## Без Docker

Нужна PostgreSQL с применённой `schema.sql`. Создайте Python-окружение и установите `requirements.txt`. Задайте `DATABASE_URL`, `PHOTO_ROOT`, `PHOTO_SIGNING_KEY` и, только локально, `APP_ENV=local`.

Из корня проекта с активным окружением:

```powershell
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8100
```

## Проверки и копии

Интеграционные тесты используют отдельную тестовую БД: [docs/testing.md](../docs/testing.md). Скрипты `smoke_test.py` и `cloud_smoke.ps1` создают тестовые аккаунты и запускаются вручную для выбранного окружения.

Резервная копия из корня проекта:

```powershell
docker compose -f backend/compose.yaml exec -T db pg_dump -U biosmile -d biosmile -Fc -f /tmp/smile-quest.backup
docker compose -f backend/compose.yaml cp db:/tmp/smile-quest.backup .\smile-quest.backup
```

Храните копию вне репозитория. Для полного восстановления нужна отдельная копия фотографий. Проверяйте восстановление на отдельной БД.

## Ограничения

Регистрация создаёт сессию без подтверждения email. Почтовое восстановление пароля не настроено: `/auth/request-reset` возвращает 503. Настройки напоминаний сохраняются, доставка уведомлений требует реализации. Прежние записи Supabase недоступны без выгрузки старого проекта.
