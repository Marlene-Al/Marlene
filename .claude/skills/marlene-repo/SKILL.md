---
name: marlene-repo
description: Работа с репозиторием Marlene (github.com/Marlene-Al/Marlene) — структура, скрипты, иллюстрации, обновление README, публикация в GitHub, проверка ошибок. Использовать при любых задачах в папке Marlene\: правки файлов, картинки, синхронизация с GitHub, подготовка к публикации.
---

# Скилл: работа с репозиторием Marlene

## Контекст

- Репозиторий: `github.com/Marlene-Al/Marlene` — публичный, аккаунт `Marlene-Al`.
- **git не установлен** — все операции с GitHub только через `gh` CLI (авторизован).
- Все материалы — черновики; публикация и рассылка — только после явного разрешения руководителя.
- Без явного разрешения: не удалять, не переименовывать файлы, не выходить за пределы папки.

## Структура репозитория

| Путь | Назначение |
|---|---|
| `README.md` | Лицо репозитория: описание кампании, скриншот, структура, запуск, планы |
| `CLAUDE.md` | Правила работы агента (обязателен в корне) |
| `github-profile-readme.md` | Текст для профиля Marlene-Al |
| `reports/` | План-график кампании (`2026-09-28-promo-kurs-korpos-plan-grafik.md`) и отчёты |
| `posts/ГГГГ-ММ-ДД-week-NN.json` | Черновики недель: тексты для `telegram`, `vkontakte`, `email`, `site` + промпт иллюстрации + метаданные |
| `posts/ГГГГ-ММ-ДД-week-NN-telegram.png` | Иллюстрации к постам |
| `data/` | Приглашение на ППК, знак качества НОКС |
| `images/` | Скриншоты для README |
| `scripts/add-logo.ps1` | Наложение знака качества на картинку |
| `tmp/` | Временные артефакты — **в GitHub не публикуются** |

Именование файлов: `[дата — опционально]-[тема]-[тип].md`.

## Типовые операции

### Иллюстрация с знаком качества
1. Исходная картинка → `tmp\<файл>.png`.
2. `powershell -ExecutionPolicy Bypass -File scripts\add-logo.ps1 -Base tmp\<файл>.png -Out posts\<результат>-telegram.png` — знак НОКС ляжет в правый верхний угол.

### Публикация / обновление репозитория (git не установлен)

Скрипт `tmp\publish-gh.ps1` пересоздаёт все blobs (кроме `tmp\`), собирает tree, коммитит:

```
sha = gh api repos/Marlene-Al/Marlene/git/refs/heads/main --jq ".object.sha"
powershell -ExecutionPolicy Bypass -File tmp\publish-gh.ps1 %sha%
```

**Важно:** последняя строка скрипта всегда падает с `422 Reference already exists` — это норма, ветка уже есть. Дозаливка:

```
gh api --method PATCH repos/Marlene-Al/Marlene/git/refs/heads/main -f sha=<новый commit sha>
```

Новый commit sha скрипт печатает строкой `commit OK: ...`.

Проверка результата: `gh api repos/Marlene-Al/Marlene/contents --jq ".[].path"`.

Выборочная замена одного файла (быстрее полного прогона): `gh api --method PUT repos/Marlene-Al/Marlene/contents/<path> -f message="..." -f content=<base64> -f sha=<sha текущего файла>`.

### Обновление README

Структура README фиксирована: заголовок → описание кампании → скриншот → «что сделано» → структура папок → таблица рабочих файлов → как запустить → скрипты → правила работы → MVP и планы. Правится локально, публикуется через полный прогон `publish-gh.ps1` или точечный PUT.

### Проверка ошибок перед публикацией

1. **JSON недель:** каждый `posts/*.json` → `ConvertFrom-Json`, внутри должны быть `telegram`, `vkontakte`, `email`, `site` и метаданные.
2. **PowerShell-скрипты:** парс — `powershell -NoProfile -Command "$e=$null; [System.Management.Automation.Language.Parser]::ParseFile('<путь>', [ref]$null, [ref]$e) | Out-Null; if ($e) { $e } else { 'OK' }"`.
3. **Ссылки в README/планах:** каждый указанный путь должен существовать локально (особенно `images/*.png`).
4. **Изображения:** открываются, размер разумный (< 1 МБ на скриншот, < 4 МБ на иллюстрацию).

### Подготовка к публикации — чек-лист

1. Все новые файлы названы по формуле нейминга.
2. Проверки ошибок выше прошли.
3. `tmp/` не попал в публикацию автоматически — исключён скриптом, лишних файлов нет.
4. Публикация → `PATCH refs/heads/main` → проверка на GitHub: README рендерится, картинки открываются, структура папок совпадает.

## Грабли Windows (повторять не надо, просто знать)

- PS 5.1 читает `.ps1` без BOM как ANSI → кириллица в литералах ломает парсер. Данные (JSON для `gh api`) писать через `UTF8Encoding($false)`, литералы скрипта — ASCII.
- `gh api` на пустом репозитории даёт 409 — Git Data API нужен seed-файл через Contents API.
- В PS 5.1 нет `&&`/`||`, ternary; stderr нативных exe не редиректить.
- Cyrillic-пути Git Data API берёт как есть в JSON body — кодировать не нужно.

## Хвосты на контроль

- `.claude\agents\` пуст, но README обещает агентов researcher / article-writer / project-weekly-control — до публикации в репозиторий они не дошли; либо добавить файлы агентов, либо поправить README.