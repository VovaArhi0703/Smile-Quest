# Smile Quest: сервис упражнений

FastAPI WebSocket-сервис с MediaPipe Face Landmarker. Получает изображения, возвращает метрики и координаты точек лица. Калибровкой, удержанием и подсчётом повторов управляет Flutter. Сервис не сохраняет кадры камеры.

В приложении используются `face_1`, `face_2`, `face_3`, `face_4`, `face_6`, `face_7`, `lip_4`: поднятие и нахмуривание бровей, закрытие глаз, моргание, прищур, подмигивание и улыбка. Экспериментальные обработчики других упражнений сохранены на сервере; это не означает готовность этих упражнений в приложении.

## Подготовка на Windows

Из корня проекта, Python 3.11:

```powershell
cd exercise_server
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Invoke-WebRequest -Uri 'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task' -OutFile .\models\face_landmarker.task
```

Модель и окружение исключены из Git и создаются после клонирования. Если `Resolve-Path` не находит модель, сначала выполните скачивание из каталога `exercise_server`.

Для полного приложения запустите API и следуйте [корневому README](../README.md). Для отдельной локальной проверки:

```powershell
$env:FACE_LANDMARKER_MODEL = (Resolve-Path .\models\face_landmarker.task).Path
$env:ALLOW_ANONYMOUS_EXERCISES = 'true'
.\.venv\Scripts\python.exe -m uvicorn exercise_server.main:app --host 127.0.0.1 --port 8000 --ws-max-size 750000
```

Состояние доступно на `http://127.0.0.1:8000/health`. Анонимный режим используйте только локально. Для Android есть [инструкция USB-проверки](../docs/android_usb_test.md).

## Docker

Из каталога `exercise_server`, после скачивания модели:

```powershell
Copy-Item .env.example .env
docker compose up --build -d
```

Compose публикует порт 8000 только на `127.0.0.1`. При подключении к API из контейнера `EXERCISE_AUTH_URL` должен указывать адрес, доступный контейнеру, а не loopback другого процесса на хосте. Схема двух серверов описана в [deploy/](../deploy/README.md).

## Протокол

В защищённом режиме первым сообщением передаётся токен сессии:

```json
{"mode":"auth","token":"<session token>"}
```

Сервис проверяет его через `/auth/me` API данных из `EXERCISE_AUTH_URL`. В публичном окружении `ALLOW_ANONYMOUS_EXERCISES=false`, соединение клиента — WSS.

Основной запрос новых экранов:

```json
{"mode":"observe","exercise":"face_2","image":"<JPEG base64>"}
```

Ответ содержит `status: observation`, метрики и `landmarks`. Для совместимости поддерживаются `init` и `track` с ответами `baseline_set` и `tracking`. Контракт проверяется в `tests/test_observation_v2_protocol.py` и `tests/test_server_integration.py`.

Стороны лица измеряются независимо. Для бровей используются ориентиры уголков глаз, а не положение верхнего века; метрики нормализуются по геометрии лица. Flutter сохраняет спокойное и максимальное положение, проверяет удержание, засчитывает повтор на целевом положении и ждёт расслабления перед следующим повтором. Различение слабого и сильного зажмуривания требует доработки.

## Проверки

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Matplotlib поставляет тестовое изображение лица. Интеграционные проверки с моделью пропускаются при её отсутствии; геометрические тесты выполняются без неё. Тесты не заменяют проверку точности на пациентах и нагрузочное испытание.
