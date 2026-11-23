# Проверки Smile Quest

Команды выполняются из корня проекта, если не указано иное. Используйте тестовые аккаунты и отдельную тестовую базу.

## Flutter

```powershell
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

Есть информационные замечания анализатора о стиле и устаревших вызовах. Они не отключены в настройках: команда их показывает, но завершается успешно при отсутствии ошибок и предупреждений. Обычный `flutter analyze` возвращает ненулевой код и при информационных замечаниях.

## Сервис упражнений

```powershell
cd exercise_server
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Окружение и модель готовятся по [README сервиса](../exercise_server/README.md). Проверяются геометрия, масштаб и поворот лица, независимость сторон, ошибки протокола и авторизация. При скачанной модели выполняются интеграционные проверки с тестовым изображением Matplotlib; камера пользователя не нужна.

## Синхронизация задач

Создайте Python-окружение для `backend/requirements-dev.txt`. При работающем Docker поднимите отдельную тестовую БД:

```powershell
docker run --name smile-quest-test-db -e POSTGRES_PASSWORD=local_test_only -e POSTGRES_DB=smile_quest_test -p 127.0.0.1:55432:5432 -d postgres:17-alpine
```

После готовности PostgreSQL, из корня проекта с активным окружением:

```powershell
$env:TASKS_TEST_DATABASE_URL = 'postgresql://postgres:local_test_only@127.0.0.1:55432/smile_quest_test'
python -m unittest backend.test_tasks -v
```

Тесты создают схему со случайным именем и удаляют её после проверки. Проверяются изоляция аккаунтов, удаление задач, повторные и конкурентные запросы, валидация и идемпотентность миграции. Без `TASKS_TEST_DATABASE_URL` проверки пропускаются. По окончании удалите тестовый контейнер: `docker rm -f smile-quest-test-db`.

## Ручная сквозная проверка

Запустите API на 8100 и упражнения с авторизацией на 8001 по [корневой инструкции](../README.md):

```powershell
.\exercise_server\.venv\Scripts\python.exe backend/smoke_test.py
```

Скрипту нужны также зависимости API из `backend/requirements.txt`. Он создаёт тестовые записи, проверяет вход, профиль, награды, фотографии и WebSocket. Облачные `cloud_smoke`-скрипты также создают аккаунты и запускаются вручную. GitHub Actions не обращается к рабочим серверам.

На Android отдельно проверяйте калибровку, удержание, зачёт повторов, плавность камеры и точек, задачи, награды и серию заходов. Успешные автоматические тесты не заменяют эту проверку.
