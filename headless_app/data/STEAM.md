# STEAM.md — план интеграции Steam (GameServer API) на headless-сервере

Статус: **план, реализация в будущем**.

## Цель
Замена AuthServer (HTTP + SQLite) на Steam-авторизацию: клиент шлёт auth ticket, сервер валидирует через Steam GameServer API.

## Что уже есть в CGE (`castleinternalsteamapi.pas`)
- Динамическая загрузка: `TDynLib.Load('libsteam_api.so'/'steam_api64.dll')` — менять загрузчик не нужно
- `SteamAPI_RegisterCallback` + `ManualDispatch_*` — механизм прокачки колбэков уже есть
- Привязаны только `ISteamApps`, `ISteamUtils`, `ISteamUserStats` — GameServer и User отсутствуют

## Что привязать (сервер)
C-функции:
- `SteamGameServer_RunCallbacks()` — прокачка в главном цикле сервера
- `SteamGameServer_Init(ip, port, mode, version)` / `SteamGameServerShutdown()`
- `SteamGameServer_GetHSteamPipe()` — для manual dispatch

`ISteamGameServer` (7 из ~60 методов):
- `LogOnAnonymous()` — вход в Steam без логина
- `BeginAuthSession(ticket, size, SteamID)` — валидация тикета → `k_EBeginAuthSessionResultOK`
- `EndAuthSession(SteamID)`
- `GetSteamID()`
- (+ SetModTime/SetGameTags — только если нужен серверный браузер Steam)

Колбэк `TValidateAuthTicketResponse` (`k_iSteamGameServerCallbacks + 34`) — асинхронный результат: `k_EAuthSessionResponseOK` / `UserNotConnectedToSteam` / `ExpiredTicket`...

## Что привязать (клиент)
`ISteamUser`:
- `GetAuthSessionTicket(pTicket, cbMax, @pcbTicket)` → `HAuthTicket` (тикет ~2 КБ)
- `CancelAuthTicket(hAuthTicket)`
- `GetSteamID()`

## Варианты размещения кода
- **А** — дописать в `castleinternalsteamapi.pas` (движок, `/home/vano/Engines/`): потеряется при обновлении CGE
- **Б (рекомендуется)** — отдельный юнит `headless_app/src/SteamServerApi.pas`: свой `TDynLib.Load` + Symbol-ы + init/finalize (~30 строк каркаса, копия паттерна CGE)

## Версии символов
Экспорт версионирован (`SteamAPI_SteamGameServer_v014`). Решение как у CGE: alias `'SteamAPI_SteamGameServer_v' + Version` — либо перебор версий при загрузке (попробовать несколько, взять первую найденную).

## Деплой на сервер
- `libsteam_api.so` (+ `steamclient.so`) рядом с бинарником
- `steam_appid.txt` с валидным AppID
- `SteamGameServer_RunCallbacks()` в главном цикле, на той же нити, где вызывался init (важно: лобби обновляются в `TParallel.For` — колбэки качать только из main thread)

## Изменения в проекте
1. `TAuthPayload` — фикс. 64 байта → length-prefixed `array of Byte` (4 места: 2 клиентских + 2 серверных)
2. `TSteamValidator : class(..., IAuthValidator)` — вставляется в `LobbyManager.AuthValidator` без изменений в NetSystem-ах
3. `TAuthResult` — добавить SteamID64, display name
4. БД: `TOrmGameAccount.AuthUserId` = SteamID64 (Int64); таблица `sessions` отмирает

## Альтернатива (если не нужен серверный браузер/античит)
Steam Web API: `POST api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1?key=...&appid=...&ticket=...` → SteamID + персона. Нужен только Web API-ключ и интернет; без биндингов GameServer. Минус: нет `LogOnAnonymous`, нет листинга в браузере серверов, лишний HTTP-вызов.
